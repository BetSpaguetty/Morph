import SwiftUI
import QuartzCore
import Observation

// MARK: - Motor Multitoque com Física Independente e Auto-Pausa a 60 Hz

@MainActor
@Observable
final class CRTMagneticTouchEngine {
    static let maxSlots = 16
    /// Buffer mínimo não-vazio (1 float => 0 slots no shader) para evitar buffers vazios no Metal.
    static let idlePayload: [Float] = [0]

    struct TouchSlot {
        var touchID: ObjectIdentifier? // nil após soltar o dedo (em dissipação)
        var position: CGPoint
        var targetPosition: CGPoint
        var intensity: CGFloat
        var releaseTime: CFTimeInterval
        var initialReleaseIntensity: CGFloat

        var isActive: Bool { touchID != nil }
    }

    var config: CRTTouchConfig
    private(set) var shaderPayload: [Float] = CRTMagneticTouchEngine.idlePayload

    @ObservationIgnored var openingTransform: CRTBarrelTransform = .identity
    @ObservationIgnored private var slots: [TouchSlot] = []
    @ObservationIgnored private var scratchPayload: [Float] = []
    @ObservationIgnored private nonisolated(unsafe) var displayLink: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval = 0

    init(config: CRTTouchConfig = .default, installDisplayLink: Bool = true) {
        self.config = config
        self.slots.reserveCapacity(Self.maxSlots)
        self.scratchPayload.reserveCapacity(Self.maxSlots * 3)
        if installDisplayLink {
            setupDisplayLink()
        }
        #if DEBUG
        Self.verifyTouchEngineOnce()
        #endif
    }

    deinit {
        displayLink?.invalidate()
    }

    private func setupDisplayLink() {
        let proxy = CRTDisplayLinkProxy { [weak self] timestamp in
            self?.step(timestamp: timestamp, now: CACurrentMediaTime())
        }
        let link = CADisplayLink(target: proxy, selector: #selector(CRTDisplayLinkProxy.onTick(link:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        self.displayLink = link
    }

    func handleTouchesBegan(_ updates: [(ObjectIdentifier, CGPoint)]) {
        guard config.isEnabled else { return }
        var changed = false
        for (id, point) in updates {
            if registerTouchBegan(id: id, at: point) {
                changed = true
            }
        }
        if changed {
            publishPayload()
            updateDisplayLinkState()
        }
    }

    func handleTouchesMoved(_ updates: [(ObjectIdentifier, CGPoint)], now: CFTimeInterval = CACurrentMediaTime()) {
        guard config.isEnabled else { return }
        var changed = false
        for (id, point) in updates {
            if let idx = slots.firstIndex(where: { $0.touchID == id }) {
                if !openingTransform.containsVisibleScreenPoint(point) {
                    beginDecay(at: idx, now: now)
                    changed = true
                    continue
                }
                slots[idx].targetPosition = point
                slots[idx].intensity = 1.0
                if config.followSpeed >= 0.95 {
                    slots[idx].position = point
                }
                changed = true
            } else if registerTouchBegan(id: id, at: point) {
                // Dedo entrou deslizando da borda para dentro do vidro
                changed = true
            }
        }
        if changed {
            publishPayload()
            updateDisplayLinkState()
        }
    }

    func handleTouchesEnded(_ ids: [ObjectIdentifier], now: CFTimeInterval = CACurrentMediaTime()) {
        var changed = false
        for id in ids {
            if let idx = slots.firstIndex(where: { $0.touchID == id }) {
                beginDecay(at: idx, now: now)
                changed = true
            }
        }
        if changed {
            updateDisplayLinkState()
        }
    }

    func clearAllTouches() {
        slots.removeAll(keepingCapacity: true)
        lastTimestamp = 0
        displayLink?.isPaused = true
        if shaderPayload != Self.idlePayload {
            shaderPayload = Self.idlePayload
        }
    }

    @discardableResult
    private func registerTouchBegan(id: ObjectIdentifier, at point: CGPoint) -> Bool {
        guard openingTransform.containsVisibleScreenPoint(point) else { return false }

        if let existing = slots.firstIndex(where: { $0.touchID == id }) {
            slots[existing].position = point
            slots[existing].targetPosition = point
            slots[existing].intensity = 1.0
            return true
        }

        let newSlot = TouchSlot(
            touchID: id,
            position: point,
            targetPosition: point,
            intensity: 1.0,
            releaseTime: 0,
            initialReleaseIntensity: 1.0
        )

        if slots.count < Self.maxSlots {
            slots.append(newSlot)
        } else if let victim = weakestDecayingSlotIndex() {
            slots[victim] = newSlot
        } else {
            // Limite de hardware (<= 11 dedos no iPad) nunca atinge maxSlots = 16 em uso normal
            slots[0] = newSlot
        }
        return true
    }

    private func weakestDecayingSlotIndex() -> Int? {
        var bestIdx: Int?
        var lowestIntensity: CGFloat = .greatestFiniteMagnitude
        for idx in slots.indices where !slots[idx].isActive {
            if slots[idx].intensity < lowestIntensity {
                lowestIntensity = slots[idx].intensity
                bestIdx = idx
            }
        }
        return bestIdx
    }

    private func beginDecay(at index: Int, now: CFTimeInterval) {
        slots[index].touchID = nil
        slots[index].releaseTime = now
        slots[index].initialReleaseIntensity = slots[index].intensity
    }

    func step(timestamp: CFTimeInterval, now: CFTimeInterval) {
        let dt: CGFloat
        if lastTimestamp == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(max(0, timestamp - lastTimestamp)), 0.1)
        }
        lastTimestamp = timestamp

