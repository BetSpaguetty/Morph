import SwiftUI
import UIKit
import Observation

// MARK: - Métricas, Controlador de Scroll e Ponte de Input fora do Shader

struct RetroScrollMetrics: Equatable {
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var contentOffsetY: CGFloat = 0

    var maxOffset: CGFloat { max(0, contentHeight - viewportHeight) }
    var needsScroll: Bool { maxOffset > 4 }

    var progress: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(1, max(0, contentOffsetY / maxOffset))
    }

    var visibleFraction: CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, max(0.08, viewportHeight / contentHeight))
    }
}

@MainActor
@Observable
final class RetroScrollController {
    var metrics = RetroScrollMetrics()
    var keyboardOverlap: CGFloat = 0
    var isFocused: Bool = false
    var renderVersion: Int = 0
    weak var textView: RetroCaretTextView?

    func markNeedsCanvasRedraw() {
        renderVersion &+= 1
    }

    func insertText(_ string: String) {
        textView?.insertVirtualText(string)
    }

    func deleteBackward() {
        textView?.deleteVirtualBackward()
    }

    func scrollToProgress(_ progress: CGFloat) {
        guard let tv = textView else { return }
        let clamped = min(1, max(0, progress))
        let targetY = -tv.adjustedContentInset.top + clamped * metrics.maxOffset
        tv.setContentOffset(CGPoint(x: tv.contentOffset.x, y: targetY), animated: false)
        tv.publishScrollMetrics()
        markNeedsCanvasRedraw()
    }

    func scrollDownByStep() {
        let step = max(56, metrics.viewportHeight * 0.24)
        _ = scrollDown(by: step, animated: true)
    }

    @discardableResult
    func scrollDown(by delta: CGFloat, animated: Bool = false) -> Bool {
        guard let tv = textView, metrics.needsScroll else { return false }
        let maxY = -tv.adjustedContentInset.top + metrics.maxOffset
        let nextY = min(maxY, tv.contentOffset.y + delta)
        guard nextY > tv.contentOffset.y + 0.1 else { return false }
        tv.setContentOffset(CGPoint(x: tv.contentOffset.x, y: nextY), animated: animated)
        if !animated {
            tv.publishScrollMetrics()
            markNeedsCanvasRedraw()
        }
        return true
    }

    func resignFocus() {
        _ = textView?.resignFirstResponder()
    }
}

/// Ponte entre a área de escrita (dentro do shader Metal) e o `UITextView` invisível (fora do shader).
@MainActor
@Observable
final class CRTTextInputBridge {
    struct Session {
        var text: Binding<String>
        var metrics: RetroFrameMetrics
        var scrollController: RetroScrollController
        var focusRequestID: Int
        var useSystemKeyboard: Bool
        var isVirtualKeyboardVisible: Bool = false
        var onKeyboardDismissed: () -> Void
    }

    var session: Session?
    var editorFrameInCRT: CGRect = .zero
    var excludedFramesInCRT: [String: CGRect] = [:]
    var keyboardStartYInCRT: CGFloat = -1.0

    func setExcludedFrame(_ frame: CGRect, for key: String) {
        if frame.isEmpty {
            if excludedFramesInCRT[key] != nil {
                excludedFramesInCRT.removeValue(forKey: key)
            }
        } else if excludedFramesInCRT[key] != frame {
            excludedFramesInCRT[key] = frame
        }
    }
}

// MARK: - UITextView Invisível (Input Nativo + Espelho TextKit 1 para o Canvas Curvado)

