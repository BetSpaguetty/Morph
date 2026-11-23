import SwiftUI
import UIKit
import Observation

// MARK: - Métricas e Controlador de Scroll / Teclado

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
    weak var textView: RetroCaretTextView?

    func scrollToProgress(_ progress: CGFloat) {
        guard let tv = textView else { return }
        let clamped = min(1, max(0, progress))
        let targetY = -tv.adjustedContentInset.top + clamped * metrics.maxOffset
        tv.setContentOffset(CGPoint(x: tv.contentOffset.x, y: targetY), animated: false)
        tv.publishScrollMetrics()
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
        if !animated { tv.publishScrollMetrics() }
        return true
    }

    func resignFocus() {
        _ = textView?.resignFirstResponder()
    }
}

// MARK: - UITextView com Caret SVG Customizado

final class RetroCaretTextView: UITextView {
    private static let caretAspectRatio: CGFloat = 11.0 / 41.0 // viewBox de `caret_morph.svg`

    var onMetricsChanged: ((RetroScrollMetrics) -> Void)?

    /// Alterna entre o teclado padrão do sistema (hoje) e um teclado virtual próprio dentro da TV (futuro).
    var useSystemKeyboard: Bool = true {
        didSet {
            guard oldValue != useSystemKeyboard else { return }
            inputView = useSystemKeyboard ? nil : UIView(frame: .zero)
            inputAccessoryView = useSystemKeyboard ? makeKeyboardDismissAccessory() : nil
            if isFirstResponder { reloadInputViews() }
        }
    }