        let duration = max(config.decayTime, 0.05)
        let immediateFollow = config.followSpeed >= 0.95
        let smoothing = immediateFollow ? 1.0 : min(1.0, dt * (15.0 + config.followSpeed * 130.0))

        var writeIdx = 0
        for readIdx in slots.indices {
            var slot = slots[readIdx]
            if slot.isActive {
                if immediateFollow {
                    slot.position = slot.targetPosition
                } else {
                    let dx = slot.targetPosition.x - slot.position.x
                    let dy = slot.targetPosition.y - slot.position.y
                    if (dx * dx + dy * dy) < 0.04 {
                        slot.position = slot.targetPosition
                    } else {
                        slot.position.x += dx * smoothing
                        slot.position.y += dy * smoothing
                    }
                }
                slot.intensity = 1.0
                slots[writeIdx] = slot
                writeIdx += 1
            } else {
                let elapsed = CGFloat(max(0, now - slot.releaseTime))
                let progress = elapsed / duration
                if progress < 1.0 {
                    let baseDecay = pow(1.0 - progress, 2.5)
                    let oscillation: CGFloat
                    if config.elasticity > 0 {
                        oscillation = sin(progress * .pi * 14.0) * config.elasticity * 0.30 * (1.0 - progress)
                    } else {
                        oscillation = 0
                    }
                    slot.intensity = min(max(slot.initialReleaseIntensity * (baseDecay + oscillation), 0.0), 1.5)
                    slots[writeIdx] = slot
                    writeIdx += 1
                }
            }
        }

        if writeIdx < slots.count {
            slots.removeSubrange(writeIdx..<slots.count)
        }

