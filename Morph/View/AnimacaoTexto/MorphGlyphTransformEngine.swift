import SwiftUI

// MARK: - Primitivo 1: Motor de Transformação por Caractere (Cobre ~65 Efeitos + Tetos CRT)

struct MorphGlyphTransform: Equatable, Sendable {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var rotationDeg: Double = 0
    var rotateXDeg: Double = 0
    var rotateYDeg: Double = 0
    var skewXDeg: Double = 0
    var skewYDeg: Double = 0
    var opacity: Double = 1
    var blur: CGFloat = 0
    var anchor: UnitPoint = .center
    var glowRadius: CGFloat = 0
    var glowOpacity: Double = 0

    static let identity = MorphGlyphTransform()

    var isFinite: Bool {
        dx.isFinite && dy.isFinite && scaleX.isFinite && scaleY.isFinite
            && rotationDeg.isFinite && rotateXDeg.isFinite && rotateYDeg.isFinite
            && skewXDeg.isFinite && skewYDeg.isFinite && opacity.isFinite
            && blur.isFinite && glowRadius.isFinite && glowOpacity.isFinite
    }

    func combined(with other: MorphGlyphTransform) -> MorphGlyphTransform {
        MorphGlyphTransform(
            dx: dx + other.dx,
            dy: dy + other.dy,
            scaleX: scaleX * other.scaleX,
            scaleY: scaleY * other.scaleY,
            rotationDeg: rotationDeg + other.rotationDeg,
            rotateXDeg: rotateXDeg + other.rotateXDeg,
            rotateYDeg: rotateYDeg + other.rotateYDeg,
            skewXDeg: skewXDeg + other.skewXDeg,
            skewYDeg: skewYDeg + other.skewYDeg,
            opacity: opacity * other.opacity,
            blur: blur + other.blur,
            anchor: other.anchor != .center ? other.anchor : anchor,
            glowRadius: max(glowRadius, other.glowRadius),
            glowOpacity: max(glowOpacity, other.glowOpacity)
        )
    }

    /// Aplica os tetos globais de palco CRT em estado contínuo/estático para evitar colisão entre linhas.
    func clampedForSteadyState() -> MorphGlyphTransform {
        var copy = self
        copy.dy = min(24, max(-24, copy.dy))
        copy.scaleX = min(1.32, max(0.62, copy.scaleX))
        copy.scaleY = min(1.48, max(0.62, copy.scaleY))
        copy.opacity = min(1.0, max(0.55, copy.opacity))
        copy.blur = min(4.0, max(0, copy.blur))
        return copy
    }
}

// MARK: - Curvas de Easing

enum MorphEasing {
    static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3.0 - 2.0 * t)
    }

    static func easeOutCubic(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        let u = 1.0 - t
        return 1.0 - u * u * u
    }

    static func easeInCubic(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * t
    }

    static func easeOutBack(_ x: Double, overshoot: Double = 1.45) -> Double {
        let t = min(max(x, 0), 1)
        let u = t - 1.0
        return 1.0 + (overshoot + 1.0) * u * u * u + overshoot * u * u
    }
}

// MARK: - Avaliador de Todos os Efeitos de Caractere (Estático + Entrada 1x + Contínuo)

enum MorphGlyphTransformEngine {
    static func entranceDuration(for effectID: MorphEffectID) -> Double {
        switch effectID {
        case .andSpeedDash, .ativBounce, .ativBounceInRight, .ativFlipIn, .pesoDropIn, .fluidWaterDrop:
            return 0.60
        case .tensGlitch:
            return 0.48
        case .andRollIn, .ativShakeY, .tensTada, .tensSqueezeExpand, .volGritoExplosivo, .ativRicocheteLateral, .kwHeartbeatBurst:
            return 0.80
        case .kwBolhasSabao:
            return 0.95
        case .kwRoloCassino, .kwTracoParaTinta:
            return 1.10
        case .luzGlowIn, .luzFlicker, .luzFlickerIn, .abertTrackingContract, .distArrastoTemporal, .pesoAfundarComPeso, .kwPenduloNewton:
            return 1.15
        case .valImpressaoCMYK:
            return 1.30
        default:
            return 0.92
        }
    }

    static func charEntranceProgress(elapsed: Double, charIndex: Int, duration: Double, delayStep: Double) -> Double {
        let raw = (elapsed - Double(charIndex) * delayStep) / max(0.05, duration)
        return min(max(raw, 0), 1)
    }

    static func wholeEntranceProgress(elapsed: Double, duration: Double) -> Double {
        min(max(elapsed / max(0.05, duration), 0), 1)
    }

    /// Avalia a transformação combinada (Canal 1 Estático + Canal 4 Contínuo + Canal 3 Entrada 1x) para uma letra.
    static func evaluate(
        plan: WordAnimationPlan,
        charIndex: Int,
        totalChars: Int,
        elapsed: Double
    ) -> MorphGlyphTransform {
        let effectiveTime = elapsed * plan.speedMultiplier

        var steady = MorphGlyphTransform.identity

        if let staticSlot = plan.staticStructure {
            steady = steady.combined(with: evaluateStatic(
                effectID: staticSlot.effectID,
                intensity: staticSlot.intensity,
                charIndex: charIndex,
                totalChars: totalChars
            ))
        }

        if let continuousSlot = plan.continuous {
            steady = steady.combined(with: evaluateContinuous(
                effectID: continuousSlot.effectID,
                intensity: continuousSlot.intensity,
                charIndex: charIndex,
                totalChars: totalChars,
                wordIndex: plan.wordIndex,
                time: effectiveTime
            ))
        }

        // Tetos seguros de palco CRT para o estado contínuo + estático
        steady = steady.clampedForSteadyState()

        guard let entranceSlot = plan.entrance else {
            return steady
        }

        let ent = evaluateEntrance(
            effectID: entranceSlot.effectID,
            intensity: entranceSlot.intensity,
            charIndex: charIndex,
            totalChars: totalChars,
            wordIndex: plan.wordIndex,
            elapsed: elapsed
        )
        return steady.combined(with: ent)
    }