/// Substituto vazio para o destaque nativo de seleção do UIKit (fora do shader), evitando marcação dupla sobre o Canvas curvado.
private final class InvisibleSelectionHighlightView: UIView, UITextSelectionHighlightView {
    var selectionRects: [UITextSelectionRect] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class RetroCaretTextView: UITextView {
    private static let caretAspectRatio: CGFloat = 11.0 / 41.0 // viewBox de `caret_morph.svg`

    var onMetricsChanged: ((RetroScrollMetrics) -> Void)?
    var onVisualChanged: (() -> Void)?

    /// Alterna entre o teclado padrão do sistema e o teclado virtual interno dentro da TV.
    var useSystemKeyboard: Bool = true {
        didSet {
            guard oldValue != useSystemKeyboard else { return }
            applyKeyboardConfiguration()
            if isFirstResponder { reloadInputViews() }
        }
    }

    private(set) var caretAlpha: CGFloat = 1.0

    // Espelho TextKit 1 idêntico ao próprio textView, porém com tinta visível para desenhar dentro do shader Metal
    private let mirrorStorage = NSTextStorage()
    private let mirrorLayoutManager = NSLayoutManager()
    private let mirrorContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    private var mirrorDirty = true

    private var blinkTimer: Timer?
    private var lastMetrics = RetroScrollMetrics()
    private var lastLayoutHeight: CGFloat = 0

    convenience init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        self.init(frame: .zero, textContainer: container)
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    deinit {
        blinkTimer?.invalidate()
    }

    private func configure() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        alwaysBounceVertical = true
        // Mantém alpha = 1 para hit-testing/seleção nativa, mas mascara 100% da renderização UIKit (delegando tudo ao Canvas no shader).
        // shortcut: o menu nativo de edição (Cut/Copy) permanece em coordenadas UIKit fora do shader.
        textColor = .clear
        tintColor = .clear
        layer.mask = CALayer()
        applyKeyboardConfiguration()
        suppressNativeSelectionHighlight(in: self)

        mirrorLayoutManager.addTextContainer(mirrorContainer)
        mirrorStorage.addLayoutManager(mirrorLayoutManager)
    }

    private func suppressNativeSelectionHighlight(in view: UIView) {
        for interaction in view.interactions {
            if let display = interaction as? UITextSelectionDisplayInteraction,
               !(display.highlightView is InvisibleSelectionHighlightView) {
                display.highlightView = InvisibleSelectionHighlightView()
            }
        }
        for subview in view.subviews {
            if subview is any UITextSelectionHighlightView, !(subview is InvisibleSelectionHighlightView) {
                subview.alpha = 0
            }
            suppressNativeSelectionHighlight(in: subview)
        }
    }

    private func applyKeyboardConfiguration() {
        if useSystemKeyboard {
            inputView = nil
            inputAccessoryView = makeKeyboardDismissAccessory()
            keyboardDismissMode = .interactive
            autocorrectionType = .default
            spellCheckingType = .default
            smartQuotesType = .default
            smartDashesType = .default
        } else {
            inputView = UIView(frame: .zero)
            inputAccessoryView = nil
            // Limpa a barra de atalhos do iPadOS (desfazer/colar/ditado) que ainda aparece com inputView vazio.
            inputAssistantItem.leadingBarButtonGroups = []
            inputAssistantItem.trailingBarButtonGroups = []
            keyboardDismissMode = .none
            autocorrectionType = .no
            spellCheckingType = .no
            smartQuotesType = .no
            smartDashesType = .no
        }
    }

    func insertVirtualText(_ string: String) {
        guard !string.isEmpty else { return }
        if !isFirstResponder {
            _ = becomeFirstResponder()
        }
        insertText(string)
        if string.contains("\n") {
            layoutIfNeeded()
        }
        markMirrorDirty()
        updateCaretBlinkState(resetBlink: true)
        scrollCaretToVisible(animated: false)
        publishScrollMetrics()
        onVisualChanged?()
    }

    func deleteVirtualBackward() {
        guard hasText || selectedRange.length > 0 else { return }
        if !isFirstResponder {
            _ = becomeFirstResponder()
        }
        deleteBackward()
        markMirrorDirty()
        updateCaretBlinkState(resetBlink: true)
        scrollCaretToVisible(animated: false)
        publishScrollMetrics()
        onVisualChanged?()
    }

    func scrollCaretToVisible(animated: Bool = false) {
        guard let position = selectedTextRange?.end else { return }
        let rawRect = super.caretRect(for: position)
        guard !rawRect.isNull, !rawRect.isInfinite, rawRect.height > 0 else { return }
        scrollRectToVisible(rawRect.insetBy(dx: 0, dy: -12), animated: animated)
    }

