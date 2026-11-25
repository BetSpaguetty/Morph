import SwiftUI
import UIKit

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