    private let caretImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "caret_morph"))
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = false
        return iv
    }()

    private var blinkTimer: Timer?
    private var lastMetrics = RetroScrollMetrics()

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
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        alwaysBounceVertical = true
        keyboardDismissMode = .interactive
        textColor = RetroTerminalStyle.uiInk
        tintColor = .clear
        inputAccessoryView = useSystemKeyboard ? makeKeyboardDismissAccessory() : nil

        addSubview(caretImageView)
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
            syncTintForSelection()
            updateCaretVisibilityAndFrame(resetBlink: true)
        }
    }

    override var text: String! {
        didSet {
            updateCaretVisibilityAndFrame(resetBlink: true)
            publishScrollMetrics()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopBlinking()
        } else {
            updateCaretVisibilityAndFrame(resetBlink: false)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        syncTintForSelection()
        updateCaretVisibilityAndFrame(resetBlink: true)
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        updateCaretVisibilityAndFrame(resetBlink: false)
        return ok
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bringSubviewToFront(caretImageView)
        updateCaretVisibilityAndFrame(resetBlink: false)
        publishScrollMetrics()
    }

    private func syncTintForSelection() {
        // Caret nativo oculto em modo cursor; destaque nativo preservado quando há seleção de texto
        tintColor = selectedRange.length > 0 ? RetroTerminalStyle.uiInk.withAlphaComponent(0.35) : .clear
    }

    func updateCaretVisibilityAndFrame(resetBlink: Bool = false) {
        let shouldShow = window != nil && selectedRange.length == 0 && (isFirstResponder || text.isEmpty)

        guard shouldShow else {
            caretImageView.isHidden = true
            stopBlinking()
            return
        }

        let position = selectedTextRange?.start ?? beginningOfDocument
        let rawRect = super.caretRect(for: position)
        let baseRect = (!rawRect.isNull && !rawRect.isInfinite && rawRect.height > 0)
            ? rawRect
            : fallbackInitialCaretRect()

        let caretH = max(baseRect.height, font?.lineHeight ?? 30) * 1.06
        let caretW = caretH * Self.caretAspectRatio

        caretImageView.frame = CGRect(
            x: baseRect.minX,
            y: baseRect.midY - caretH * 0.5,
            width: caretW,
            height: caretH
        )
        caretImageView.isHidden = false

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
        caretImageView.alpha = 1.0
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.caretImageView.isHidden else { return }
                self.caretImageView.alpha = (self.caretImageView.alpha > 0.5) ? 0.0 : 1.0
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

// MARK: - SwiftUI Representable

struct RetroTextEditor: UIViewRepresentable {
    @Binding var text: String
    let metrics: RetroFrameMetrics
    let scrollController: RetroScrollController
    var focusRequestID: Int = 0
    var useSystemKeyboard: Bool = true
    var onKeyboardDismissed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> RetroCaretTextView {
        let tv = RetroCaretTextView()
        tv.delegate = context.coordinator
        tv.useSystemKeyboard = useSystemKeyboard
        tv.text = text
        applyLayout(to: tv)

        tv.onMetricsChanged = { [weak scrollController] newMetrics in
            scrollController?.metrics = newMetrics
        }

        scrollController.textView = tv
        context.coordinator.attach(to: tv)
        context.coordinator.applyPendingFocusIfNeeded(on: tv)
        return tv
    }

    func updateUIView(_ uiView: RetroCaretTextView, context: Context) {
        context.coordinator.parent = self
        scrollController.textView = uiView

        if uiView.useSystemKeyboard != useSystemKeyboard {
            uiView.useSystemKeyboard = useSystemKeyboard
        }

        if uiView.text != text {
            let selected = uiView.selectedRange
            uiView.text = text
            let maxLoc = (text as NSString).length
            uiView.selectedRange = NSRange(location: min(selected.location, maxLoc), length: 0)
        }

        applyLayout(to: uiView)
        context.coordinator.applyPendingFocusIfNeeded(on: uiView)
    }

    static func dismantleUIView(_ uiView: RetroCaretTextView, coordinator: Coordinator) {
        uiView.stopBlinking()
        coordinator.detach()
    }

    private func applyLayout(to tv: RetroCaretTextView) {
        let fw = metrics.frameSize.width
        let bodyH = max(120, metrics.frameSize.height - metrics.headerHeight)

        let fontSize = min(26, max(19, 25 * metrics.headerScale))
        if tv.font?.pointSize != fontSize {
            tv.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }

        let leftInset = min(190, max(24, fw * 0.20))
        let topInset = min(68, max(20, bodyH * 0.11))
        let rightInset = max(62 * metrics.headerScale, fw * 0.11)
        let bottomInset = max(24, bodyH * 0.08)

        let desiredInset = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        if tv.textContainerInset != desiredInset {
            tv.textContainerInset = desiredInset
            tv.updateCaretVisibilityAndFrame(resetBlink: false)
            tv.publishScrollMetrics()
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RetroTextEditor
        private weak var textView: RetroCaretTextView?
        private var observers: [NSObjectProtocol] = []
        private var didNotifyDismissForSession = false
        private var lastHandledFocusID = 0

        init(parent: RetroTextEditor) {
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
            parent.scrollController.keyboardOverlap = 0
        }

        func applyPendingFocusIfNeeded(on tv: RetroCaretTextView) {
            guard parent.focusRequestID != lastHandledFocusID else { return }
            lastHandledFocusID = parent.focusRequestID
            DispatchQueue.main.async { [weak tv] in
                _ = tv?.becomeFirstResponder()
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            didNotifyDismissForSession = false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            if let retro = textView as? RetroCaretTextView {
                retro.updateCaretVisibilityAndFrame(resetBlink: true)
                retro.publishScrollMetrics()
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            (textView as? RetroCaretTextView)?.updateCaretVisibilityAndFrame(resetBlink: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            (scrollView as? RetroCaretTextView)?.publishScrollMetrics()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            notifyDismissOnce()
        }

        private func handleSystemKeyboardWillHide() {
            guard parent.useSystemKeyboard, let tv = textView else { return }
            parent.scrollController.keyboardOverlap = 0
            if tv.contentInset.bottom != 0 {
                tv.contentInset.bottom = 0
                tv.publishScrollMetrics()
            }
            if tv.isFirstResponder {
                // `resignFirstResponder` dispara `textViewDidEndEditing` sincronamente
                _ = tv.resignFirstResponder()
            }
        }

        private func handleSystemKeyboardFrameChange(endFrame: CGRect?) {
            guard parent.useSystemKeyboard, let tv = textView, let window = tv.window, let endFrame else { return }
            let kbInWindow = window.convert(endFrame, from: nil)
            let tvInWindow = tv.convert(tv.bounds, to: window)
            let overlap = max(0, tvInWindow.maxY - kbInWindow.minY)
            let newBottomInset = (kbInWindow.minY >= window.bounds.height - 1) ? 0 : overlap

            parent.scrollController.keyboardOverlap = newBottomInset
            if abs(tv.contentInset.bottom - newBottomInset) > 0.5 {
                tv.contentInset.bottom = newBottomInset
                tv.publishScrollMetrics()
                if tv.isFirstResponder, let range = tv.selectedTextRange {
                    let caret = tv.caretRect(for: range.end)
                    tv.scrollRectToVisible(caret.insetBy(dx: 0, dy: -16), animated: true)
                }
            }
        }

        private func notifyDismissOnce() {
            guard !didNotifyDismissForSession else { return }
            didNotifyDismissForSession = true
            parent.onKeyboardDismissed()
        }
    }
}

// MARK: - Scrollbar Retrô Condicional (Cápsula com `=` + Botão `▼`)

struct RetroScrollbarView: View {
    let metrics: RetroFrameMetrics
    let controller: RetroScrollController

    @State private var dragStartProgress: CGFloat?
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
                        Color.clear.contentShape(Rectangle())

                        thumbCapsule
                            .frame(width: barWidth, height: thumbH)
                            .offset(y: offsetY)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard travel > 0 else { return }
                                if dragStartProgress == nil {
                                    let y = value.startLocation.y
                                    if y >= offsetY && y <= offsetY + thumbH {
                                        dragStartProgress = controller.metrics.progress
                                    } else {
                                        let jumped = min(1, max(0, (y - thumbH * 0.5) / travel))
                                        dragStartProgress = jumped
                                        controller.scrollToProgress(jumped)
                                    }
                                }
                                if let start = dragStartProgress {
                                    controller.scrollToProgress(start + value.translation.height / travel)
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
            .transition(.opacity)
            .onDisappear(perform: stopContinuousScroll)
        }
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
        .contentShape(Capsule())
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
        .contentShape(Rectangle())
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
