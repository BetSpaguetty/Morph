import SwiftUI

// MARK: - Primitivo 3: Paleta e Superfícies Adaptadas ao Fundo Creme-Amarelo do CRT (#EEE6B8 -> #D2C27A)

enum MorphCRTSafePalette {
    static func defaultInk(onWhiteCanvas: Bool) -> Color {
        onWhiteCanvas
            ? Color(red: 0.10, green: 0.11, blue: 0.15)
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    static let deepCrimson = Color(red: 0.72, green: 0.09, blue: 0.12)
    static let burntOrange = Color(red: 0.85, green: 0.28, blue: 0.06)
    static let darkAmber = Color(red: 0.76, green: 0.40, blue: 0.02)
    static let deepCyan = Color(red: 0.02, green: 0.44, blue: 0.60)
    static let deepPink = Color(red: 0.74, green: 0.10, blue: 0.42)
    static let deepPurple = Color(red: 0.36, green: 0.14, blue: 0.56)
    static let deepIndigo = Color(red: 0.14, green: 0.18, blue: 0.52)
    static let glacialBlue = Color(red: 0.10, green: 0.35, blue: 0.68)
    static let glacialMid = Color(red: 0.16, green: 0.48, blue: 0.78)
    static let oceanDeep = Color(red: 0.04, green: 0.25, blue: 0.52)
    static let oceanBright = Color(red: 0.08, green: 0.54, blue: 0.68)

    /// Espectro contínuo em `[0, 1)` que pula a faixa amarela morta (`hue 0.10...0.21`)
    /// para nunca sumir no fundo `#EEE6B8` da TV CRT.
    static func safeSpectrumColor(phase rawPhase: Double, saturation: Double = 0.86, brightness: Double = 0.58) -> Color {
        var u = rawPhase.truncatingRemainder(dividingBy: 1.0)
        if u < 0 { u += 1.0 }

        // Mapeia [0, 1) continuamente para [0.00...0.08] U [0.24...1.00) (largura útil = 0.84)
        let span = 0.84
        let mapped = u * span
        let hue = mapped < 0.08 ? mapped : (mapped + 0.16)
        return Color(hue: hue.truncatingRemainder(dividingBy: 1.0), saturation: saturation, brightness: brightness)
    }

    static var safeFlameGradient: LinearGradient {
        LinearGradient(
            colors: [darkAmber, burntOrange, deepCrimson],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var safeIceGradient: LinearGradient {
        LinearGradient(
            colors: [glacialMid, glacialBlue, deepIndigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func thermalFallbackColor(calorScore: Int, onWhiteCanvas: Bool) -> Color {
        switch calorScore {
        case -5: return Color(red: 0.08, green: 0.19, blue: 0.54)
        case -4: return Color(red: 0.11, green: 0.28, blue: 0.66)
        case -3: return Color(red: 0.14, green: 0.40, blue: 0.74)
        case -2: return Color(red: 0.28, green: 0.36, blue: 0.72)
        case -1: return Color(red: 0.44, green: 0.34, blue: 0.68)
        case 1:  return darkAmber
        case 2:  return Color(red: 0.84, green: 0.38, blue: 0.08)
        case 3:  return burntOrange
        case 4:  return Color(red: 0.80, green: 0.16, blue: 0.09)
        case 5:  return deepCrimson
        default: return defaultInk(onWhiteCanvas: onWhiteCanvas)
        }
    }
}

enum MorphSurfaceResolver {
    /// Resolve a cor sólida representativa da palavra (usada para sombras/ecos e fallback).
    static func baseTintColor(
        plan: WordAnimationPlan,
        effectiveTime: Double,
        onWhiteCanvas: Bool
    ) -> Color {
        let ink = MorphCRTSafePalette.defaultInk(onWhiteCanvas: onWhiteCanvas)
        // Trava de proteção: CatsFont e SnowtopCaps nunca alteram cor.
        guard !plan.typography.isDecorativeSingleWeight else { return ink }

        if let surface = plan.surface {
            switch surface.effectID {
            case .fluidBrilhoMetalico, .valMercurioLiquido:
                return Color(white: 0.26)
            case .valFluxoArcoIris, .valRotacaoMatiz:
                return MorphCRTSafePalette.safeSpectrumColor(phase: effectiveTime / 3.8)
            case .valLampadaLava:
                return MorphCRTSafePalette.deepPink
            case .valPulsoSaturacao:
                return MorphCRTSafePalette.deepPurple
            case .valCameraTermica:
                return thermalNegativeColor(effectiveTime: effectiveTime)
            default:
                break
            }
        }

        if plan.usesCoupledMotionSurfaceColor, let motion = plan.continuous {
            switch motion.effectID {
            case .calFogoVivo, .calMiragemCalor:
                return MorphCRTSafePalette.burntOrange
            case .calTremocaoFrio:
                return MorphCRTSafePalette.glacialBlue
            case .fluidEspelhoLiquido, .fluidSubmarino, .fluidLuzPiscina, .fluidRefracaoSubmersa:
                return MorphCRTSafePalette.oceanBright
            case .kwLetreiroNeon:
                return MorphCRTSafePalette.deepPink
            default:
                break
            }
        }

        if plan.overlay?.effectID == .kwEstouroPopArt && plan.surface == nil {
            return MorphCRTSafePalette.deepCrimson
        }

        if plan.scores[.calor] != 0 {
            return MorphCRTSafePalette.thermalFallbackColor(
                calorScore: plan.scores[.calor],
                onWhiteCanvas: onWhiteCanvas
            )
        }

        return ink
    }

    /// Resolve o `AnyShapeStyle` aplicado diretamente no `.foregroundStyle` de cada glifo
    /// (preservando 100% da fonte de `Tom`, sem `.mask(Text)` redundante).
    static func foregroundStyle(
        plan: WordAnimationPlan,
        elapsed: Double,
        effectiveTime: Double,
        charIndex: Int,
        totalChars: Int,
        onWhiteCanvas: Bool
    ) -> AnyShapeStyle {
        let ink = MorphCRTSafePalette.defaultInk(onWhiteCanvas: onWhiteCanvas)
        guard !plan.typography.isDecorativeSingleWeight else { return AnyShapeStyle(ink) }

        // 1. Canal 2 (Cor / Superfície vencedora)
        if let surface = plan.surface {
            switch surface.effectID {
            case .fluidBrilhoMetalico:
                let p = (effectiveTime / 2.4).truncatingRemainder(dividingBy: 1.0)
                let c = -0.35 + p * 1.7
                let s1 = min(max(c - 0.18, 0), 1)
                let s2 = min(max(c, s1), 1)
                let s3 = min(max(c + 0.18, s2), 1)
                return AnyShapeStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(white: 0.14), location: 0),
                            .init(color: Color(white: 0.36), location: s1),
                            .init(color: Color(white: 0.72), location: s2),
                            .init(color: Color(white: 0.16), location: s3),
                            .init(color: Color(white: 0.34), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            case .valFluxoArcoIris:
                let n = Double(max(1, totalChars))
                let shift = (effectiveTime / 3.0).truncatingRemainder(dividingBy: 1.0)
                let phase = Double(charIndex) / n + shift
                return AnyShapeStyle(MorphCRTSafePalette.safeSpectrumColor(phase: phase, saturation: 0.88, brightness: 0.56))

            case .valLampadaLava:
                // Versão leve em gradiente animado (substitui Canvas + blur(10) + mask).
                let phase = (effectiveTime / 3.8) * 2.0 * .pi
                let drift = 0.5 + 0.5 * sin(phase)
                let c1 = Color(red: 0.42, green: 0.06, blue: 0.44)
                let c2 = MorphCRTSafePalette.deepCrimson
                let c3 = MorphCRTSafePalette.burntOrange
                let c4 = MorphCRTSafePalette.deepPink
                if plan.isEcoMode {
                    return AnyShapeStyle(LinearGradient(colors: [c1, c2, c3], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                let mid = 0.25 + 0.50 * drift
                return AnyShapeStyle(
                    LinearGradient(
                        stops: [
                            .init(color: c1, location: 0.0),
                            .init(color: c2, location: max(0.08, mid - 0.22)),
                            .init(color: c3, location: mid),
                            .init(color: c4, location: min(0.92, mid + 0.24)),
                            .init(color: c1, location: 1.0)
                        ],
                        startPoint: UnitPoint(x: 0.1 + 0.3 * sin(phase * 0.7), y: 0),
                        endPoint: UnitPoint(x: 0.9 - 0.3 * cos(phase * 0.6), y: 1)
                    )
                )

            case .valPulsoSaturacao:
                let phase = (effectiveTime / 3.2) * 2.0 * .pi
                let mix = (0.5 - 0.5 * cos(phase)) * min(1.0, surface.intensity)
                let grad = LinearGradient(
                    colors: [
                        blendGrayRGB(r: 0.74, g: 0.10, b: 0.42, vivid: mix),
                        blendGrayRGB(r: 0.85, g: 0.28, b: 0.06, vivid: mix),
                        blendGrayRGB(r: 0.02, g: 0.44, b: 0.60, vivid: mix),
                        blendGrayRGB(r: 0.14, g: 0.18, b: 0.52, vivid: mix)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                return AnyShapeStyle(grad)

            case .valRotacaoMatiz:
                let phase = effectiveTime / 4.5
                return AnyShapeStyle(MorphCRTSafePalette.safeSpectrumColor(phase: phase, saturation: 0.88, brightness: 0.56))

            case .valCameraTermica:
                return AnyShapeStyle(thermalNegativeColor(effectiveTime: effectiveTime))

            case .valMercurioLiquido:
                let phase = (effectiveTime / 2.8) * 2.0 * .pi
                let shift = 0.45 * sin(phase)
                let p1 = max(0.05, min(0.85, 0.28 + shift * 0.35))
                let p2 = max(p1 + 0.08, min(0.92, 0.52 + shift * 0.35))
                let p3 = max(p2 + 0.06, min(0.98, 0.74 + shift * 0.35))
                return AnyShapeStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(white: 0.16), location: 0.0),
                            .init(color: Color(white: 0.70), location: p1),
                            .init(color: Color(white: 0.10), location: p2),
                            .init(color: Color(white: 0.66), location: p3),
                            .init(color: Color(white: 0.20), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            default:
                break
            }
        }

        // 2. Tint transitório de Entradas cromáticas (durante a revelação 1x)
        if let entrance = plan.entrance {
            let p = MorphGlyphTransformEngine.charEntranceProgress(
                elapsed: elapsed,
                charIndex: charIndex,
                duration: MorphGlyphTransformEngine.entranceDuration(for: entrance.effectID),
                delayStep: 0.045
            )
            if p < 1.0 {
                switch entrance.effectID {
                case .calChamaAscendente:
                    let heat = max(0, 1.0 - max(0, (p - 0.35) / 0.65))
                    if heat > 0.15 {
                        return AnyShapeStyle(Color(red: 0.86, green: 0.24 + 0.26 * heat, blue: 0.04))
                    }
                case .calArrepioGelado:
                    if p < 0.8 {
                        return AnyShapeStyle(MorphCRTSafePalette.glacialBlue)
                    }
                case .valCascataArcoIris:
                    let mix = max(0, 1.0 - max(0, (p - 0.55) / 0.45))
                    if mix > 0.15 {
                        let huePhase = Double(charIndex) / Double(max(1, totalChars))
                        return AnyShapeStyle(MorphCRTSafePalette.safeSpectrumColor(phase: huePhase, saturation: 0.90, brightness: 0.58))
                    }
                default:
                    break
                }
            }
        }

        // 3. Paleta acoplada do Canal 4 (somente quando Canal 2 está vazio)
        if plan.usesCoupledMotionSurfaceColor, let motion = plan.continuous {
            switch motion.effectID {
            case .calFogoVivo, .calMiragemCalor:
                return AnyShapeStyle(MorphCRTSafePalette.safeFlameGradient)
            case .calTremocaoFrio:
                return AnyShapeStyle(MorphCRTSafePalette.glacialBlue)
            case .fluidEspelhoLiquido:
                let phase = (effectiveTime / 2.2) * 2.0 * .pi
                let wave = sin(phase - Double(charIndex) * 0.6)
                return AnyShapeStyle(Color(hue: 0.55 + 0.05 * wave, saturation: 0.80, brightness: 0.56))
            case .fluidSubmarino:
                return AnyShapeStyle(Color(red: 0.05, green: 0.36, blue: 0.62))
            case .fluidLuzPiscina:
                let p = (effectiveTime / 2.8).truncatingRemainder(dividingBy: 1.0)
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            MorphCRTSafePalette.oceanDeep,
                            MorphCRTSafePalette.oceanBright,
                            MorphCRTSafePalette.oceanDeep,
                            MorphCRTSafePalette.oceanBright,
                            MorphCRTSafePalette.oceanDeep
                        ],
                        startPoint: UnitPoint(x: -0.5 + p * 1.4, y: 0),
                        endPoint: UnitPoint(x: 0.8 + p * 1.4, y: 1)
                    )
                )
            case .fluidRefracaoSubmersa:
                return AnyShapeStyle(Color(red: 0.06, green: 0.38, blue: 0.64))
            case .kwLetreiroNeon:
                return AnyShapeStyle(MorphCRTSafePalette.deepPink)
            default:
                break
            }
        }

        // 4. Overlay térmico de gelo e Pop-Art (quando Canal 2 está livre)
        if plan.overlay?.effectID == .kwEstouroPopArt {
            return AnyShapeStyle(MorphCRTSafePalette.deepCrimson)
        }
        if plan.overlay?.effectID == .calGelidoQuebradico {
            return AnyShapeStyle(MorphCRTSafePalette.safeIceGradient)
        }
        if plan.overlay?.effectID == .calNevascaCristalina {
            return AnyShapeStyle(MorphCRTSafePalette.glacialBlue)
        }

        // 5. Fallback térmico sutil (ex.: após Lançamento de Foguete ou Névoa Ascendente)
        if plan.scores[.calor] != 0 {
            return AnyShapeStyle(
                MorphCRTSafePalette.thermalFallbackColor(
                    calorScore: plan.scores[.calor],
                    onWhiteCanvas: onWhiteCanvas
                )
            )
        }

        return AnyShapeStyle(ink)
    }

    private static func thermalNegativeColor(effectiveTime: Double) -> Color {
        // Faixa fria/tensa para Valência (-): índigo -> violeta -> carmesim escuro (nunca amarelo claro).
        let phase = (effectiveTime / 3.6) * 2.0 * .pi
        let t = 0.5 - 0.5 * cos(phase)
        let hue = (0.68 + t * 0.30).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: hue, saturation: 0.84, brightness: 0.46 + 0.14 * t)
    }

    private static func blendGrayRGB(r: Double, g: Double, b: Double, vivid: Double) -> Color {
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        let k = min(max(vivid, 0), 1)
        return Color(
            red: lum + (r - lum) * k,
            green: lum + (g - lum) * k,
            blue: lum + (b - lum) * k
        )
    }
}