    private func makeKeyboardDismissAccessory() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let dismissItem = UIBarButtonItem(
            image: UIImage(systemName: "keyboard.chevron.compact.down"),
            style: .plain,
            target: self,
            action: #selector(dismissKeyboardTapped)
        )
        dismissItem.accessibilityLabel = "Abaixar teclado"
        toolbar.items = [flex, dismissItem]
        return toolbar
    }

    @objc private func dismissKeyboardTapped() {
        _ = resignFirstResponder()
    }

    override var selectedTextRange: UITextRange? {
        didSet {
            updateCaretBlinkState(resetBlink: true)
            onVisualChanged?()
        }
    }

    override var text: String! {
        didSet {
            mirrorDirty = true
            updateCaretBlinkState(resetBlink: true)
            publishScrollMetrics()
            onVisualChanged?()
        }
    }

    override var font: UIFont? {
        didSet {
            mirrorDirty = true
            onVisualChanged?()
        }
    }

    override var textContainerInset: UIEdgeInsets {
        didSet {
            mirrorDirty = true
            onVisualChanged?()
        }
    }

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        super.setMarkedText(markedText, selectedRange: selectedRange)
        mirrorDirty = true
        updateCaretBlinkState(resetBlink: true)
        onVisualChanged?()
    }

    override func unmarkText() {
        super.unmarkText()
        mirrorDirty = true
        onVisualChanged?()
    }

    override func addInteraction(_ interaction: any UIInteraction) {
        super.addInteraction(interaction)
        if let display = interaction as? UITextSelectionDisplayInteraction,
           !(display.highlightView is InvisibleSelectionHighlightView) {
            display.highlightView = InvisibleSelectionHighlightView()
        }
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        suppressNativeSelectionHighlight(in: subview)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopBlinking()
        } else {
            suppressNativeSelectionHighlight(in: self)
            updateCaretBlinkState(resetBlink: false)
            onVisualChanged?()
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        updateCaretBlinkState(resetBlink: true)
        onVisualChanged?()
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        updateCaretBlinkState(resetBlink: false)
        onVisualChanged?()
        return ok
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncMirrorContainerGeometry()
        suppressNativeSelectionHighlight(in: self)
        if bounds.height > 1 && lastLayoutHeight > 1 && bounds.height < lastLayoutHeight - 1 && isFirstResponder {
            scrollCaretToVisible(animated: false)
        }
        lastLayoutHeight = bounds.height
        updateCaretBlinkState(resetBlink: false)
        publishScrollMetrics()
        onVisualChanged?()
    }

    func markMirrorDirty() {
        mirrorDirty = true
    }

    private func syncMirrorContainerGeometry() {
        let targetWidth = textContainer.size.width > 0
            ? textContainer.size.width
            : max(1, bounds.width - textContainerInset.left - textContainerInset.right)
        let targetSize = CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        if mirrorContainer.size != targetSize {
            mirrorContainer.size = targetSize
        }
        if mirrorContainer.lineFragmentPadding != textContainer.lineFragmentPadding {
            mirrorContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        }
        if mirrorContainer.lineBreakMode != textContainer.lineBreakMode {
            mirrorContainer.lineBreakMode = textContainer.lineBreakMode
        }
    }

    private func syncMirrorTextIfNeeded() {
        syncMirrorContainerGeometry()
        guard mirrorDirty else { return }
        mirrorDirty = false

        let resolvedFont = font ?? UIFont.monospacedSystemFont(ofSize: 24, weight: .regular)
        let fullText = text ?? ""
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: resolvedFont,
                .foregroundColor: RetroTerminalStyle.uiInk
            ]
        )

        // Sublinha texto em composição (ex.: acentuação / dead keys)
        if let marked = markedTextRange {
            let loc = offset(from: beginningOfDocument, to: marked.start)
            let len = offset(from: marked.start, to: marked.end)
            if loc >= 0, len > 0, loc + len <= attributed.length {
                attributed.addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: loc, length: len)
                )
            }
        }

        mirrorStorage.setAttributedString(attributed)
    }

    /// Desenha o texto visível e destaques de seleção no `CGContext` do Canvas SwiftUI (dentro do shader Metal).
    func drawMirroredContent(in cgContext: CGContext, viewportSize: CGSize) {
        syncMirrorTextIfNeeded()

        let inset = textContainerInset
        let offset = contentOffset

        // Destaque de seleção único dentro do shader (fillPath evita sobreposição de alfa entre retângulos)
        if selectedRange.length > 0, let range = selectedTextRange {
            let rects = selectionRects(for: range)
                .map { $0.rect.offsetBy(dx: -offset.x, dy: -offset.y) }
                .filter { $0.width > 0.5 && $0.height > 0.5 }
            if !rects.isEmpty {
                cgContext.setFillColor(RetroTerminalStyle.uiInk.withAlphaComponent(0.24).cgColor)
                cgContext.beginPath()
                for r in rects { cgContext.addRect(r) }
                cgContext.fillPath()
            }
        }

        guard mirrorStorage.length > 0 else { return }

        let visibleInContainer = CGRect(
            x: offset.x - inset.left,
            y: offset.y - inset.top,
            width: viewportSize.width,
            height: viewportSize.height
        )
        let glyphRange = mirrorLayoutManager.glyphRange(forBoundingRect: visibleInContainer, in: mirrorContainer)
        guard glyphRange.length > 0 else { return }

        let drawOrigin = CGPoint(x: inset.left - offset.x, y: inset.top - offset.y)
        UIGraphicsPushContext(cgContext)
        mirrorLayoutManager.drawBackground(forGlyphRange: glyphRange, at: drawOrigin)
        mirrorLayoutManager.drawGlyphs(forGlyphRange: glyphRange, at: drawOrigin)
        UIGraphicsPopContext()
    }

    /// Retângulo exato do `caret_morph` SVG no espaço da viewport do Canvas.
    func currentCaretRectInViewport() -> CGRect? {
        let shouldShow = window != nil && selectedRange.length == 0 && (isFirstResponder || (text ?? "").isEmpty)
        guard shouldShow else { return nil }

        let position = selectedTextRange?.start ?? beginningOfDocument
        let rawRect = super.caretRect(for: position)
        let baseRect = (!rawRect.isNull && !rawRect.isInfinite && rawRect.height > 0)
            ? rawRect
            : fallbackInitialCaretRect()

        let caretH = max(baseRect.height, font?.lineHeight ?? 30) * 1.06
        let caretW = caretH * Self.caretAspectRatio

        return CGRect(
            x: baseRect.minX - contentOffset.x,
            y: baseRect.midY - caretH * 0.5 - contentOffset.y,
            width: caretW,
            height: caretH
        )
    }

    func updateCaretBlinkState(resetBlink: Bool) {
        let shouldShow = window != nil && selectedRange.length == 0 && (isFirstResponder || (text ?? "").isEmpty)
        guard shouldShow else {
            caretAlpha = 0.0
            stopBlinking()
            return
        }

        if resetBlink || blinkTimer == nil {
            restartBlinking()
        }
    }

    private func fallbackInitialCaretRect() -> CGRect {
        CGRect(
            x: textContainerInset.left + textContainer.lineFragmentPadding,
            y: textContainerInset.top,
            width: 2,
            height: font?.lineHeight ?? 30
        )
    }

    private func restartBlinking() {
        blinkTimer?.invalidate()
        caretAlpha = 1.0
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.caretAlpha = (self.caretAlpha > 0.5) ? 0.0 : 1.0
                self.onVisualChanged?()
            }
        }
    }

    func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    func publishScrollMetrics() {
        let inset = adjustedContentInset
        let next = RetroScrollMetrics(
            contentHeight: contentSize.height,
            viewportHeight: max(0, bounds.height - inset.top - inset.bottom),
            contentOffsetY: contentOffset.y + inset.top
        )

        if abs(next.contentHeight - lastMetrics.contentHeight) > 0.5 ||
            abs(next.viewportHeight - lastMetrics.viewportHeight) > 0.5 ||
            abs(next.contentOffsetY - lastMetrics.contentOffsetY) > 0.5 {
            lastMetrics = next
            onMetricsChanged?(next)
        }
    }
}

