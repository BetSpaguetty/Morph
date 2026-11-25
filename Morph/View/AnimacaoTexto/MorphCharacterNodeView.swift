import SwiftUI

// MARK: - Renderizador Individual de Cada Letra (Fluidez, Micro-Tensão, Fragmentação, Volume)

struct MorphCharacterNodeView: View {
    let character: Character
    let charIndex: Int
    let totalChars: Int
    let wordIndex: Int
    let typography: ResolvedTypography
    let color: Color
    let fluidezScore: Int
    let tensaoScore: Int
    let fragmentacaoScore: Int
    let luzScore: Int
    let ativacaoScore: Int
    let isolatedParameter: MorphParameter?
    let andamentoScore: Int
    let characterSequenceIndex: Int
    let phraseCharacterCount: Int
    let isAndamentoPaused: Bool
    let effectiveTime: Double

    private var speedDashState: (x: CGFloat, skew: CGFloat, opacity: Double) {
        guard andamentoScore >= 1, !isAndamentoPaused else { return (0, 0, 1) }

        // Mantém a sequência do HTML (50 ms entre letras e 2,5 s de pausa),
        // acelerando a entrada conforme o nível de Andamento.
        let duration: Double = [1: 1.25, 2: 1.0, 3: 0.75, 4: 0.6, 5: 0.5][andamentoScore] ?? 0.5
        let stagger = 0.05
        let cycle = Double(max(phraseCharacterCount, 1)) * stagger + duration + 2.5
        let delayedTime = effectiveTime - Double(characterSequenceIndex) * stagger
        guard delayedTime >= 0 else { return (-2, -.pi / 4, 0) }
        let phase = delayedTime.truncatingRemainder(dividingBy: cycle)
        guard phase < duration else { return (0, 0, 1) }

        let progress = phase / duration
        if progress < 0.7 {
            let p = progress / 0.7
            let eased = p * p * (3 - 2 * p)
            return (
                x: CGFloat(-2.0 + 2.1 * eased),
                skew: CGFloat((-45.0 + 35.0 * eased) * .pi / 180.0),
                opacity: min(1.0, p)
            )
        }

        let p = (progress - 0.7) / 0.3
        let eased = p * p * (3 - 2 * p)
        return (
            x: CGFloat(0.1 * (1 - eased)),
            skew: CGFloat((-10.0 + 10.0 * eased) * .pi / 180.0),
            opacity: 1.0
        )
    }

    private var fluidityWaveOffset: (dx: CGFloat, dy: CGFloat, rotation: Double) {
        guard fluidezScore >= 1 else { return (0, 0, 0) }
        let ampY = CGFloat(fluidezScore) * 3.4
        let ampX = CGFloat(fluidezScore) * 1.8
        let phase = effectiveTime * 3.4 - Double(charIndex) * 0.65 + Double(wordIndex) * 0.4
        return (
            dx: CGFloat(cos(phase * 0.85)) * ampX,
            dy: CGFloat(sin(phase)) * ampY,
            rotation: cos(phase) * Double(fluidezScore) * 1.8
        )
    }

    private var charTensionOffset: (dx: CGFloat, dy: CGFloat) {
        guard tensaoScore > 0 else { return (0, 0) }
        let amp = Double(tensaoScore) * 0.85
        let phase = effectiveTime * 38.0 + Double(charIndex) * 19.3 + Double(wordIndex) * 7.1
        return (
            dx: CGFloat(sin(phase) * amp),
            dy: CGFloat(cos(phase * 1.3) * amp)
        )
    }

    private var isolatedActivationWaveY: CGFloat {
        guard isolatedParameter == .ativacao || (ativacaoScore != 0 && fluidezScore <= 0 && tensaoScore <= 0 && fragmentacaoScore <= 0) else {
            return 0
        }
        let phase = effectiveTime * 4.2 - Double(charIndex) * 0.55
        return CGFloat(sin(phase)) * 6.5
    }

