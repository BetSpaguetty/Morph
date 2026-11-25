import SwiftUI
import UIKit

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