// MARK: - Canvas SwiftUI do Editor (100% dentro do Shader Metal CRT)

struct RetroTextCanvasView: View {
    let scrollController: RetroScrollController
    let metrics: RetroFrameMetrics
    let text: String

    @Environment(CRTTextInputBridge.self) private var textInputBridge

    var body: some View {
        Canvas { context, size in
            _ = scrollController.renderVersion

            if let tv = scrollController.textView {
                context.withCGContext { cgContext in
                    cgContext.saveGState()
                    cgContext.clip(to: CGRect(origin: .zero, size: size))
                    tv.drawMirroredContent(in: cgContext, viewportSize: size)
                    cgContext.restoreGState()
                }

                if let caretRect = tv.currentCaretRectInViewport(), tv.caretAlpha > 0.01 {
                    var caretContext = context
                    caretContext.opacity = Double(tv.caretAlpha)
                    caretContext.draw(Image("caret_morph"), in: caretRect)
                }
            } else if text.isEmpty {
                // Caret inicial imediato no primeiro frame antes do overlay UIKit anexar
                let layout = RetroEditorLayout.compute(for: metrics, isVirtualKeyboardVisible: false)
                let lineH = UIFont.monospacedSystemFont(ofSize: layout.fontSize, weight: .regular).lineHeight
                let caretH = lineH * 1.06
                let caretW = caretH * (11.0 / 41.0)
                let rect = CGRect(
                    x: layout.insets.left + 5,
                    y: layout.insets.top + (lineH - caretH) * 0.5,
                    width: caretW,
                    height: caretH
                )
                context.draw(Image("caret_morph"), in: rect)
            }
        }
        .allowsHitTesting(false)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(CRTCoordinateSpace.name))
        } action: { frame in
            if textInputBridge.editorFrameInCRT != frame {
                textInputBridge.editorFrameInCRT = frame
            }
        }
    }
}