    private var characterFragmentationFade: (opacity: Double, scatterY: CGFloat) {
        guard fragmentacaoScore > 0 else { return (1.0, 0.0) }
        let normalizedFrag = Double(fragmentacaoScore) / 5.0
        let slowWave = 0.5 + 0.5 * sin(effectiveTime * 2.6 + Double(charIndex) * 1.7 + Double(wordIndex) * 2.3)
        let fastGrain = 0.5 + 0.5 * cos(effectiveTime * 11.5 + Double(charIndex) * 5.1)
        let combined = slowWave * 0.68 + fastGrain * 0.32

        let minOpacity = max(0.04, 1.0 - normalizedFrag * 0.92)
        let opacity = minOpacity + (1.0 - minOpacity) * combined
        let dirFactor: Double = charIndex.isMultiple(of: 2) ? -6.0 : 6.0
        let scatterY = CGFloat((1.0 - slowWave) * normalizedFrag * dirFactor)
        return (opacity, scatterY)
    }

    var body: some View {
        let wave = fluidityWaveOffset
        let charJitter = charTensionOffset
        let frag = characterFragmentationFade
        let dash = speedDashState
        let str = String(character)
        let totalX: CGFloat = wave.dx + charJitter.dx
        let totalY: CGFloat = wave.dy + charJitter.dy + frag.scatterY + isolatedActivationWaveY

        ZStack {
            if typography.extraStrokeWidth > 0 {
                let d = typography.extraStrokeWidth
                Text(str).font(typography.font).foregroundStyle(color).offset(x: d, y: 0)
                Text(str).font(typography.font).foregroundStyle(color).offset(x: -d, y: 0)
                Text(str).font(typography.font).foregroundStyle(color).offset(x: 0, y: d * 0.7)
                Text(str).font(typography.font).foregroundStyle(color).offset(x: 0, y: -d * 0.7)
            }
            Text(str)
                .font(typography.font)
                .foregroundStyle(color)
                .modifier(
                                    LightAndShadowModifier(
                                        luzScore: luzScore,
                                        baseColor: color,
                                        charIndex: charIndex,
                                        totalChars: totalChars,
                                        effectiveTime: effectiveTime
                                    )
                                )
            
        }
        .opacity(frag.opacity)
        .rotationEffect(.degrees(wave.rotation))
        .offset(x: totalX, y: totalY)
        .visualEffect { content, proxy in
            content
                .transformEffect(
                    CGAffineTransform(
                        a: 1,
                        b: 0,
                        c: CGFloat(tan(Double(dash.skew))),
                        d: 1,
                        tx: 0,
                        ty: 0
                    )
                )
                .offset(x: proxy.size.width * dash.x)
                .opacity(dash.opacity)
        }
    }
}

// MARK: - Modificador de Granulação Entrando e Saindo (Fragmentação 0 a +5)

struct GranulationFadeModifier: ViewModifier {
    let fragmentacaoScore: Int
    let effectiveTime: Double
    let wordSeed: Int
    let tintColor: Color