        publishPayload()
        updateDisplayLinkState()
    }

    private func publishPayload() {
        guard config.isEnabled, !slots.isEmpty else {
            if shaderPayload != Self.idlePayload {
                shaderPayload = Self.idlePayload
            }
            return
        }

        scratchPayload.removeAll(keepingCapacity: true)
        for slot in slots where slot.intensity > 0.001 {
            scratchPayload.append(Float(slot.position.x))
            scratchPayload.append(Float(slot.position.y))
            scratchPayload.append(Float(slot.intensity))
        }

        let next = scratchPayload.isEmpty ? Self.idlePayload : scratchPayload
        if shaderPayload != next {
            shaderPayload = next
        }
    }

    private func updateDisplayLinkState() {
        let needsTick = slots.contains { slot in
            if !slot.isActive { return true }
            if config.followSpeed < 0.95 {
                let dx = slot.targetPosition.x - slot.position.x
                let dy = slot.targetPosition.y - slot.position.y
                return (dx * dx + dy * dy) >= 0.04
            }
            return false
        }

        if needsTick {
            displayLink?.isPaused = false
        } else {
            displayLink?.isPaused = true
            lastTimestamp = 0
        }
    }

    // MARK: - Autoverificação Matemática (DEBUG)

    #if DEBUG
    private static var didVerifyEngine = false

    private static func verifyTouchEngineOnce() {
        guard !didVerifyEngine else { return }
        didVerifyEngine = true

        // 1. Parâmetros calibrados de referência
        let cfg = CRTTouchConfig.default
        assert(cfg.radius == 40.0)
        assert(abs(cfg.force - 0.10) < 1e-6)
        assert(abs(cfg.falloff - 1.00) < 1e-6)
        assert(abs(cfg.vortex - (-0.05)) < 1e-6)
        assert(abs(cfg.rgbSplit - 1.0) < 1e-6)
        assert(abs(cfg.centerLuminance - (-0.04)) < 1e-6)
        assert(abs(cfg.scanlines - 0.35) < 1e-6)
        assert(abs(cfg.decayTime - 0.30) < 1e-6)
        assert(abs(cfg.elasticity - 0.25) < 1e-6)
        assert(abs(cfg.keyboardAreaAttenuation - 0.15) < 1e-6)
        assert(abs(cfg.followSpeed - 1.0) < 1e-6)
        assert(cfg.extraSampleOffset >= ceil(cfg.maxDispBudget + cfg.maxSplitBudget))

        // 2. Filtro SDF da moldura (aceita vidro, rejeita borda_tv e cantos curvos)
        let transform = CRTBarrelTransform(containerSize: CGSize(width: 1180, height: 820), curvature: 0.07)
        assert(transform.containsVisibleScreenPoint(CGPoint(x: transform.openingRect.midX, y: transform.openingRect.midY)))
        assert(transform.containsVisibleScreenPoint(CGPoint(x: transform.openingRect.maxX, y: transform.openingRect.midY)))
        assert(!transform.containsVisibleScreenPoint(CGPoint(x: transform.openingRect.minX, y: transform.openingRect.minY)))
        assert(!transform.containsVisibleScreenPoint(CGPoint(x: 10, y: 10)))

        // 3. Multitoque simultâneo + rejeição de toque na borda
        let engine = CRTMagneticTouchEngine(config: cfg, installDisplayLink: false)
        engine.openingTransform = transform

        final class DummyTouch {}
        let t1 = DummyTouch(), t2 = DummyTouch(), t3 = DummyTouch(), tBezel = DummyTouch()
        let id1 = ObjectIdentifier(t1), id2 = ObjectIdentifier(t2), id3 = ObjectIdentifier(t3), idBezel = ObjectIdentifier(tBezel)

        let p1 = CGPoint(x: transform.openingRect.midX - 80, y: transform.openingRect.midY)
        let p2 = CGPoint(x: transform.openingRect.midX + 80, y: transform.openingRect.midY)
        let p3 = CGPoint(x: transform.openingRect.midX, y: transform.openingRect.midY + 60)

        engine.handleTouchesBegan([(id1, p1), (id2, p2), (id3, p3), (idBezel, CGPoint(x: 8, y: 8))])
        assert(engine.shaderPayload.count == 9) // 3 toques dentro; toque na borda ignorado

        // 4. Dissipação independente de 1 dedo enquanto os outros permanecem ativos
        engine.handleTouchesEnded([id1], now: 10.0)
        engine.step(timestamp: 10.15, now: 10.15)
        assert(engine.shaderPayload.count == 9)
        assert(engine.shaderPayload[2] > 0 && engine.shaderPayload[2] < 1.0)
        assert(engine.shaderPayload[5] == 1.0 && engine.shaderPayload[8] == 1.0)

        engine.step(timestamp: 10.35, now: 10.35) // > decayTime (0.30s)
        assert(engine.shaderPayload.count == 6) // id1 removido; id2 e id3 seguem ativos

        // Dedo deslizando para fora do vidro entra em decay sem grudar na borda
        engine.handleTouchesMoved([(id2, CGPoint(x: 4, y: 4))], now: 10.40)
        engine.handleTouchesEnded([id3], now: 10.40)
        engine.step(timestamp: 10.75, now: 10.75)
        assert(engine.shaderPayload == Self.idlePayload)

        // 5. Prioridade do pool: dedos ativos nunca são removidos quando há rastros em decay
        var activeDummies: [DummyTouch] = []
        var decayDummies: [DummyTouch] = []
        for i in 0..<10 {
            let d = DummyTouch()
            decayDummies.append(d)
            let pt = CGPoint(x: transform.openingRect.midX + CGFloat(i * 5), y: transform.openingRect.midY)
            let oid = ObjectIdentifier(d)
            engine.handleTouchesBegan([(oid, pt)])
            engine.handleTouchesEnded([oid], now: 20.0 + Double(i) * 0.01)
        }
        engine.step(timestamp: 20.12, now: 20.12)
        for i in 0..<10 {
            let a = DummyTouch()
            activeDummies.append(a)
            let pt = CGPoint(x: transform.openingRect.midX - CGFloat(i * 5), y: transform.openingRect.midY)
            engine.handleTouchesBegan([(ObjectIdentifier(a), pt)])
        }
        assert(engine.slots.count == Self.maxSlots)
        let activeCount = engine.slots.filter(\.isActive).count
        assert(activeCount == 10)

        // 6. Resposta ao movimento com inércia (followSpeed < 0.95)
        var inertiaCfg = cfg
        inertiaCfg.followSpeed = 0.20
        let inertiaEngine = CRTMagneticTouchEngine(config: inertiaCfg, installDisplayLink: false)
        inertiaEngine.openingTransform = transform
        let tMove = DummyTouch()
        let idMove = ObjectIdentifier(tMove)
        let startPt = CGPoint(x: transform.openingRect.midX, y: transform.openingRect.midY)
        let endPt = CGPoint(x: transform.openingRect.midX + 100, y: transform.openingRect.midY)
        inertiaEngine.handleTouchesBegan([(idMove, startPt)])
        inertiaEngine.handleTouchesMoved([(idMove, endPt)], now: 30.0)
        assert(inertiaEngine.shaderPayload[0] == Float(startPt.x)) // ainda não teleportou
        inertiaEngine.step(timestamp: 30.016, now: 30.016)
        assert(inertiaEngine.shaderPayload[0] > Float(startPt.x) && inertiaEngine.shaderPayload[0] < Float(endPt.x))
    }
    #endif
}

private final class CRTDisplayLinkProxy: NSObject {
    private let callback: @MainActor (CFTimeInterval) -> Void

    init(callback: @escaping @MainActor (CFTimeInterval) -> Void) {
        self.callback = callback
    }

    @objc func onTick(link: CADisplayLink) {
        MainActor.assumeIsolated {
            callback(link.timestamp)
        }
    }
}
