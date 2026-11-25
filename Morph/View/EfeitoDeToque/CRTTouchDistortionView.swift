import SwiftUI
import UIKit

// MARK: - Observador Passivo de Multitoque em UIKit (Cobre SwiftUI + UITextView sem Bloquear Gestos)

private final class CRTPassiveTouchRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    weak var coordinateView: UIView?
    var onTouchesBegan: ([(ObjectIdentifier, CGPoint)]) -> Void = { _ in }
    var onTouchesMoved: ([(ObjectIdentifier, CGPoint)]) -> Void = { _ in }
    var onTouchesEnded: ([ObjectIdentifier]) -> Void = { _ in }

    private var activeTouchIDs: Set<ObjectIdentifier> = []

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        requiresExclusiveTouchType = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let refView = coordinateView ?? view else { return }
        var updates: [(ObjectIdentifier, CGPoint)] = []
        updates.reserveCapacity(touches.count)
        for touch in touches {
            let id = ObjectIdentifier(touch)
            activeTouchIDs.insert(id)
            updates.append((id, touch.location(in: refView)))
        }
        onTouchesBegan(updates)
        if state == .possible {
            state = .began
        } else if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let refView = coordinateView ?? view else { return }
        var updates: [(ObjectIdentifier, CGPoint)] = []
        updates.reserveCapacity(touches.count)
        for touch in touches {
            let id = ObjectIdentifier(touch)
            activeTouchIDs.insert(id)
            updates.append((id, touch.location(in: refView)))
        }
        onTouchesMoved(updates)
        if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        finishTouches(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        finishTouches(touches, cancelled: true)
    }

    override func reset() {
        super.reset()
        if !activeTouchIDs.isEmpty {
            let remaining = Array(activeTouchIDs)
            activeTouchIDs.removeAll(keepingCapacity: true)
            onTouchesEnded(remaining)
        }
    }

    private func finishTouches(_ touches: Set<UITouch>, cancelled: Bool) {
        var ended: [ObjectIdentifier] = []
        ended.reserveCapacity(touches.count)
        for touch in touches {
            let id = ObjectIdentifier(touch)
            activeTouchIDs.remove(id)
            ended.append(id)
        }
        onTouchesEnded(ended)
        if activeTouchIDs.isEmpty {
            if state == .began || state == .changed {
                state = cancelled ? .cancelled : .ended
            } else {
                state = .failed
            }
        } else if state == .began || state == .changed {
            state = .changed
        }
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let hostView = view, let touchView = touch.view else { return true }
        return touchView.isDescendant(of: hostView)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

final class CRTPassiveTouchAnchorView: UIView {
    private let recognizer = CRTPassiveTouchRecognizer()
    private weak var attachedHostView: UIView?
    weak var engine: CRTMagneticTouchEngine? {
        didSet { bindCallbacks() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        recognizer.coordinateView = self
        bindCallbacks()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bindCallbacks() {
        recognizer.onTouchesBegan = { [weak engine] updates in
            engine?.handleTouchesBegan(updates)
        }
        recognizer.onTouchesMoved = { [weak engine] updates in
            engine?.handleTouchesMoved(updates)
        }
        recognizer.onTouchesEnded = { [weak engine] ids in
            engine?.handleTouchesEnded(ids)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            detach()
        } else {
            attachToHostIfNeeded()
        }
    }

    func attachToHostIfNeeded() {
        guard let host = resolveHostView(), host !== attachedHostView else { return }
        detach()
        host.isMultipleTouchEnabled = true
        host.addGestureRecognizer(recognizer)
        attachedHostView = host
    }

    func detach() {
        if let host = attachedHostView {
            host.removeGestureRecognizer(recognizer)
            attachedHostView = nil
        }
    }

    private func resolveHostView() -> UIView? {
        if let rootView = window?.rootViewController?.view, isDescendant(of: rootView) {
            return rootView
        }
        var current = superview
        while let parent = current?.superview, !(parent is UIWindow) {
            current = parent
        }
        return current
    }
}

struct CRTPassiveTouchObserver: UIViewRepresentable {
    let engine: CRTMagneticTouchEngine
    let transform: CRTBarrelTransform

    func makeUIView(context: Context) -> CRTPassiveTouchAnchorView {
        engine.openingTransform = transform
        let view = CRTPassiveTouchAnchorView()
        view.engine = engine
        return view
    }

    func updateUIView(_ uiView: CRTPassiveTouchAnchorView, context: Context) {
        engine.openingTransform = transform
        uiView.engine = engine
        uiView.attachToHostIfNeeded()
    }

    static func dismantleUIView(_ uiView: CRTPassiveTouchAnchorView, coordinator: ()) {
        uiView.detach()
        uiView.engine?.clearAllTouches()
    }
}

// MARK: - ViewModifier Isolado (Impede Reavaliação da Árvore SwiftUI a 60 Hz)

struct CRTScreenEffectModifier: ViewModifier {
    let transform: CRTBarrelTransform
    let barrelConfig: CRTBarrelConfig
    let touchEngine: CRTMagneticTouchEngine
    let textInputBridge: CRTTextInputBridge

    func body(content: Content) -> some View {
        let touchConfig = touchEngine.config
        let payload = touchEngine.shaderPayload
        let keyboardStartY = textInputBridge.keyboardStartYInCRT
        let sampleOffset = CGSize(
            width: transform.maxSampleOffset.width + touchConfig.extraSampleOffset,
            height: transform.maxSampleOffset.height + touchConfig.extraSampleOffset
        )

        content
            .layerEffect(
                ShaderLibrary.crtScreenEffect(
                    .float2(transform.openingRect.minX, transform.openingRect.minY),
                    .float2(transform.openingRect.width, transform.openingRect.height),
                    .float(Float(transform.curvature)),
                    .float(Float(barrelConfig.vignetteStrength)),
                    .float(Float(barrelConfig.bezelShadowStrength)),
                    .float(Float(barrelConfig.glassGlareStrength)),
                    .floatArray(payload),
                    .float4(
                        Float(touchConfig.isEnabled ? touchConfig.radius : 0),
                        Float(touchConfig.force),
                        Float(touchConfig.falloff),
                        Float(touchConfig.maxDispBudget)
                    ),
                    .float4(
                        Float(touchConfig.vortex),
                        Float(touchConfig.rgbSplit),
                        Float(touchConfig.centerLuminance),
                        Float(touchConfig.scanlines)
                    ),
                    .float4(
                        Float(keyboardStartY),
                        Float(touchConfig.keyboardAreaAttenuation),
                        Float(touchConfig.maxSplitBudget),
                        0
                    )
                ),
                maxSampleOffset: sampleOffset
            )
    }
}