private enum RetroEditorLayout {
    static func compute(
        for metrics: RetroFrameMetrics,
        isVirtualKeyboardVisible: Bool
    ) -> (fontSize: CGFloat, insets: UIEdgeInsets) {
        let fw = metrics.frameSize.width
        let bodyH = max(120, metrics.frameSize.height - metrics.headerHeight)
        let compactWithKeyboard = isVirtualKeyboardVisible && bodyH < 420

        let fontSize = compactWithKeyboard
            ? min(22, max(17, 21 * metrics.headerScale))
            : min(26, max(19, 25 * metrics.headerScale))
        let leftInset = min(190, max(24, fw * 0.20))
        let topInset = compactWithKeyboard
            ? min(28, max(10, bodyH * 0.05))
            : min(68, max(20, bodyH * 0.11))
        let rightInset = max(62 * metrics.headerScale, fw * 0.11)
        let bottomInset = isVirtualKeyboardVisible
            ? (compactWithKeyboard ? 8 : 14)
            : max(24, bodyH * 0.08)

        return (fontSize, UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset))
    }
}

// MARK: - Container UIKit com Hit-Testing Remapeado pelo Efeito Barril (fora do Shader Metal)

final class CRTTextInputContainerView: UIView, UIGestureRecognizerDelegate {
    let textView = RetroCaretTextView()
    var editorFrame: CGRect = .zero {
        didSet {
            if oldValue != editorFrame {
                setNeedsLayout()
            }
        }
    }
    var excludedFrames: [String: CGRect] = [:]
    var barrelTransform: CRTBarrelTransform = .identity

    private lazy var crtTapRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleWarpedTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        return tap
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = true
        addSubview(textView)
        textView.addGestureRecognizer(crtTapRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !editorFrame.isEmpty && textView.frame != editorFrame {
            textView.frame = editorFrame
        }
    }

    /// Remapeia cada toque pela função exata do shader barril antes de decidir se pertence ao editor.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, !editorFrame.isEmpty else {
            return nil
        }
        let logical = barrelTransform.screenToLogical(point)
        guard editorFrame.contains(logical) else { return nil }
        if excludedFrames.values.contains(where: { !$0.isEmpty && $0.contains(logical) }) {
            return nil
        }
        return textView
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func handleWarpedTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let screenPoint = recognizer.location(in: self)
        let logicalPoint = barrelTransform.screenToLogical(screenPoint)
        let pointInTextView = convert(logicalPoint, to: textView)

        if !textView.isFirstResponder {
            _ = textView.becomeFirstResponder()
        }

        let applyCaretPosition = { [weak textView] in
            guard let textView, textView.selectedRange.length == 0 else { return }
            if let pos = textView.closestPosition(to: pointInTextView) {
                textView.selectedTextRange = textView.textRange(from: pos, to: pos)
            }
        }

        applyCaretPosition()
        // Garante prevalência sobre o posicionamento não-distorcido nativo do UITextView no mesmo ciclo
        DispatchQueue.main.async(execute: applyCaretPosition)
    }
}

struct CRTTextInputOverlay: UIViewRepresentable {
    @Binding var text: String
    let session: CRTTextInputBridge.Session
    let editorFrame: CGRect
    let excludedFrames: [String: CGRect]
    let barrelTransform: CRTBarrelTransform