    // MARK: Canal 1 — Geometria Estática

    static func evaluateStatic(
        effectID: MorphEffectID,
        intensity: Double,
        charIndex: Int,
        totalChars: Int
    ) -> MorphGlyphTransform {
        switch effectID {
        case .abertUltraCondensado:
            // Mantém legibilidade sob as bolinhas de 6pt do CRT (scaleX >= 0.65, scaleY <= 1.45).
            let k = min(1.0, max(0.45, intensity * 0.85))
            return MorphGlyphTransform(scaleX: 1.0 - 0.34 * k, scaleY: 1.0 + 0.42 * k)

        case .abertUltraEstirado:
            let k = min(1.0, max(0.45, intensity * 0.85))
            return MorphGlyphTransform(scaleX: 1.0 + 0.26 * k, scaleY: 1.0 - 0.22 * k)

        case .fluidDerretido:
            // Derretido SEM cores (conforme ressalva): estica cada letra para baixo a partir do topo.
            let unit = Double(MorphDeterministicHash.mix(charIndex, 880, 1) & 0xFFFF) / 65535.0
            let extra = (0.18 + unit * 0.28) * min(1.1, intensity)
            return MorphGlyphTransform(
                scaleX: 0.86,
                scaleY: min(1.48, 1.0 + extra),
                anchor: .top
            )

        case .kwArcoCurvado:
            let n = max(1, totalChars)
            let mid = Double(n - 1) * 0.5
            let maxD = max(1.0, mid)
            let norm = (Double(charIndex) - mid) / maxD
            return MorphGlyphTransform(
                dy: CGFloat((norm * norm - 0.5) * 24.0),
                rotationDeg: norm * 22.0
            )

        case .kwEscadaDiagonal:
            // Sobe da esquerda para a direita ("Escada - subida"), respeitando o teto vertical do palco CRT.
            let n = max(1, totalChars)
            let mid = Double(n - 1) * 0.5
            let stepY = min(5.5, 36.0 / Double(max(1, n - 1)))
            return MorphGlyphTransform(dy: CGFloat(-(Double(charIndex) - mid) * stepY))

        case .kwLinhaDesconstruida:
            let u1 = Double(MorphDeterministicHash.mix(charIndex, 1, 790) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(charIndex, 2, 791) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dy: CGFloat((u1 - 0.5) * 14.0),
                rotationDeg: (u2 - 0.5) * 13.0
            )

        default:
            return .identity
        }
    }

    // MARK: Canal 3 — Entradas 1x (terminam SEMPRE em opacity == 1.0)

    static func evaluateEntrance(
        effectID: MorphEffectID,
        intensity: Double,
        charIndex: Int,
        totalChars: Int,
        wordIndex: Int,
        elapsed: Double
    ) -> MorphGlyphTransform {
        let dur = entranceDuration(for: effectID)
        let n = max(1, totalChars)
        let mid = Double(n - 1) * 0.5
        let maxD = max(1.0, mid)
        let norm = (Double(charIndex) - mid) / maxD

        switch effectID {
        case .fragDespedacar:
            let p = MorphEasing.easeOutCubic(charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.03))
            let rem = 1.0 - p
            let u1 = Double(MorphDeterministicHash.mix(wordIndex, charIndex, 801) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(wordIndex, charIndex, 802) & 0xFFFF) / 65535.0
            let u3 = Double(MorphDeterministicHash.mix(wordIndex, charIndex, 803) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dx: CGFloat((u1 - 0.5) * 38.0 * rem),
                dy: CGFloat((u2 - 0.5) * 32.0 * rem),
                skewXDeg: (u3 - 0.5) * 42.0 * rem,
                opacity: min(1.0, p * 1.8)
            )

        case .fragDesabamento:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            if t >= 1.0 { return .identity }
            let buckle = sin(min(1.0, t / 0.65) * .pi)
            let recover = MorphEasing.easeOutCubic(t)
            let centerWeight = 1.0 - abs(norm)
            return MorphGlyphTransform(
                dx: CGFloat(-norm * 12.0 * buckle),
                dy: CGFloat(centerWeight * 24.0 * buckle - 18.0 * (1.0 - recover)),
                rotationDeg: -norm * 22.0 * buckle,
                opacity: min(1.0, t * 3.0)
            )

        case .ativBounceInRight:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            if t >= 1.0 { return .identity }
            let dx: Double
            if t < 0.6 {
                dx = 46.0 * (1.0 - MorphEasing.smoothstep(t / 0.6)) - 8.0 * MorphEasing.smoothstep(t / 0.6)
            } else if t < 0.8 {
                let k = (t - 0.6) / 0.2
                dx = -8.0 + 12.0 * k
            } else {
                let k = (t - 0.8) / 0.2
                dx = 4.0 * (1.0 - k)
            }
            return MorphGlyphTransform(dx: CGFloat(dx), opacity: min(1.0, t * 2.5))

        case .ativBounce:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.06)
            if t >= 1.0 { return .identity }
            let dy: Double
            if t < 0.5 {
                let k = MorphEasing.easeInCubic(t / 0.5)
                dy = -44.0 * (1.0 - k) + 12.0 * k
            } else if t < 0.75 {
                let k = MorphEasing.easeOutCubic((t - 0.5) / 0.25)
                dy = 12.0 * (1.0 - k) - 5.0 * k
            } else {
                let k = MorphEasing.smoothstep((t - 0.75) / 0.25)
                dy = -5.0 * (1.0 - k)
            }
            return MorphGlyphTransform(dy: CGFloat(dy), opacity: min(1.0, t * 2.5))

        case .ativFlipIn:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            let p = MorphEasing.smoothstep(t)
            return MorphGlyphTransform(rotateXDeg: -90.0 * (1.0 - p), opacity: min(1.0, t * 2.2), anchor: .bottom)

        case .ativShakeY:
            // Bug corrigido do catálogo original (#19): termina SEMPRE em opacity == 1.0.
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            if t >= 1.0 { return .identity }
            let damp = 1.0 - t
            let dy = sin(t * 10.0 * .pi) * 10.0 * damp
            return MorphGlyphTransform(dy: CGFloat(dy), opacity: min(1.0, t * 5.0))