    func body(content: Content) -> some View {
        if fragmentacaoScore <= 0 {
            content
        } else {
            let intensity = Double(fragmentacaoScore) / 5.0

            content
                .mask {
                    Canvas { context, size in
                        let baseAlpha = max(0.18, 1.0 - intensity * 0.62)
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.white.opacity(baseAlpha))
                        )

                        let cellSize: CGFloat = max(2.2, 5.0 - CGFloat(fragmentacaoScore) * 0.5)
                        let cols = max(1, Int(size.width / cellSize))
                        let rows = max(1, Int(size.height / cellSize))

                        for r in 0..<rows {
                            for c in 0..<cols {
                                let hash = Double((r * 73 + c * 37 + wordSeed * 19) % 97) / 97.0
                                let grainWave = sin(effectiveTime * (3.5 + hash * 6.0) + hash * .pi * 2.0)
                                if grainWave > (-0.35 + intensity * 0.55) {
                                    let rect = CGRect(
                                        x: CGFloat(c) * cellSize,
                                        y: CGFloat(r) * cellSize,
                                        width: cellSize * 0.92,
                                        height: cellSize * 0.92
                                    )
                                    context.fill(Path(rect), with: .color(.white))
                                }
                            }
                        }
                    }
                }
                .overlay {
                    Canvas { context, size in
                        let particleCount = fragmentacaoScore * 14
                        for i in 0..<particleCount {
                            let seed = Double((i * 41 + wordSeed * 29) % 113) / 113.0
                            let seedY = Double((i * 67 + wordSeed * 13) % 109) / 109.0
                            let phase = effectiveTime * (2.2 + seed * 3.5) + seed * 6.28
                            let alpha = max(0.0, sin(phase)) * intensity * 0.95

                            guard alpha > 0.05 else { continue }

                            let driftX = cos(phase * 1.2) * Double(fragmentacaoScore) * 2.6
                            let driftY = sin(phase * 1.5) * Double(fragmentacaoScore) * 3.2
                            let px = size.width * CGFloat(0.06 + 0.88 * seed) + CGFloat(driftX)
                            let py = size.height * CGFloat(0.12 + 0.76 * seedY) + CGFloat(driftY)
                            let grainRadius = CGFloat(1.1 + seed * 1.8)

                            let rect = CGRect(
                                x: px - grainRadius,
                                y: py - grainRadius,
                                width: grainRadius * 2,
                                height: grainRadius * 2
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(tintColor.opacity(alpha))
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
        }
    }
}

// MARK: - Modificador de Luz (+ Brilho) e Escuridão (- Sombra para a Letra)

struct LightAndShadowModifier: ViewModifier {
    let luzScore: Int
    let baseColor: Color
    let charIndex: Int      // <-- argumento #3
    let totalChars: Int     // <-- argumento #4
    let effectiveTime: Double

    /// Reproduz o ciclo do `glowIn` do HTML: cada letra começa 50 ms depois,
    /// brilha durante 1 s e aguarda 2,5 s antes de reiniciar a sequência.
    private var glowIn: (opacity: Double, intensity: Double) {
        let stagger = 0.05
        let animationDuration = 1.0
        let restDuration = 2.5
        let cycleDuration = Double(max(totalChars, 1)) * stagger + animationDuration + restDuration
        let delayedTime = effectiveTime - Double(charIndex) * stagger
        guard delayedTime >= 0 else { return (0.0, 0.0) }
        let localTime = delayedTime.truncatingRemainder(dividingBy: cycleDuration)
        guard localTime < animationDuration else {
            return (1.0, 0.0)
        }

        let progress = localTime / animationDuration
        let opacity = min(1.0, progress * 2.0)
        let intensity = progress <= 0.5
            ? progress * 2.0
            : (1.0 - progress) * 2.0
        return (opacity, max(0.0, intensity))
    }

    func body(content: Content) -> some View {
        if luzScore > 0 {
            let level = CGFloat(luzScore)
            let animation = glowIn
            let glowRadius1 = level * 3.2 * CGFloat(animation.intensity)
            let glowRadius2 = level * 7.5 * CGFloat(animation.intensity)

            content
                .brightness(Double(luzScore) * 0.06)
                .opacity(animation.opacity)
                .shadow(
                    color: Color(red: 1.0, green: 0.95, blue: 0.75).opacity(min(1.0, Double(luzScore) * 0.22) * animation.intensity),
                    radius: glowRadius1, x: 0, y: 0
                )
                .shadow(
                    color: baseColor.opacity(min(0.95, Double(luzScore) * 0.18) * animation.intensity),
                    radius: glowRadius2, x: 0, y: 0
                )
                .shadow(
                    color: Color.white.opacity((luzScore >= 4 ? Double(luzScore - 3) * 0.30 : 0.0) * animation.intensity),
                    radius: level * 11.0, x: 0, y: 0
                )
        } else if luzScore < 0 {
            let depth = CGFloat(abs(luzScore))
            content
                .shadow(
                    color: Color.black.opacity(min(0.98, 0.45 + Double(depth) * 0.11)),
                    radius: depth * 2.2, x: depth * 1.8, y: depth * 2.2
                )
                .shadow(
                    color: Color.black.opacity(min(0.90, Double(depth) * 0.16)),
                    radius: depth * 5.0, x: depth * 2.8, y: depth * 3.6
                )
        } else {
            content
        }
    }
}
