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
            dominioScore: scores[.dominio],
            calorScore: scores[.calor],
            felineContext: FontRegistrationManager.isFelineTerm(word)
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
            dominioScore: scores[.dominio],
            calorScore: scores[.calor],
            felineContext: FontRegistrationManager.isFelineTerm(word)
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