    init(
        session: CRTTextInputBridge.Session,
        editorFrame: CGRect,
        excludedFrames: [String: CGRect],
        barrelTransform: CRTBarrelTransform
    ) {
        self._text = session.text
        self.session = session
        self.editorFrame = editorFrame
        self.excludedFrames = excludedFrames
        self.barrelTransform = barrelTransform
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CRTTextInputContainerView {
        let container = CRTTextInputContainerView()
        let tv = container.textView
        tv.delegate = context.coordinator
        tv.useSystemKeyboard = session.useSystemKeyboard
        tv.text = text

        container.editorFrame = editorFrame
        container.excludedFrames = excludedFrames
        container.barrelTransform = barrelTransform
        applyLayout(to: tv)

        let controller = session.scrollController
        tv.onMetricsChanged = { [weak controller] newMetrics in
            controller?.metrics = newMetrics
        }
        tv.onVisualChanged = { [weak controller] in
            controller?.markNeedsCanvasRedraw()
        }

        controller.textView = tv
        context.coordinator.attach(to: tv)
        context.coordinator.applyPendingFocusIfNeeded(on: tv)
        controller.markNeedsCanvasRedraw()
        return container
    }

    func updateUIView(_ uiView: CRTTextInputContainerView, context: Context) {
        context.coordinator.parent = self
        let tv = uiView.textView
        let controller = session.scrollController
        controller.textView = tv

        uiView.editorFrame = editorFrame
        uiView.excludedFrames = excludedFrames
        uiView.barrelTransform = barrelTransform

        if tv.useSystemKeyboard != session.useSystemKeyboard {
            tv.useSystemKeyboard = session.useSystemKeyboard
        }

        if tv.text != text {
            let selected = tv.selectedRange
            tv.text = text
            let maxLoc = (text as NSString).length
            tv.selectedRange = NSRange(location: min(selected.location, maxLoc), length: 0)
        }

        applyLayout(to: tv)
        context.coordinator.applyPendingFocusIfNeeded(on: tv)
    }

    static func dismantleUIView(_ uiView: CRTTextInputContainerView, coordinator: Coordinator) {
        uiView.textView.stopBlinking()
        coordinator.detach()
    }

    private func applyLayout(to tv: RetroCaretTextView) {
        let layout = RetroEditorLayout.compute(
            for: session.metrics,
            isVirtualKeyboardVisible: session.isVirtualKeyboardVisible
        )
        if tv.font?.pointSize != layout.fontSize {
            tv.font = UIFont.monospacedSystemFont(ofSize: layout.fontSize, weight: .regular)
        }
        if tv.textContainerInset != layout.insets {
            tv.textContainerInset = layout.insets
            tv.updateCaretBlinkState(resetBlink: false)
            tv.publishScrollMetrics()
            tv.onVisualChanged?()
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CRTTextInputOverlay
        private weak var textView: RetroCaretTextView?
        private var observers: [NSObjectProtocol] = []
        private var didNotifyDismissForSession = false
        private var lastHandledFocusID = 0

        init(parent: CRTTextInputOverlay) {
            self.parent = parent
        }

        func attach(to tv: RetroCaretTextView) {
            self.textView = tv
            let center = NotificationCenter.default

            let hideObs = center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleSystemKeyboardWillHide()
                }
            }

            let frameObs = center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                MainActor.assumeIsolated {
                    self?.handleSystemKeyboardFrameChange(endFrame: endFrame)
                }
            }

            observers = [hideObs, frameObs]
        }

