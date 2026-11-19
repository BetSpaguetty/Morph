import SwiftUI

// MARK: - Canvas de Palavras com Flow Layout Dinâmico (Distância) e Renderização Individual

struct MorphWordsCanvasView: View {
    let tokens: [String]
    let scope: ModificationScope
    @Binding var selectedWordIndex: Int
    let elapsedTime: TimeInterval
    let isAndamentoPaused: Bool
    let isolatedParameter: MorphParameter?
    var onWhiteCanvas: Bool = false
    var onWordTap: ((Int) -> Void)? = nil
    let scoresProvider: (Int) -> ParameterScores

    /// Espaçamento base entre palavras + extra de Distância (0 a +5)
    private func wordSpacingAfter(index: Int) -> CGFloat {
        let currentDist = scoresProvider(index)[.distancia]
        let nextDist = (index + 1 < tokens.count) ? scoresProvider(index + 1)[.distancia] : currentDist
        switch max(currentDist, nextDist) {
        case 0: return 10
        case 1: return 22
        case 2: return 36
        case 3: return 52
        case 4: return 70
        case 5: return 92
        default: return 10
        }
    }

    var body: some View {
        MorphFlowLayout(
            lineSpacing: 22,
            wordSpacings: tokens.indices.map { wordSpacingAfter(index: $0) }
        ) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, wordText in
                let scores = scoresProvider(index)
                let isSelected = (scope == .specificWord && index == selectedWordIndex)
                let characterStartIndex = tokens.prefix(index).reduce(0) { $0 + $1.count } + index
                let phraseCharacterCount = tokens.joined(separator: " ").count

                MorphSingleWordView(
                    word: wordText,
                    wordIndex: index,
                    totalWords: tokens.count,
                    scores: scores,
                    isSelectedInWordMode: isSelected,
                    showWordSelectionHighlight: scope == .specificWord,
                    elapsedTime: elapsedTime,
                    isAndamentoPaused: isAndamentoPaused,
                    characterStartIndex: characterStartIndex,
                    phraseCharacterCount: phraseCharacterCount,
                    isolatedParameter: isolatedParameter,
                    onWhiteCanvas: onWhiteCanvas
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if let onWordTap {
                        onWordTap(index)
                    } else if scope == .specificWord {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedWordIndex = index
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Renderizador Completo de Uma Palavra (13 Parâmetros)

struct MorphSingleWordView: View {
    let word: String
    let wordIndex: Int
    let totalWords: Int
    let scores: ParameterScores
    let isSelectedInWordMode: Bool
    let showWordSelectionHighlight: Bool
    let elapsedTime: TimeInterval
    let isAndamentoPaused: Bool
    let characterStartIndex: Int
    let phraseCharacterCount: Int
    let isolatedParameter: MorphParameter?
    var onWhiteCanvas: Bool = false

    // MARK: 1. Ativação (-5 a +5) -> Multiplicador de velocidade de todas as animações
    private var speedMultiplier: Double {
        switch scores[.ativacao] {
        case -5: return 0.14
        case -4: return 0.24
        case -3: return 0.38
        case -2: return 0.55
        case -1: return 0.76
        case 0:  return 1.00
        case 1:  return 1.35
        case 2:  return 1.75
        case 3:  return 2.30
        case 4:  return 3.10
        case 5:  return 4.20
        default: return 1.00
        }
    }

    private var effectiveTime: Double {
        elapsedTime * speedMultiplier
    }

    // MARK: 2. Andamento (-5 a +5) -> Entrada speed dash por letra (a partir de +1)
    private var andamentoEnvelope: (opacity: Double, scaleOffset: CGFloat, yTransition: CGFloat) {
        // A entrada e a opacidade agora são calculadas por letra no speedDash.
        // Andamento zero ou negativo mantém as palavras paradas.
        (1.0, 1.0, 0.0)
    }

    // MARK: 3. Peso (-5 a +5) -> Leve (flutuar para o topo) / Pesado (afundar para a base)
    private var pesoVerticalOffset: CGFloat {
        let peso = scores[.peso]
        guard peso != 0 else { return 0 }

        let baseShift = CGFloat(peso) * 15.6
        if peso < 0 {
            let floatAmplitude = CGFloat(abs(peso)) * 2.2
            let bobbing = sin(effectiveTime * 2.2 + Double(wordIndex) * 0.9) * Double(floatAmplitude)
            return baseShift + CGFloat(bobbing)
        } else {
            let heavySettle = abs(sin(effectiveTime * 1.4 + Double(wordIndex))) * Double(peso) * 0.8
            return baseShift + CGFloat(heavySettle)
        }
    }

    // MARK: 4. Calor (-5 a +5) + Luz (-5 a +5) -> Cor Térmica e Claridade/Escuridão
    private var resolvedColor: Color {
        let calor = scores[.calor]
        let luz = scores[.luz]

        let neutralRGB: (r: Double, g: Double, b: Double) = onWhiteCanvas
            ? (0.10, 0.11, 0.15)
            : (0.95, 0.96, 0.98)

        let baseRGB: (r: Double, g: Double, b: Double) = {
            switch calor {
            case -5: return (0.12, 0.24, 0.68)
            case -4: return (0.16, 0.36, 0.84)
            case -3: return (0.24, 0.54, 0.98)
            case -2: return (0.48, 0.52, 0.96)
            case -1: return (0.72, 0.58, 0.96)
            case 0:  return neutralRGB
            case 1:  return (0.99, 0.76, 0.34)
            case 2:  return (0.99, 0.58, 0.20)
            case 3:  return (0.98, 0.42, 0.12)
            case 4:  return (0.96, 0.24, 0.12)
            case 5:  return (0.92, 0.10, 0.14)
            default: return neutralRGB
            }
        }()

        if luz < 0 {
            let darkenFactor = 1.0 - (Double(abs(luz)) * 0.14)
            return Color(
                red: baseRGB.r * darkenFactor,
                green: baseRGB.g * darkenFactor,
                blue: baseRGB.b * darkenFactor
            )
        } else if luz > 0 {
            let boost = Double(luz) * 0.06
            return Color(
                red: min(1.0, baseRGB.r + boost),
                green: min(1.0, baseRGB.g + boost),
                blue: min(1.0, baseRGB.b + boost * 0.8)
            )
        }

        return Color(red: baseRGB.r, green: baseRGB.g, blue: baseRGB.b)
    }

    // MARK: 5. Abertura (-5 a +5) -> Espaçamento entre as letras
    private var letterSpacing: CGFloat {
        switch scores[.abertura] {
        case -5: return -4.5
        case -4: return -3.4
        case -3: return -2.4
        case -2: return -1.5
        case -1: return -0.7
        case 0:  return 0.0
        case 1:  return 3.0
        case 2:  return 6.5
        case 3:  return 10.5
        case 4:  return 15.0
        case 5:  return 21.0
        default: return 0.0
        }
    }

    // MARK: 6. Tensão (-5 a +5) -> Vibração da palavra
    private var wordTensionJitter: (dx: CGFloat, dy: CGFloat, angle: Double) {
        let tensao = scores[.tensao]
        guard tensao > 0 else { return (0, 0, 0) }
        let intensity = Double(tensao)
        let freq = 28.0 + intensity * 7.0
        let phase = effectiveTime * freq + Double(wordIndex) * 3.7
        let dx = CGFloat(sin(phase * 1.3) * cos(phase * 0.7) * intensity * 1.45)
        let dy = CGFloat(cos(phase * 1.7) * sin(phase * 1.1) * intensity * 1.25)
        let angle = sin(phase * 0.9) * intensity * 0.55
        return (dx, dy, angle)
    }

    private var isolatedActivationPulseScale: CGFloat {
        let ativacao = scores[.ativacao]
        let hasOtherTemporal = scores[.fluidez] > 0
            || scores[.tensao] > 0
            || scores[.fragmentacao] > 0
            || scores[.andamento] > 0
            || scores[.peso] != 0

        guard (ativacao != 0 && !hasOtherTemporal) || isolatedParameter == .ativacao else {
            return 1.0
        }
        let pulse = sin(effectiveTime * 3.2 + Double(wordIndex) * 0.6)
        let amp: CGFloat = ativacao < 0 ? 0.06 : 0.12
        return 1.0 + CGFloat(pulse) * amp
    }

    private var charactersRow: some View {
        let typography = FontRegistrationManager.shared.resolveTypography(
            tomScore: scores[.tom],
            volumeScore: scores[.volume],
            dominioScore: scores[.dominio]
        )
        let characters = Array(word)
        let fragScore = scores[.fragmentacao]
        let luzScore = scores[.luz]
        let tint = resolvedColor

        return HStack(spacing: letterSpacing) {
            ForEach(Array(characters.enumerated()), id: \.offset) { charIdx, ch in
                MorphCharacterNodeView(
                    character: ch,
                    charIndex: charIdx,
                    totalChars: characters.count,
                    wordIndex: wordIndex,
                    typography: typography,
                    color: tint,
                    fluidezScore: scores[.fluidez],
                    tensaoScore: scores[.tensao],
                    fragmentacaoScore: fragScore,
                    luzScore: luzScore,
                    ativacaoScore: scores[.ativacao],
                    isolatedParameter: isolatedParameter,
                    andamentoScore: scores[.andamento],
                    characterSequenceIndex: characterStartIndex + charIdx,
                    phraseCharacterCount: phraseCharacterCount,
                    isAndamentoPaused: isAndamentoPaused,
                    effectiveTime: effectiveTime
                )
            }
        }
        .modifier(
            GranulationFadeModifier(
                fragmentacaoScore: fragScore,
                effectiveTime: effectiveTime,
                wordSeed: wordIndex,
                tintColor: tint
            )
        )
    }

    var body: some View {
        let typography = FontRegistrationManager.shared.resolveTypography(
            tomScore: scores[.tom],
            volumeScore: scores[.volume],
            dominioScore: scores[.dominio]
        )
        let env = andamentoEnvelope
        let jitter = wordTensionJitter
        let peso = scores[.peso]
        let squashX: CGFloat = peso >= 4 ? 1.0 + CGFloat(peso - 3) * 0.04 : 1.0
        let squashY: CGFloat = peso >= 4 ? 1.0 - CGFloat(peso - 3) * 0.04 : 1.0
        let combinedScale: CGFloat = env.scaleOffset * isolatedActivationPulseScale
        let combinedOpacity: Double = env.opacity * typography.whisperOpacityMultiplier
        let totalOffsetY: CGFloat = pesoVerticalOffset + env.yTransition + jitter.dy
        let padH: CGFloat = showWordSelectionHighlight ? 6 : 2
        let padV: CGFloat = showWordSelectionHighlight ? 4 : 2

        charactersRow
            .scaleEffect(x: squashX * combinedScale, y: squashY * combinedScale)
            .opacity(combinedOpacity)
            .rotationEffect(.degrees(jitter.angle))
            .offset(x: jitter.dx, y: totalOffsetY)
            .padding(.horizontal, padH)
            .padding(.vertical, padV)
            .background {
                if isSelectedInWordMode {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.cyan.opacity(0.08))
                        )
                        .offset(y: pesoVerticalOffset + env.yTransition)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: scores)
    }
}

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

// MARK: - Layout Customizado de Fluxo com Espaçamento por Palavra (Distância)

struct MorphFlowLayout: Layout {
    var lineSpacing: CGFloat = 18
    var wordSpacings: [CGFloat] = []

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 340
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let totalHeight = rows.reduce(CGFloat(0)) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: maxWidth, height: max(60, totalHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        let totalHeight = rows.reduce(CGFloat(0)) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        var currentY = bounds.minY + max(0, (bounds.height - totalHeight) / 2.0)

        for row in rows {
            var currentX = bounds.minX + max(0, (bounds.width - row.totalWidth) / 2.0)
            for item in row.items {
                let yPos = currentY + (row.maxHeight - item.size.height) / 2.0
                item.subview.place(
                    at: CGPoint(x: currentX, y: yPos),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                currentX += item.size.width + item.spacingAfter
            }
            currentY += row.maxHeight + lineSpacing
        }
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
        let spacingAfter: CGFloat
    }

    private struct Row {
        var items: [RowItem] = []
        var totalWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        guard !subviews.isEmpty else { return [] }
        var rows: [Row] = [Row()]

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let spacing = index < wordSpacings.count ? wordSpacings[index] : 10.0

            let currentRow = rows[rows.count - 1]
            let proposedWidth = currentRow.items.isEmpty
                ? size.width
                : currentRow.totalWidth + (currentRow.items.last?.spacingAfter ?? 10.0) + size.width

            if !currentRow.items.isEmpty && proposedWidth > maxWidth {
                var newRow = Row()
                newRow.items.append(RowItem(subview: subview, size: size, spacingAfter: spacing))
                newRow.totalWidth = size.width
                newRow.maxHeight = size.height
                rows.append(newRow)
            } else {
                let prevSpacing = currentRow.items.last?.spacingAfter ?? 0
                rows[rows.count - 1].items.append(RowItem(subview: subview, size: size, spacingAfter: spacing))
                rows[rows.count - 1].totalWidth += (currentRow.items.isEmpty ? 0 : prevSpacing) + size.width
                rows[rows.count - 1].maxHeight = max(rows[rows.count - 1].maxHeight, size.height)
            }
        }
        return rows
    }
}