        case .ativRicocheteLateral:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            if t >= 1.0 { return .identity }
            let (dx, dy, sx, sy): (Double, Double, Double, Double)
            if t < 0.5 {
                let k = MorphEasing.easeInCubic(t / 0.5)
                (dx, dy, sx, sy) = (-46.0 * (1.0 - k), -48.0 * (1.0 - k) + 6.0 * k, 1.0 - 0.1 * k, 1.0 + 0.14 * k)
            } else if t < 0.72 {
                let k = (t - 0.5) / 0.22
                let squash = sin(k * .pi)
                (dx, dy, sx, sy) = (0, 6.0 * (1.0 - k) - 16.0 * squash, 1.0 + 0.30 * (1.0 - k), 1.0 - 0.30 * (1.0 - k))
            } else {
                let k = MorphEasing.smoothstep((t - 0.72) / 0.28)
                (dx, dy, sx, sy) = (0, -12.0 * sin((1.0 - k) * .pi * 0.5), 1.0, 1.0)
            }
            return MorphGlyphTransform(dx: CGFloat(dx), dy: CGFloat(dy), scaleX: CGFloat(sx), scaleY: CGFloat(sy), opacity: min(1.0, t * 3.0), anchor: .bottom)

        case .ativCartasZigueZague:
            let p = MorphEasing.smoothstep(charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045))
            let rem = 1.0 - p
            let sway = sin(rem * 3.5 * .pi + Double(charIndex)) * 18.0 * rem
            return MorphGlyphTransform(
                dx: CGFloat(sway),
                dy: CGFloat(-52.0 * rem),
                rotateYDeg: sway * 2.0,
                opacity: min(1.0, p * 1.8)
            )

        case .tensTada:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.04)
            if t >= 1.0 { return .identity }
            let scale: Double = t < 0.2 ? (1.0 - 0.1 * (t / 0.2)) : (t < 0.9 ? 1.10 : (1.10 - 0.10 * ((t - 0.9) / 0.1)))
            let rot: Double = t < 0.2 ? -3.0 : (t < 0.9 ? sin((t - 0.2) * 26.0) * 4.0 : 0.0)
            return MorphGlyphTransform(scaleX: CGFloat(scale), scaleY: CGFloat(scale), rotationDeg: rot, opacity: min(1.0, t * 6.0))

        case .tensGlitch:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.06)
            if t >= 1.0 { return .identity }
            let step = Int(t * 10.0)
            let dx: CGFloat = step.isMultiple(of: 2) ? -3.0 : 3.0
            let dy: CGFloat = (step / 2).isMultiple(of: 2) ? 2.5 : -2.5
            return MorphGlyphTransform(dx: dx, dy: dy, opacity: min(1.0, t * 8.0))

        case .tensSqueezeExpand:
            // Zero reflow: expansão/contração horizontal feita com offset(x:) relativo ao centro da palavra.
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.035)
            if t >= 1.0 { return .identity }
            let (sy, spread): (Double, Double)
            if t < 0.5 {
                let k = MorphEasing.smoothstep(t / 0.5)
                sy = 0.18 + 1.02 * k
                spread = -7.0 * (1.0 - k) + 5.0 * k
            } else {
                let k = MorphEasing.smoothstep((t - 0.5) / 0.5)
                sy = 1.20 - 0.20 * k
                spread = 5.0 * (1.0 - k)
            }
            return MorphGlyphTransform(dx: CGFloat((Double(charIndex) - mid) * spread), scaleY: CGFloat(sy), opacity: min(1.0, t * 3.0))

        case .tensTensaoContida:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            if t >= 1.0 { return .identity }
            let (sx, sy, vib): (Double, Double, Double)
            if t < 0.52 {
                let k = MorphEasing.smoothstep(t / 0.52)
                (sx, sy, vib) = (1.0 + 0.34 * k, 1.0 - 0.52 * k, sin(t * 90.0) * 2.4 * k)
            } else {
                let k = MorphEasing.easeOutBack((t - 0.52) / 0.48, overshoot: 1.2)
                (sx, sy, vib) = (1.34 - 0.34 * k, 0.48 + 0.52 * k, 0)
            }
            return MorphGlyphTransform(dx: CGFloat(vib), scaleX: CGFloat(max(0.4, sx)), scaleY: CGFloat(max(0.25, sy)), opacity: min(1.0, t * 4.0), anchor: .bottom)

        case .andSpeedDash:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.04)
            if t >= 1.0 { return .identity }
            if t < 0.7 {
                let k = MorphEasing.smoothstep(t / 0.7)
                return MorphGlyphTransform(dx: CGFloat(-52.0 * (1.0 - k) + 4.0 * k), skewXDeg: -38.0 + 30.0 * k, opacity: min(1.0, t / 0.5))
            } else {
                let k = MorphEasing.smoothstep((t - 0.7) / 0.3)
                return MorphGlyphTransform(dx: CGFloat(4.0 * (1.0 - k)), skewXDeg: -8.0 * (1.0 - k), opacity: 1.0)
            }

        case .andRollIn:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            let p = MorphEasing.smoothstep(t)
            return MorphGlyphTransform(dx: CGFloat(-40.0 * (1.0 - p)), rotationDeg: -120.0 * (1.0 - p), opacity: min(1.0, t * 2.2))

        case .calChamaAscendente:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            let p = MorphEasing.smoothstep(t)
            let heat = max(0, 1.0 - max(0, (t - 0.35) / 0.65))
            return MorphGlyphTransform(
                dx: CGFloat(sin(t * 9.0 + Double(charIndex)) * 5.0 * (1.0 - p)),
                dy: CGFloat(36.0 * (1.0 - p)),
                opacity: min(1.0, t * 2.2),
                glowRadius: CGFloat(heat * 10.0),
                glowOpacity: heat * 0.85
            )

        case .calLancamentoFoguete:
            let raw = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            let p = MorphEasing.easeOutCubic(raw)
            let trail = (raw > 0.02 && raw < 0.85) ? (1.0 - raw) : 0.0
            return MorphGlyphTransform(
                dy: CGFloat(46.0 * (1.0 - p)),
                scaleX: CGFloat(1.0 - trail * 0.16),
                scaleY: CGFloat(1.0 + trail * 0.28),
                opacity: min(1.0, raw * 3.0)
            )

        case .calArrepioGelado:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.03)
            let p = MorphEasing.smoothstep(t)
            let rem = 1.0 - p
            let tick = Int(elapsed * 36.0)
            let u = Double(MorphDeterministicHash.mix(tick, charIndex, 830) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dx: CGFloat((u - 0.5) * 9.0 * rem),
                scaleX: CGFloat(0.74 + 0.26 * p),
                scaleY: CGFloat(1.0 + 0.14 * rem),
                opacity: min(1.0, p * 2.2)
            )

        case .luzGlowIn:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            let glow = t <= 0.5 ? (t * 2.0) : ((1.0 - t) * 2.0)
            return MorphGlyphTransform(
                opacity: min(1.0, t * 2.2),
                glowRadius: CGFloat(max(0, glow) * 14.0 * intensity),
                glowOpacity: max(0, glow) * 0.9
            )

        case .luzFlicker:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.04)
            if t >= 0.24 { return .identity }
            let slot = Int(t * 48.0)
            return MorphGlyphTransform(opacity: slot.isMultiple(of: 2) ? 0.12 : 1.0, glowRadius: slot.isMultiple(of: 2) ? 0 : 7, glowOpacity: slot.isMultiple(of: 2) ? 0 : 0.7)

        case .luzFlickerIn:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            if t >= 0.52 { return .identity }
            let slot = Int(t * 10.0)
            return MorphGlyphTransform(opacity: slot.isMultiple(of: 2) ? 0.15 : 1.0, glowRadius: slot.isMultiple(of: 2) ? 0 : 8, glowOpacity: slot.isMultiple(of: 2) ? 0 : 0.75)

        case .abertTrackingContract:
            // Zero reflow: letras convergem do centro com offset(x:) sem mexer no layout do MorphFlowLayout.
            let p = MorphEasing.easeOutCubic(wholeEntranceProgress(elapsed: elapsed, duration: dur))
            let rem = 1.0 - p
            return MorphGlyphTransform(dx: CGFloat((Double(charIndex) - mid) * 14.0 * rem), opacity: min(1.0, p * 1.8))

        case .distEngrenagemRelogio:
            let raw = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            let steps = 6.0
            let q = raw >= 1.0 ? 1.0 : (floor(raw * steps) + MorphEasing.smoothstep((raw * steps).truncatingRemainder(dividingBy: 1.0))) / steps
            return MorphGlyphTransform(
                rotationDeg: -145.0 * (1.0 - q),
                opacity: min(1.0, raw * 3.0),
                anchor: UnitPoint(x: 0.5, y: 1.5)
            )

        case .distArrastoTemporal:
            let p = MorphEasing.smoothstep(charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.04))
            let rem = 1.0 - p
            return MorphGlyphTransform(
                dx: CGFloat(-28.0 * rem),
                scaleX: CGFloat(1.0 + rem * 1.15),
                opacity: min(1.0, p * 1.6),
                blur: CGFloat(rem * 3.8),
                anchor: .trailing
            )

        case .volGritoExplosivo:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            if t >= 1.0 { return .identity }
            let blast = MorphEasing.easeOutBack(min(1.0, t / 0.65), overshoot: 1.35)
            let settle = t > 0.65 ? ((t - 0.65) / 0.35) * 0.24 : 0.0
            let scale = max(0.45, 0.50 + 0.74 * blast - settle)
            let shake = (t > 0.25 && t < 0.75) ? sin(t * 110.0) * 3.8 * (1.0 - (t - 0.25) / 0.5) : 0.0
            return MorphGlyphTransform(dx: CGFloat(shake), dy: CGFloat(-shake * 0.5), scaleX: CGFloat(scale), scaleY: CGFloat(scale), opacity: min(1.0, t * 3.0))

        case .pesoDropIn:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.05)
            if t >= 1.0 { return .identity }
            let dy: Double
            if t < 0.6 {
                let k = MorphEasing.easeInCubic(t / 0.6)
                dy = -48.0 * (1.0 - k) + 8.0 * k
            } else if t < 0.8 {
                let k = (t - 0.6) / 0.2
                dy = 8.0 * (1.0 - k) - 4.0 * k
            } else {
                let k = (t - 0.8) / 0.2
                dy = -4.0 * (1.0 - k)
            }
            return MorphGlyphTransform(dy: CGFloat(dy), opacity: min(1.0, t * 3.0))

        case .pesoRastroVertical:
            let p = MorphEasing.easeOutCubic(charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.04))
            return MorphGlyphTransform(dy: CGFloat(-44.0 * (1.0 - p)), opacity: min(1.0, p * 1.8))

        case .pesoEsmagar:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            if t >= 1.0 { return .identity }
            let (dy, sx, sy): (Double, Double, Double)
            if t < 0.35 {
                let k = MorphEasing.easeInCubic(t / 0.35)
                (dy, sx, sy) = (-48.0 * (1.0 - k), 1.0, 1.0 + 0.18 * k)
            } else if t < 0.58 {
                let k = (t - 0.35) / 0.23
                let smash = sin(k * .pi)
                (dy, sx, sy) = (6.0 * smash, 1.0 + 0.42 * smash, 1.0 - 0.58 * smash)
            } else {
                let k = MorphEasing.smoothstep((t - 0.58) / 0.42)
                (dy, sx, sy) = (0, 1.0 + 0.12 * (1.0 - k), 1.0 - 0.12 * (1.0 - k))
            }
            return MorphGlyphTransform(dy: CGFloat(dy), scaleX: CGFloat(sx), scaleY: CGFloat(max(0.2, sy)), opacity: min(1.0, t * 4.0), anchor: .bottom)

        case .pesoAfundarComPeso:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            let settledY = min(20.0, 14.0 * intensity)
            if t >= 1.0 {
                return MorphGlyphTransform(dy: CGFloat(settledY))
            }
            let (dy, sy): (Double, Double)
            if t < 0.65 {
                let k = MorphEasing.easeInCubic(t / 0.65)
                dy = -26.0 * (1.0 - k) + settledY * 0.85 * k
                sy = 1.04 - 0.14 * k
            } else {
                let k = MorphEasing.easeOutCubic((t - 0.65) / 0.35)
                dy = settledY * (0.85 + 0.15 * k)
                sy = 0.90 + 0.10 * k
            }
            return MorphGlyphTransform(dy: CGFloat(dy), scaleY: CGFloat(sy), opacity: min(1.0, t * 3.0), anchor: .bottom)

        case .fluidWaterDrop:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.045)
            if t >= 1.0 { return .identity }
            if t < 0.5 {
                let k = MorphEasing.easeInCubic(t / 0.5)
                return MorphGlyphTransform(
                    dy: CGFloat(-52.0 * (1.0 - k)),
                    scaleX: CGFloat(0.25 + 1.08 * k),
                    scaleY: CGFloat(1.65 - 1.05 * k),
                    opacity: min(1.0, t * 3.0)
                )
            } else {
                let k = MorphEasing.easeOutCubic((t - 0.5) / 0.5)
                return MorphGlyphTransform(
                    scaleX: CGFloat(1.33 - 0.33 * k),
                    scaleY: CGFloat(0.60 + 0.40 * k),
                    opacity: 1.0
                )
            }

        case .valCaleidoscopioPrismatico:
            let p = MorphEasing.easeOutCubic(wholeEntranceProgress(elapsed: elapsed, duration: dur))
            return MorphGlyphTransform(opacity: max(0.0, (p - 0.20) / 0.80))

        case .valCascataArcoIris:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.05)
            let p = MorphEasing.easeOutBack(t, overshoot: 1.15)
            return MorphGlyphTransform(dy: CGFloat(-38.0 * (1.0 - p)), opacity: min(1.0, t * 2.5))

        case .valImpressaoCMYK:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            let kP = MorphEasing.smoothstep(min(1.0, max(0.0, (t - 0.58) / 0.42)))
            return MorphGlyphTransform(opacity: kP)

        case .kwHeartbeatBurst:
            // 79. Heartbeat Burst: 0(0.5, a=0) -> 0.3(1.2, a=1) -> 0.5(0.9) -> 0.7(1.1) -> 1.0(1.0)
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.05)
            if t >= 1.0 { return .identity }
            let scale: Double
            let alpha: Double
            if t < 0.3 {
                let k = MorphEasing.smoothstep(t / 0.3)
                scale = 0.5 + 0.7 * k
                alpha = k
            } else if t < 0.5 {
                let k = MorphEasing.smoothstep((t - 0.3) / 0.2)
                scale = 1.2 - 0.3 * k
                alpha = 1.0
            } else if t < 0.7 {
                let k = MorphEasing.smoothstep((t - 0.5) / 0.2)
                scale = 0.9 + 0.2 * k
                alpha = 1.0
            } else {
                let k = MorphEasing.smoothstep((t - 0.7) / 0.3)
                scale = 1.1 - 0.1 * k
                alpha = 1.0
            }
            return MorphGlyphTransform(scaleX: CGFloat(scale), scaleY: CGFloat(scale), opacity: alpha)

        case .kwRoloCassino:
            let t = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.05)
            if t >= 1.0 { return .identity }
            let spinning = t > 0.01 && t < 0.85
            let dy: Double = spinning
                ? ((t * 24.0).truncatingRemainder(dividingBy: 1.0) - 0.5) * 16.0
                : sin(((t - 0.85) / 0.15) * .pi) * 6.0
            return MorphGlyphTransform(
                dy: CGFloat(dy),
                opacity: t > 0.01 ? 1.0 : 0.0,
                blur: spinning ? 1.6 : 0.0
            )

        case .kwPenduloNewton:
            let t = wholeEntranceProgress(elapsed: elapsed, duration: dur)
            if t >= 1.0 { return .identity }
            let offsetX: Double
            if charIndex == 0 {
                let swing = MorphEasing.easeInCubic(min(1.0, t / 0.35))
                offsetX = -46.0 * (1.0 - swing)
            } else if charIndex == n - 1 {
                let kick = t > 0.55 ? sin(min(1.0, (t - 0.55) / 0.45) * .pi) : 0.0
                offsetX = kick * 30.0
            } else {
                let wavePos = 0.35 + (Double(charIndex) / Double(max(1, n - 1))) * 0.22
                let pulse = max(0.0, 1.0 - abs(t - wavePos) / 0.08)
                offsetX = pulse * 6.0
            }
            return MorphGlyphTransform(
                dx: CGFloat(offsetX),
                rotationDeg: offsetX * 0.24,
                opacity: min(1.0, t * 4.0),
                anchor: .top
            )

        case .kwBolhasSabao:
            let raw = charEntranceProgress(elapsed: elapsed, charIndex: charIndex, duration: dur, delayStep: 0.05)
            if raw >= 1.0 { return .identity }
            let p = MorphEasing.smoothstep(raw)
            let inBubble = raw > 0.02 && raw < 0.78
            let scale = inBubble
                ? (0.45 + 0.40 * p)
                : (1.0 + sin(min(1.0, (raw - 0.78) / 0.22) * .pi) * 0.20)
            return MorphGlyphTransform(
                dx: CGFloat(sin(raw * 6.0 + Double(charIndex)) * 7.0 * (1.0 - p)),
                dy: CGFloat(38.0 * (1.0 - p)),
                scaleX: CGFloat(scale),
                scaleY: CGFloat(scale),
                opacity: min(1.0, raw * 3.0)
            )

        default:
            return .identity
        }
    }

    // MARK: Canal 4 — Movimentos Contínuos (loops 60fps, nunca zeram opacidade)

    static func evaluateContinuous(
        effectID: MorphEffectID,
        intensity: Double,
        charIndex: Int,
        totalChars: Int,
        wordIndex: Int,
        time: Double
    ) -> MorphGlyphTransform {
        let n = max(1, totalChars)
        let mid = Double(n - 1) * 0.5
        let maxD = max(1.0, mid)
        let norm = (Double(charIndex) - mid) / maxD

        switch effectID {
        case .fragDesintegracao:
            let tick = Int(time * 10.0)
            let loose = (Double(MorphDeterministicHash.mix(tick / 3, charIndex, 850) & 0xFFFF) / 65535.0) > 0.74
            let dy: CGFloat = loose ? CGFloat(4.5 * intensity) : 0
            let deg: Double = loose ? (charIndex.isMultiple(of: 2) ? 6.5 : -6.5) * intensity : 0
            return MorphGlyphTransform(dy: dy, rotationDeg: deg)

        case .ativPulaPulaElastico:
            let phase = (time / 1.8) * 2.0 * .pi
            let raw = sin(phase + Double(charIndex) * 0.55)
            let air = max(0, raw)
            let squash = max(0, -raw)
            return MorphGlyphTransform(
                dy: CGFloat(-air * 17.0 * intensity),
                scaleX: CGFloat(1.0 + (squash * 0.22 - air * 0.10) * intensity),
                scaleY: CGFloat(1.0 + (-squash * 0.22 + air * 0.16) * intensity),
                anchor: .bottom
            )

        case .ativMicroOrbitas:
            let phase = (time / 3.2) * 2.0 * .pi
            let speed = 0.8 + (Double(MorphDeterministicHash.mix(charIndex, 1, 730) & 0xFFFF) / 65535.0) * 0.8
            let dir: Double = charIndex.isMultiple(of: 2) ? 1.0 : -1.0
            let a = phase * speed * dir + Double(charIndex) * 1.9
            let r = 3.6 * intensity
            return MorphGlyphTransform(dx: CGFloat(cos(a) * r), dy: CGFloat(sin(a) * r))

        case .ativPulsoRitmicoRegular:
            let cycle = max(1.6, Double(n) * 0.12 + 0.6)
            let local = time.truncatingRemainder(dividingBy: cycle)
            let dt = local - Double(charIndex) * 0.12
            let pulse = (dt >= 0 && dt <= 0.36) ? sin((dt / 0.36) * .pi) : 0
            return MorphGlyphTransform(
                dy: CGFloat(-pulse * 7.5 * intensity),
                scaleX: CGFloat(1.0 + pulse * 0.20 * intensity),
                scaleY: CGFloat(1.0 + pulse * 0.20 * intensity)
            )

        case .domLenteInflada:
            let phase = (time / 2.8) * 2.0 * .pi
            let bulge = (0.5 - 0.5 * cos(phase)) * min(1.0, intensity)
            let center = 1.0 - abs(norm)
            return MorphGlyphTransform(
                dx: CGFloat(norm * 8.0 * bulge),
                scaleX: CGFloat(1.0 + center * 0.26 * bulge),
                scaleY: CGFloat(1.0 + center * 0.40 * bulge)
            )

        case .tensOndaSismica:
            let epicentre = (time / 2.4).truncatingRemainder(dividingBy: 1.0)
            let tick = Int(time * 36.0)
            let pos = n > 1 ? Double(charIndex) / Double(n - 1) : 0.5
            let d = min(abs(pos - epicentre), 1.0 - abs(pos - epicentre))
            let shake = max(0, 1.0 - d / 0.20) * intensity
            let u1 = Double(MorphDeterministicHash.mix(tick, charIndex, 540) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(tick, charIndex, 541) & 0xFFFF) / 65535.0
            let jx = (u1 - 0.5) * 9.0 * shake
            let jy = (u2 - 0.5) * 10.0 * shake
            return MorphGlyphTransform(dx: CGFloat(jx), dy: CGFloat(jy), rotationDeg: jx * 1.1)

        case .tensDesalinhamentoMecanico:
            let stepTick = Int(time / 0.45)
            let active = (charIndex == (stepTick % n))
            let u = Double(MorphDeterministicHash.mix(stepTick / 2, charIndex, 750) & 0xFFFF) / 65535.0
            let dy = ((u - 0.5) * 6.5 + (active ? -3.0 : 0)) * intensity
            return MorphGlyphTransform(dy: CGFloat(dy))

        case .tensPressaoCrescente:
            let p = (time / 2.6).truncatingRemainder(dividingBy: 1.0)
            let build = p < 0.78 ? (p / 0.78) : (1.0 - (p - 0.78) / 0.22)
            let tremor = p < 0.78 ? sin(time * 88.0) * 3.2 * build * build * intensity : 0
            return MorphGlyphTransform(
                dx: CGFloat(tremor),
                dy: CGFloat(tremor * 0.4),
                scaleX: CGFloat(1.0 + build * 0.20 * intensity),
                scaleY: CGFloat(1.0 - build * 0.14 * intensity)
            )

        case .tensAmeacaLatente:
            let slot = Int(time * 5.0)
            let target = Int(MorphDeterministicHash.mix(slot, wordIndex, 845) % UInt64(n))
            guard charIndex == target else { return .identity }
            let tick = Int(time * 36.0)
            let u1 = Double(MorphDeterministicHash.mix(tick, charIndex, 846) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(tick, charIndex, 847) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dx: CGFloat((u2 - 0.5) * 5.0 * intensity),
                skewXDeg: (u1 - 0.5) * 24.0 * intensity
            )

        case .tensVibracaoPalavra:
            let tick = Int(time * 36.0)
            let wave = (0.55 + 0.45 * sin((time / 2.4) * 2.0 * .pi)) * intensity
            let u1 = Double(MorphDeterministicHash.mix(tick, charIndex, 1) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(tick, charIndex, 2) & 0xFFFF) / 65535.0
            let u3 = Double(MorphDeterministicHash.mix(tick, charIndex, 3) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dx: CGFloat((u1 - 0.5) * 5.8 * wave),
                dy: CGFloat((u2 - 0.5) * 4.6 * wave),
                rotationDeg: (u3 - 0.5) * 4.2 * wave
            )

        case .andLetargia:
            let phase = (time / 4.0) * 2.0 * .pi
            let droop = (0.5 - 0.5 * cos(phase)) * min(1.0, intensity)
            return MorphGlyphTransform(
                dy: CGFloat(droop * 7.5),
                scaleY: CGFloat(0.95 - droop * 0.10),
                skewXDeg: 7.0 + droop * 12.0,
                skewYDeg: 1.5 + droop * 3.0,
                blur: CGFloat(droop * 1.6),
                anchor: .bottom
            )

        case .calFogoVivo:
            let phase = (time / 1.8) * 2.0 * .pi
            let flicker = sin(phase * 3.0 + Double(charIndex) * 1.7) * cos(phase * 2.0 - Double(charIndex))
            return MorphGlyphTransform(
                scaleY: CGFloat(1.0 + abs(flicker) * 0.16 * intensity),
                skewXDeg: flicker * 9.0 * intensity,
                anchor: .bottom,
                glowRadius: 7.0,
                glowOpacity: 0.65
            )

        case .calTremocaoFrio:
            let sub = (time / 2.0).truncatingRemainder(dividingBy: 1.0)
            let shivering = sub < 0.38
            let tick = Int(time * 42.0)
            let u = Double(MorphDeterministicHash.mix(tick, charIndex, 840) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dx: shivering ? CGFloat((u - 0.5) * 6.0 * intensity) : 0,
                scaleX: shivering ? 0.90 : 0.96,
                scaleY: shivering ? 1.06 : 1.0
            )

        case .abertPingentesVento:
            let phase = (time / 2.4) * 2.0 * .pi
            let deg = sin(phase + Double(charIndex) * 0.45) * 13.0 * min(1.05, intensity)
            return MorphGlyphTransform(rotationDeg: deg, anchor: .top)

        case .volPanoramica3D:
            let phase = (time / 3.6) * 2.0 * .pi
            let yaw = sin(phase) * 24.0 * min(1.1, intensity)
            return MorphGlyphTransform(rotateYDeg: yaw)

        case .pesoFlutuacaoZeroG:
            let phase = (time / 4.0) * 2.0 * .pi
            let f1 = 0.85 + (Double(MorphDeterministicHash.mix(charIndex, 1, 301) & 0xFFFF) / 65535.0) * 0.45
            let f2 = 0.70 + (Double(MorphDeterministicHash.mix(charIndex, 2, 302) & 0xFFFF) / 65535.0) * 0.55
            let offsetP = Double(charIndex) * 1.1
            return MorphGlyphTransform(
                dx: CGFloat(sin(phase * f1 + offsetP) * 5.0 * intensity),
                dy: CGFloat(-6.0 + cos(phase * f2 + offsetP * 0.7) * 9.0 * intensity),
                rotationDeg: sin(phase * f1 * 0.7 + offsetP) * 6.0 * intensity
            )

        case .pesoAntiGravity:
            // Reescrito p/ nunca sumir: flutuação ascendente contínua e leve.
            let phase = (time / 2.6) * 2.0 * .pi + Double(charIndex) * 0.45
            let lift = 0.5 - 0.5 * cos(phase)
            return MorphGlyphTransform(
                dy: CGFloat(-4.0 - lift * 16.0 * min(1.1, intensity)),
                opacity: 0.78 + 0.22 * (1.0 - lift * 0.5)
            )

        case .pesoFlutuarTopo:
            // Reescrito p/ nunca sumir: mantém palavra no topo com balanço suave.
            let phase = (time / 2.8) * 2.0 * .pi + Double(wordIndex) * 0.8
            return MorphGlyphTransform(
                dx: CGFloat(sin(phase * 0.7) * 5.0),
                dy: CGFloat(-13.0 * min(1.15, intensity) + sin(phase) * 4.5)
            )

        case .pesoMovieCredits:
            // Reescrito p/ nunca sumir: deriva ascendente contínua com retorno suave.
            let phase = (time / 3.4) * 2.0 * .pi + Double(charIndex) * 0.22
            let drift = sin(phase)
            return MorphGlyphTransform(
                dy: CGFloat(-6.0 + drift * 12.0 * min(1.05, intensity)),
                opacity: 0.76 + 0.24 * (1.0 - abs(drift) * 0.6)
            )

        case .pesoFallingLeaves:
            // Confirmado em Peso (+), reescrito p/ pêndulo descendente contínuo sem opacity 0.
            let phase = (time / 2.4) * 2.0 * .pi + Double(charIndex) * 0.55
            let sway = sin(phase)
            let settle = 0.5 - 0.5 * cos(phase * 0.7)
            return MorphGlyphTransform(
                dx: CGFloat(sway * 8.5 * intensity),
                dy: CGFloat(4.0 + settle * 14.0 * min(1.1, intensity)),
                rotationDeg: sway * 16.0 * intensity,
                opacity: 0.82 + 0.18 * (1.0 - settle * 0.5)
            )

        case .fluidRigidezMecanica:
            let step = Int(time * 4.0) % 4
            let (skew, sx, sy): (Double, Double, Double)
            switch step {
            case 0: (skew, sx, sy) = (-11.0, 1.10, 0.91)
            case 1: (skew, sx, sy) = (0.0, 0.93, 1.12)
            case 2: (skew, sx, sy) = (11.0, 1.10, 0.91)
            default: (skew, sx, sy) = (0.0, 1.0, 1.0)
            }
            return MorphGlyphTransform(scaleX: CGFloat(sx), scaleY: CGFloat(sy), skewXDeg: skew * min(1.1, intensity))

        case .fluidWave:
            let phase = (time / 1.5) * 2.0 * .pi - Double(charIndex) * 0.55
            return MorphGlyphTransform(dy: CGFloat(-max(0, sin(phase)) * 13.0 * intensity))

        case .fluidOndaInclinacao:
            let phase = (time / 2.2) * 2.0 * .pi - Double(charIndex) * 0.5
            return MorphGlyphTransform(skewXDeg: sin(phase) * 20.0 * intensity)

        case .fluidDancaTipografica:
            let phase = (time / 1.6) * 2.0 * .pi + Double(charIndex) * 0.62
            return MorphGlyphTransform(
                dy: CGFloat(-abs(sin(phase)) * 15.0 * intensity),
                rotationDeg: cos(phase) * 7.5 * intensity
            )

        case .fluidOndulacaoVertical:
            let phase = (time / 2.0) * 2.0 * .pi - Double(charIndex) * 0.55
            return MorphGlyphTransform(
                dy: CGFloat(sin(phase) * 11.5 * intensity),
                rotationDeg: cos(phase) * 4.2 * intensity
            )

        case .fluidFluidoViscoso:
            let phase = (time / 2.8) * 2.0 * .pi
            let drip = 0.5 - 0.5 * cos(phase)
            let factor = 0.65 + (Double(MorphDeterministicHash.mix(charIndex, 1, 865) & 0xFFFF) / 65535.0) * 0.55
            let stretch = min(0.46, drip * 0.42 * factor * intensity)
            return MorphGlyphTransform(
                scaleX: CGFloat(max(0.76, 1.0 - stretch * 0.28)),
                scaleY: CGFloat(1.0 + stretch),
                anchor: .top
            )

        case .fluidEspelhoLiquido:
            let phase = (time / 2.2) * 2.0 * .pi - Double(charIndex) * 0.6
            return MorphGlyphTransform(
                dy: CGFloat(sin(phase) * 9.5 * intensity),
                scaleX: CGFloat(1.0 + cos(phase) * 0.10 * intensity),
                scaleY: CGFloat(1.0 - cos(phase) * 0.08 * intensity)
            )

        case .fluidSubmarino:
            let phase = (time / 3.4) * 2.0 * .pi + Double(charIndex) * 0.45
            return MorphGlyphTransform(
                dx: CGFloat(sin(phase * 0.7) * 4.5 * intensity),
                dy: CGFloat(cos(phase) * 8.5 * intensity),
                blur: CGFloat(max(0, sin(phase * 0.5)) * 1.4)
            )

        case .fluidLuzPiscina:
            let phase = (time / 2.8) * 2.0 * .pi + Double(charIndex) * 0.5
            return MorphGlyphTransform(dy: CGFloat(sin(phase) * 5.5 * intensity))

        case .kwRespiracaoOrganica:
            // Zero reflow: simula abertura respirante com scaleX/scaleY em vez de animar tracking no layout.
            let phase = (time / 3.2) * 2.0 * .pi
            let breath = 0.5 - 0.5 * cos(phase)
            return MorphGlyphTransform(
                scaleX: CGFloat(0.94 + 0.14 * breath),
                scaleY: CGFloat(0.94 + 0.10 * breath),
                opacity: 0.72 + 0.28 * breath
            )

        case .kwLetreiroNeon:
            let tick = Int(time * 18.0)
            let isFaulty = (charIndex % 4 == 1) || (charIndex == n - 1)
            let noise = Double(MorphDeterministicHash.mix(tick, charIndex, 305) & 0xFFFF) / 65535.0
            let dip = isFaulty && noise > 0.72
            return MorphGlyphTransform(
                opacity: dip ? 0.55 : 1.0,
                glowRadius: dip ? 1.5 : 11.0,
                glowOpacity: dip ? 0.08 : 0.92
            )

        case .kwArcoFlexivel:
            let phase = (time / 3.0) * 2.0 * .pi
            let bend = sin(phase)
            return MorphGlyphTransform(
                dy: CGFloat((norm * norm - 0.5) * 28.0 * bend),
                rotationDeg: norm * 20.0 * bend
            )

        case .kwStopMotion6fps:
            let stepTick = Int(time * 6.0)
            let u1 = Double(MorphDeterministicHash.mix(stepTick, charIndex, 735) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(stepTick, charIndex, 736) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dx: CGFloat((u1 - 0.5) * 6.0),
                dy: CGFloat((u2 - 0.5) * 6.0)
            )

        case .kwCaosImprevisivel:
            let tick = Int(time * 5.0)
            let u1 = Double(MorphDeterministicHash.mix(tick, charIndex, 870) & 0xFFFF) / 65535.0
            let u2 = Double(MorphDeterministicHash.mix(tick, charIndex, 871) & 0xFFFF) / 65535.0
            let u3 = Double(MorphDeterministicHash.mix(tick, charIndex, 872) & 0xFFFF) / 65535.0
            let u4 = Double(MorphDeterministicHash.mix(tick, charIndex, 873) & 0xFFFF) / 65535.0
            return MorphGlyphTransform(
                dy: CGFloat((u4 - 0.5) * 18.0),
                scaleX: CGFloat(0.72 + u1 * 0.56),
                scaleY: CGFloat(0.72 + u2 * 0.68),
                skewXDeg: (u3 - 0.5) * 34.0
            )

        case .kwTontura:
            let phase = (time / 2.6) * 2.0 * .pi
            return MorphGlyphTransform(
                rotationDeg: sin(phase) * 5.0,
                skewXDeg: sin(phase) * 18.0,
                skewYDeg: cos(phase) * 10.0
            )

        default:
            return .identity
        }
    }
}

// MARK: - GeometryEffect de Inclinação (Skew)

struct MorphSkewEffect: GeometryEffect {
    var skewXDeg: Double
    var skewYDeg: Double

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        guard abs(skewXDeg) > 0.001 || abs(skewYDeg) > 0.001 else {
            return ProjectionTransform(.identity)
        }
        let tx = tan(skewXDeg * .pi / 180.0)
        let ty = tan(skewYDeg * .pi / 180.0)
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let skew = CGAffineTransform(a: 1 + tx * ty, b: ty, c: tx, d: 1, tx: 0, ty: 0)
        let centered = CGAffineTransform(translationX: -cx, y: -cy)
            .concatenating(skew)
            .concatenating(CGAffineTransform(translationX: cx, y: cy))
        return ProjectionTransform(centered)
    }
}