        func detach() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            parent.session.scrollController.keyboardOverlap = 0
            if parent.session.scrollController.isFocused {
                parent.session.scrollController.isFocused = false
            }
        }

        func applyPendingFocusIfNeeded(on tv: RetroCaretTextView) {
            let reqID = parent.session.focusRequestID
            guard reqID != lastHandledFocusID else { return }
            lastHandledFocusID = reqID
            DispatchQueue.main.async { [weak tv] in
                _ = tv?.becomeFirstResponder()
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            didNotifyDismissForSession = false
            parent.session.scrollController.isFocused = true
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            if let retro = textView as? RetroCaretTextView {
                retro.markMirrorDirty()
                retro.updateCaretBlinkState(resetBlink: true)
                retro.publishScrollMetrics()
                retro.onVisualChanged?()
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let retro = textView as? RetroCaretTextView {
                retro.updateCaretBlinkState(resetBlink: true)
                retro.onVisualChanged?()
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let retro = scrollView as? RetroCaretTextView {
                retro.publishScrollMetrics()
                retro.onVisualChanged?()
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.session.scrollController.isFocused = false
            notifyDismissOnce()
        }

        private func handleSystemKeyboardWillHide() {
            guard parent.session.useSystemKeyboard, let tv = textView else { return }
            parent.session.scrollController.keyboardOverlap = 0
            if tv.contentInset.bottom != 0 {
                tv.contentInset.bottom = 0
                tv.publishScrollMetrics()
                tv.onVisualChanged?()
            }
            if tv.isFirstResponder {
                _ = tv.resignFirstResponder()
            }
        }

        private func handleSystemKeyboardFrameChange(endFrame: CGRect?) {
            guard parent.session.useSystemKeyboard, let tv = textView, let window = tv.window, let endFrame else { return }
            let kbInWindow = window.convert(endFrame, from: nil)
            let tvInWindow = tv.superview?.convert(tv.frame, to: window) ?? tv.convert(tv.bounds, to: window)
            let overlap = max(0, tvInWindow.maxY - kbInWindow.minY)
            let newBottomInset = (kbInWindow.minY >= window.bounds.height - 1) ? 0 : overlap

            parent.session.scrollController.keyboardOverlap = newBottomInset
            if abs(tv.contentInset.bottom - newBottomInset) > 0.5 {
                tv.contentInset.bottom = newBottomInset
                tv.publishScrollMetrics()
                if tv.isFirstResponder, let range = tv.selectedTextRange {
                    let caret = tv.caretRect(for: range.end)
                    tv.scrollRectToVisible(caret.insetBy(dx: 0, dy: -16), animated: true)
                }
                tv.onVisualChanged?()
            }
        }

        private func notifyDismissOnce() {
            guard !didNotifyDismissForSession else { return }
            didNotifyDismissForSession = true
            parent.session.onKeyboardDismissed()
        }
    }
}

// MARK: - Scrollbar Retrô Condicional (Cápsula com `=` + Botão `▼`)

struct RetroScrollbarView: View {
    let metrics: RetroFrameMetrics
    let controller: RetroScrollController

    @Environment(\.crtBarrelTransform) private var barrelTransform
    @Environment(CRTTextInputBridge.self) private var textInputBridge

    @State private var dragStartProgress: CGFloat?
    @State private var dragStartLogicalY: CGFloat = 0
    @State private var trackFrameInCRT: CGRect = .zero
    @State private var isHoldingDown = false
    @State private var holdScrollTask: Task<Void, Never>?

    private var scale: CGFloat { metrics.headerScale }
    private var barWidth: CGFloat { 32 * scale }
    private var strokeWidth: CGFloat { max(1.8, metrics.lineWidth * 0.65) }
    private var buttonStrokeWidth: CGFloat { max(2.2, metrics.lineWidth * 0.88) }

    var body: some View {
        if controller.metrics.needsScroll {
            VStack(spacing: 10 * scale) {
                GeometryReader { trackGeo in
                    let trackH = max(1, trackGeo.size.height)
                    let minThumbH = min(trackH, max(54 * scale, barWidth * 1.8))
                    let thumbH = min(trackH, max(minThumbH, trackH * controller.metrics.visibleFraction))
                    let travel = max(0, trackH - thumbH)
                    let offsetY = travel * controller.metrics.progress

                    ZStack(alignment: .top) {
                        Color.clear

                        thumbCapsule
                            .frame(width: barWidth, height: thumbH)
                            .offset(y: offsetY)
                    }
                    .crtHitAdjusted()
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(CRTCoordinateSpace.name))
                    } action: { frame in
                        if trackFrameInCRT != frame {
                            trackFrameInCRT = frame
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard travel > 0 else { return }
                                let logicalCurrentY = logicalTrackY(for: value.location)
                                if dragStartProgress == nil {
                                    let logicalStartY = logicalTrackY(for: value.startLocation)
                                    dragStartLogicalY = logicalStartY
                                    if logicalStartY >= offsetY && logicalStartY <= offsetY + thumbH {
                                        dragStartProgress = controller.metrics.progress
                                    } else {
                                        let jumped = min(1, max(0, (logicalStartY - thumbH * 0.5) / travel))
                                        dragStartProgress = jumped
                                        controller.scrollToProgress(jumped)
                                    }
                                }
                                if let start = dragStartProgress {
                                    controller.scrollToProgress(start + (logicalCurrentY - dragStartLogicalY) / travel)
                                }
                            }
                            .onEnded { _ in dragStartProgress = nil }
                    )
                }
                .frame(width: barWidth)

                downArrowButton
            }
            .padding(.top, 16 * scale)
            // Mantém a scrollbar e o botão ▼ visíveis acima do teclado do sistema quando aberto
            .padding(.bottom, max(14 * scale, controller.keyboardOverlap + 10 * scale))
            .padding(.trailing, 14 * scale)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(CRTCoordinateSpace.name))
            } action: { frame in
                textInputBridge.setExcludedFrame(frame, for: "scrollbar")
            }
            .transition(.opacity)
            .onDisappear {
                stopContinuousScroll()
                textInputBridge.setExcludedFrame(.zero, for: "scrollbar")
            }
        }
    }

    private func logicalTrackY(for localPoint: CGPoint) -> CGFloat {
        guard barrelTransform.isActive, !trackFrameInCRT.isEmpty else { return localPoint.y }
        let screenPoint = CGPoint(x: trackFrameInCRT.minX + localPoint.x, y: trackFrameInCRT.minY + localPoint.y)
        return barrelTransform.screenToLogical(screenPoint).y - trackFrameInCRT.minY
    }

    private var thumbCapsule: some View {
        ZStack {
            Capsule()
                .stroke(RetroTerminalStyle.ink, lineWidth: strokeWidth)

            VStack {
                gripLines
                Spacer(minLength: 4)
                gripLines
            }
            .padding(.vertical, 12 * scale)
        }
    }

    private var gripLines: some View {
        VStack(spacing: max(3, 4 * scale)) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(RetroTerminalStyle.ink)
                    .frame(width: barWidth * 0.34, height: max(1.6, 2.0 * scale))
            }
        }
    }

    private var downArrowButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                .stroke(RetroTerminalStyle.ink, lineWidth: buttonStrokeWidth)

            DownTriangleShape()
                .fill(RetroTerminalStyle.ink)
                .frame(width: barWidth * 0.44, height: barWidth * 0.36)
                .offset(y: 1 * scale)
        }
        .frame(width: barWidth, height: barWidth)
        .opacity(isHoldingDown ? 0.65 : 1.0)
        .crtHitAdjusted()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHoldingDown else { return }
                    startPressDown()
                }
                .onEnded { _ in stopContinuousScroll() }
        )
        .accessibilityLabel("Rolar texto para baixo")
        .accessibilityAddTraits(.isButton)
    }

    private func startPressDown() {
        isHoldingDown = true
        controller.scrollDownByStep()

        holdScrollTask?.cancel()
        holdScrollTask = Task {
            try? await Task.sleep(for: .milliseconds(260))
            while !Task.isCancelled && isHoldingDown {
                guard controller.scrollDown(by: 4.5) else { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func stopContinuousScroll() {
        isHoldingDown = false
        holdScrollTask?.cancel()
        holdScrollTask = nil
    }
}

private struct DownTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.16
        let p1 = CGPoint(x: rect.minX, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY)
        let p3 = CGPoint(x: rect.midX, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: (p1.x + p2.x) * 0.5, y: p1.y))
        path.addArc(tangent1End: p2, tangent2End: p3, radius: r)
        path.addArc(tangent1End: p3, tangent2End: p1, radius: r)
        path.addArc(tangent1End: p1, tangent2End: p2, radius: r)
        path.closeSubpath()
        return path
    }
}

// MARK: - Indicador Minimalista de Processamento do Gemini

struct RetroProcessingIndicator: View {
    var scale: CGFloat = 1.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.28)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.28) % 4
            HStack(spacing: 5 * scale) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(RetroTerminalStyle.ink)
                        .frame(width: 6 * scale, height: 6 * scale)
                        .opacity(index < step ? 0.9 : 0.22)
                }
            }
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 6 * scale)
            .overlay(
                Capsule()
                    .stroke(RetroTerminalStyle.ink.opacity(0.45), lineWidth: max(1.4, 1.8 * scale))
            )
            .accessibilityLabel("Interpretando texto")
        }
    }
}
