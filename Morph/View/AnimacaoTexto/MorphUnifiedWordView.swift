import SwiftUI

// MARK: - Container de Relógio Isolado por Palavra (0% CPU em Palavras Estáticas ou Entradas Concluídas)

struct MorphWordClockView: View, Equatable {
    let plan: WordAnimationPlan
    let stageReferenceDate: Date
    let isPaused: Bool
    let isSelectedInWordMode: Bool
    let showWordSelectionHighlight: Bool
    var onWhiteCanvas: Bool = true
    var maxAvailableWidth: CGFloat = 320

    @State private var entranceSettled = false

    static func == (lhs: MorphWordClockView, rhs: MorphWordClockView) -> Bool {
        lhs.plan == rhs.plan
            && lhs.stageReferenceDate == rhs.stageReferenceDate
            && lhs.isPaused == rhs.isPaused
            && lhs.isSelectedInWordMode == rhs.isSelectedInWordMode
            && lhs.showWordSelectionHighlight == rhs.showWordSelectionHighlight
            && lhs.onWhiteCanvas == rhs.onWhiteCanvas
            && abs(lhs.maxAvailableWidth - rhs.maxAvailableWidth) < 0.5
    }

    var body: some View {
        if plan.hasContinuousTimeAnimation {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isPaused)) { context in
                let elapsed = isPaused ? 0 : max(0, context.date.timeIntervalSince(stageReferenceDate))
                MorphUnifiedWordView(
                    plan: plan,
                    elapsedTime: elapsed,
                    isSelectedInWordMode: isSelectedInWordMode,
                    showWordSelectionHighlight: showWordSelectionHighlight,
                    onWhiteCanvas: onWhiteCanvas,
                    maxAvailableWidth: maxAvailableWidth
                )
            }
        } else if plan.entrance != nil {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isPaused || entranceSettled)) { context in
                let elapsed: Double = {
                    if isPaused { return 0 }
                    if entranceSettled { return plan.entranceTotalDuration + 1.0 }
                    return max(0, context.date.timeIntervalSince(stageReferenceDate))
                }()
                MorphUnifiedWordView(
                    plan: plan,
                    elapsedTime: elapsed,
                    isSelectedInWordMode: isSelectedInWordMode,
                    showWordSelectionHighlight: showWordSelectionHighlight,
                    onWhiteCanvas: onWhiteCanvas,
                    maxAvailableWidth: maxAvailableWidth
                )
            }
            .task(id: stageReferenceDate) {
                entranceSettled = false
                let wait = max(0.1, plan.entranceTotalDuration)
                try? await Task.sleep(for: .seconds(wait))
                if !Task.isCancelled {
                    entranceSettled = true
                }
            }
        } else {
            // Palavra 100% estática: sem TimelineView (0 atualizações/seg).
            MorphUnifiedWordView(
                plan: plan,
                elapsedTime: 0,
                isSelectedInWordMode: isSelectedInWordMode,
                showWordSelectionHighlight: showWordSelectionHighlight,
                onWhiteCanvas: onWhiteCanvas,
                maxAvailableWidth: maxAvailableWidth
            )
        }
    }
}

// MARK: - Primitivos 2 e 4 + Renderizador Unificado dos 5 Canais por Palavra

struct MorphUnifiedWordView: View {
    let plan: WordAnimationPlan
    let elapsedTime: TimeInterval
    let isSelectedInWordMode: Bool
    let showWordSelectionHighlight: Bool
    var onWhiteCanvas: Bool = true
    var maxAvailableWidth: CGFloat = 320

    private var effectiveTime: Double {
        elapsedTime * plan.speedMultiplier
    }

    private var displayWord: String {
        plan.overlay?.effectID == .kwEstouroPopArt ? plan.word.uppercased() : plan.word
    }

    private var characters: [Character] {
        Array(displayWord)
    }

    private var isEntranceActive: Bool {
        plan.entrance != nil && elapsedTime < plan.entranceTotalDuration
    }

    /// Espaçamento estático entre letras com teto proporcional à largura da TV e ao tamanho da fonte (zero reflow/encavalamento).
    private var safeLetterSpacing: CGFloat {
        guard plan.staticStructure?.effectID == .abertEspacamentoLetras else {
            return 0
        }
        let abertura = plan.scores[.abertura]
        guard abertura != 0 else { return 0 }
        if abertura < 0 {
            let maxCompression = min(2.2, plan.typography.fontSize * 0.055)
            return CGFloat(abertura) / 5.0 * maxCompression
        }
        let desired: [Int: CGFloat] = [1: 2.5, 2: 5.0, 3: 7.5, 4: 10.0, 5: 12.5]
        let target = desired[abertura] ?? 0
        let gaps = CGFloat(max(1, characters.count - 1))
        let estimatedBaseWidth = CGFloat(characters.count) * plan.typography.fontSize * 0.62
        let maxExtraTotal = max(0, (maxAvailableWidth * 0.86) - estimatedBaseWidth)
        return min(target, maxExtraTotal / gaps)
    }

    /// Reduz proporcionalmente palavras muito longas (ex.: 12+ letras com Domínio alto)
    /// para caberem inteiras na largura útil da TV CRT sem cortar nem invadir vizinhas.
    private var wordFitScale: CGFloat {
        let chars = CGFloat(max(1, displayWord.count))
        let charFactor: CGFloat = plan.typography.familyName == "SF Padrão" ? 0.63 : 0.58
        let spacingExtra = max(0, safeLetterSpacing) * max(0, chars - 1)
        let estContentW = chars * plan.typography.fontSize * charFactor + spacingExtra
        let extraW = plan.horizontalVisualOverhang * 2
            + (plan.overlay?.effectID == .kwEstouroPopArt ? 24 : 0)
            + 8
        let totalEstW = estContentW + extraW
        let limit = max(120, maxAvailableWidth * 0.96)
        guard totalEstW > limit else { return 1.0 }
        return max(0.55, limit / totalEstW)
    }

    private var baseTint: Color {
        MorphSurfaceResolver.baseTintColor(
            plan: plan,
            effectiveTime: effectiveTime,
            onWhiteCanvas: onWhiteCanvas
        )
    }

    /// Fast-path total: palavra neutra/estática sem nenhum canal visual dinâmico.
    private var isPurePlainWord: Bool {
        plan.staticStructure == nil
            && plan.surface == nil
            && plan.entrance == nil
            && plan.continuous == nil
            && plan.overlay == nil
    }

    var body: some View {
        let hOverhang = plan.horizontalVisualOverhang
        let vOverhang = plan.verticalVisualOverhang
        let padH: CGFloat = (showWordSelectionHighlight ? 6 : 3) + hOverhang
        let padTop: CGFloat = (showWordSelectionHighlight ? 4 : 2) + vOverhang.top
        let padBottom: CGFloat = (showWordSelectionHighlight ? 4 : 2) + vOverhang.bottom
        let fitScale = wordFitScale

        MorphScaledLayout(scale: fitScale) {
            Group {
                if isPurePlainWord {
                    let style = MorphSurfaceResolver.foregroundStyle(
                        plan: plan,
                        elapsed: 0,
                        effectiveTime: 0,
                        charIndex: 0,
                        totalChars: 1,
                        onWhiteCanvas: onWhiteCanvas
                    )
                    MorphGlyphTextView(text: plan.word, typography: plan.typography, style: style, tracking: 0)
                } else {
                    wordWithLayersAndGPU
                }
            }
            .opacity(plan.typography.whisperOpacityMultiplier)
            .padding(.leading, padH)
            .padding(.trailing, padH)
            .padding(.top, padTop)
            .padding(.bottom, padBottom)
            .background {
                if isSelectedInWordMode {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.cyan.opacity(0.08))
                        )
                }
            }
            .scaleEffect(fitScale, anchor: .center)
        }
    }

    // MARK: - Conteúdo da Palavra (Structs Nominais para Evitar Explosão de Tipos Opacos no Swift)

    private func styledCharactersRow(overrideColor: Color? = nil, forceVisible: Bool = false) -> MorphStyledCharactersRowView {
        MorphStyledCharactersRowView(
            plan: plan,
            displayWord: displayWord,
            elapsedTime: elapsedTime,
            effectiveTime: effectiveTime,
            isEntranceActive: isEntranceActive,
            safeLetterSpacing: safeLetterSpacing,
            glowTintColor: glowTintColor,
            onWhiteCanvas: onWhiteCanvas,
            overrideColor: overrideColor,
            forceVisible: forceVisible
        )
    }

    /// Cópia leve para camadas traseiras de eco/sombra/aberração: usa 1 Text quando não há distorção por caractere.
    private func lightweightGhostWord(color: Color, forceVisible: Bool = true) -> MorphStyledCharactersRowView {
        styledCharactersRow(overrideColor: color, forceVisible: forceVisible)
    }

    private var glowTintColor: Color {
        if plan.continuous?.effectID == .kwLetreiroNeon {
            return MorphCRTSafePalette.deepPink
        }
        if plan.entrance?.effectID == .calChamaAscendente || plan.continuous?.effectID == .calFogoVivo {
            return MorphCRTSafePalette.burntOrange
        }
        return MorphCRTSafePalette.darkAmber
    }

    // MARK: - Primitivos 2 e 4: Camadas, Fatias, Outline, Partículas e Shader GPU

    @ViewBuilder
    private var wordWithLayersAndGPU: some View {
        let baseCore = coreGeometryView
        let withOverlays = applyOverlayAndEntranceLayers(to: baseCore)
        applyGPUShaderAndParticles(to: withOverlays)
    }

    @ViewBuilder
    private var coreGeometryView: some View {
        if plan.continuous?.effectID == .fragCisao {
            let phase = (effectiveTime / 2.4) * 2.0 * .pi
            let tear = pow(max(0, sin(phase)), 2) * (plan.continuous?.intensity ?? 1.0)
            ZStack {
                styledCharactersRow()
                    .clipShape(MorphSplitHalfClip(isTop: true))
                    .modifier(MorphSkewEffect(skewXDeg: -14.0 * tear, skewYDeg: 0))
                    .offset(x: 9.0 * tear, y: -2.5 * tear)
                styledCharactersRow()
                    .clipShape(MorphSplitHalfClip(isTop: false))
                    .modifier(MorphSkewEffect(skewXDeg: 14.0 * tear, skewYDeg: 0))
                    .offset(x: -9.0 * tear, y: 2.5 * tear)
            }
        } else if plan.continuous?.effectID == .calMiragemCalor {
            let bands = plan.isEcoMode ? 2 : 4
            let phase = (effectiveTime / 2.2) * 2.0 * .pi
            let amp = plan.continuous?.intensity ?? 1.0
            ZStack {
                ForEach(0..<bands, id: \.self) { band in
                    let shift = sin(phase * 2.0 + Double(band) * 1.45) * 4.0 * amp
                    let skew = cos(phase * 1.5 + Double(band) * 1.2) * 7.5 * amp
                    styledCharactersRow()
                        .clipShape(MorphBandClip(index: band, total: bands))
                        .modifier(MorphSkewEffect(skewXDeg: skew, skewYDeg: 0))
                        .offset(x: shift)
                }
            }
            .blur(radius: 0.35)
        } else if plan.continuous?.effectID == .fluidRefracaoSubmersa {
            let bands = plan.isEcoMode ? 2 : 4
            let phase = (effectiveTime / 2.6) * 2.0 * .pi
            let amp = plan.continuous?.intensity ?? 1.0
            ZStack {
                ForEach(0..<bands, id: \.self) { band in
                    let dx = sin(phase + Double(band) * 1.15) * 5.8 * amp
                    styledCharactersRow()
                        .clipShape(MorphBandClip(index: band, total: bands))
                        .offset(x: dx)
                }
            }
        } else if plan.overlay?.effectID == .fragCorteAoMeio {
            let shift = CGFloat(6.0 * (plan.overlay?.intensity ?? 1.0))
            ZStack {
                styledCharactersRow()
                    .clipShape(MorphSplitHalfClip(isTop: true))
                    .offset(x: shift, y: -1.4)
                styledCharactersRow()
                    .clipShape(MorphSplitHalfClip(isTop: false))
                    .offset(x: -shift, y: 1.4)
                Rectangle()
                    .fill(baseTint.opacity(0.75))
                    .frame(height: 1.5)
            }
        } else if plan.overlay?.effectID == .fragRachado {
            let k = CGFloat(plan.overlay?.intensity ?? 1.0)
            ZStack {
                styledCharactersRow()
                    .clipShape(MorphDiagonalHalfClip(isUpper: true))
                    .offset(x: -4.8 * k, y: -2.8 * k)
                styledCharactersRow()
                    .clipShape(MorphDiagonalHalfClip(isUpper: false))
                    .offset(x: 4.8 * k, y: 2.8 * k)
            }
        } else if plan.overlay?.effectID == .volSolidToOutline && !plan.typography.isDecorativeSingleWeight {
            let strokeW: CGFloat = 1.9
            ZStack {
                lightweightGhostWord(color: baseTint, forceVisible: false).offset(x: strokeW, y: 0)
                lightweightGhostWord(color: baseTint, forceVisible: false).offset(x: -strokeW, y: 0)
                lightweightGhostWord(color: baseTint, forceVisible: false).offset(x: 0, y: strokeW)
                lightweightGhostWord(color: baseTint, forceVisible: false).offset(x: 0, y: -strokeW)
                lightweightGhostWord(color: .black, forceVisible: false)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        } else if plan.entrance?.effectID == .fragDespedacar && isEntranceActive {
            let dur = MorphGlyphTransformEngine.entranceDuration(for: .fragDespedacar)
            let p = MorphEasing.easeOutCubic(MorphGlyphTransformEngine.wholeEntranceProgress(elapsed: elapsedTime, duration: dur))
            let rem = 1.0 - p
            ZStack {
                styledCharactersRow()
                    .clipShape(MorphSplitHalfClip(isTop: true))
                    .offset(x: -10.0 * rem, y: -7.0 * rem)
                styledCharactersRow()
                    .clipShape(MorphSplitHalfClip(isTop: false))
                    .offset(x: 10.0 * rem, y: 7.0 * rem)
            }
        } else if plan.entrance?.effectID == .kwTracoParaTinta && isEntranceActive {
            let dur = MorphGlyphTransformEngine.entranceDuration(for: .kwTracoParaTinta)
            let t = MorphGlyphTransformEngine.wholeEntranceProgress(elapsed: elapsedTime, duration: dur)
            let strokeAlpha = min(1.0, t * 2.8)
            let fillProgress = MorphEasing.smoothstep(min(1.0, max(0.0, (t - 0.32) / 0.68)))
            let strokeW: CGFloat = 1.2
            ZStack {
                ZStack {
                    lightweightGhostWord(color: baseTint, forceVisible: true).offset(x: strokeW, y: 0)
                    lightweightGhostWord(color: baseTint, forceVisible: true).offset(x: -strokeW, y: 0)
                    lightweightGhostWord(color: baseTint, forceVisible: true).offset(x: 0, y: strokeW)
                    lightweightGhostWord(color: baseTint, forceVisible: true).offset(x: 0, y: -strokeW)
                    lightweightGhostWord(color: .black, forceVisible: true)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .opacity(strokeAlpha * (1.0 - fillProgress * 0.85))

                styledCharactersRow()
                    .clipShape(MorphBottomUpFillClip(progress: fillProgress))
            }
        } else {
            styledCharactersRow()
        }
    }

    @ViewBuilder
    private func applyOverlayAndEntranceLayers<Content: View>(to base: Content) -> some View {
        let hasEntranceLayers: Bool = {
            guard isEntranceActive, let id = plan.entrance?.effectID else { return false }
            return id == .valCaleidoscopioPrismatico || id == .valImpressaoCMYK || id == .pesoRastroVertical
        }()
        let hasOverlayLayers = plan.overlay != nil

        if !hasEntranceLayers && !hasOverlayLayers {
            base
        } else {
            ZStack {
                if hasEntranceLayers, let entrance = plan.entrance {
                    let dur = MorphGlyphTransformEngine.entranceDuration(for: entrance.effectID)
                    let t = MorphGlyphTransformEngine.wholeEntranceProgress(elapsed: elapsedTime, duration: dur)
                    if t < 1.0 {
                        switch entrance.effectID {
                        case .valCaleidoscopioPrismatico:
                            let p = MorphEasing.easeOutCubic(t)
                            let rem = 1.0 - p
                            lightweightGhostWord(color: MorphCRTSafePalette.deepCrimson)
                                .rotationEffect(.degrees(-16 * rem))
                                .offset(x: -24 * rem, y: -12 * rem)
                                .opacity(rem * 0.85)
                            lightweightGhostWord(color: Color(red: 0.06, green: 0.54, blue: 0.24))
                                .rotationEffect(.degrees(12 * rem))
                                .offset(x: 20 * rem, y: -10 * rem)
                                .opacity(rem * 0.85)
                            lightweightGhostWord(color: MorphCRTSafePalette.deepIndigo)
                                .rotationEffect(.degrees(-8 * rem))
                                .offset(x: 0, y: 20 * rem)
                                .opacity(rem * 0.85)

                        case .valImpressaoCMYK:
                            let cP = MorphEasing.smoothstep(min(1, t / 0.30))
                            let mP = MorphEasing.smoothstep(min(1, max(0, (t - 0.22) / 0.30)))
                            let pP = MorphEasing.smoothstep(min(1, max(0, (t - 0.44) / 0.30)))
                            let kP = MorphEasing.smoothstep(min(1, max(0, (t - 0.64) / 0.36)))
                            lightweightGhostWord(color: MorphCRTSafePalette.deepCyan)
                                .offset(x: -13 * (1 - cP) - 3 * (1 - kP), y: -3 * (1 - kP))
                                .opacity(cP * (1 - kP * 0.88))
                            lightweightGhostWord(color: MorphCRTSafePalette.deepPink)
                                .offset(x: 13 * (1 - mP) + 3 * (1 - kP), y: -2 * (1 - kP))
                                .opacity(mP * (1 - kP * 0.88))
                            lightweightGhostWord(color: MorphCRTSafePalette.deepPurple)
                                .offset(y: 11 * (1 - pP) + 3 * (1 - kP))
                                .opacity(pP * (1 - kP * 0.88))

                        case .pesoRastroVertical:
                            let p = MorphEasing.easeOutCubic(t)
                            let rem = 1.0 - p
                            let trails = plan.isEcoMode ? 2 : 3
                            ForEach(1...trails, id: \.self) { trail in
                                lightweightGhostWord(color: baseTint)
                                    .offset(y: CGFloat(-34 * rem - Double(trail) * 8 * rem))
                                    .opacity(rem > 0.02 ? (0.30 / Double(trail)) * min(1, p * 2.5) : 0)
                            }

                        default:
                            EmptyView()
                        }
                    }
                }

                if let overlay = plan.overlay {
                    overlayBackLayers(for: overlay)
                }

                styledMainWord(base)
            }
        }
    }

    @ViewBuilder
    private func overlayBackLayers(for overlay: ResolvedEffectSlot) -> some View {
        let amp = overlay.intensity

        switch overlay.effectID {
        case .calNevoaAscendente:
            let count = plan.isEcoMode ? 1 : 3
            let p = (effectiveTime / 2.6).truncatingRemainder(dividingBy: 1.0)
            ForEach(0..<count, id: \.self) { i in
                let f = (p + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1.0)
                lightweightGhostWord(color: baseTint)
                    .offset(x: sin(f * 2 * .pi) * 6, y: -f * 26 * amp)
                    .blur(radius: CGFloat(f * 6))
                    .opacity((1 - f) * 0.42)
            }

        case .calSmokeOut:
            let count = plan.isEcoMode ? 1 : 2
            let p = (effectiveTime / 2.2).truncatingRemainder(dividingBy: 1.0)
            ForEach(0..<count, id: \.self) { i in
                let f = (p + Double(i) * 0.5).truncatingRemainder(dividingBy: 1.0)
                lightweightGhostWord(color: baseTint.opacity(0.65))
                    .scaleEffect(1.0 + f * 0.28)
                    .offset(y: -f * 24 * amp)
                    .blur(radius: CGFloat(f * 7))
                    .opacity((1 - f) * 0.50)
            }

        case .luzEscurecimento:
            let phase = (effectiveTime / 3.2) * 2.0 * .pi
            let sweep = (0.5 - 0.5 * cos(phase)) * min(1.0, amp)
            lightweightGhostWord(color: .black)
                .modifier(MorphSkewEffect(skewXDeg: 32 * sweep, skewYDeg: 0))
                .offset(x: 9 * sweep, y: 4 * sweep)
                .blur(radius: CGFloat(sweep * 2.8))
                .opacity(0.55 * sweep)

        case .distVisaoDupla:
            let phase = (effectiveTime / 3.4) * 2.0 * .pi
            let sep = (0.5 - 0.5 * cos(phase)) * 8.0 * amp
            lightweightGhostWord(color: baseTint)
                .offset(x: -sep, y: -sep * 0.35)
                .blur(radius: CGFloat(sep * 0.22))
                .opacity(0.45)
            lightweightGhostWord(color: baseTint)
                .offset(x: sep, y: sep * 0.35)
                .blur(radius: CGFloat(sep * 0.22))
                .opacity(0.45)

        case .volOndasEco:
            let p1 = (effectiveTime / 2.2).truncatingRemainder(dividingBy: 1.0)
            let p2 = (p1 + 0.5).truncatingRemainder(dividingBy: 1.0)
            lightweightGhostWord(color: baseTint)
                .scaleEffect(1.0 + p1 * 0.34 * amp)
                .opacity((1.0 - p1) * 0.42)
            if !plan.isEcoMode {
                lightweightGhostWord(color: baseTint)
                    .scaleEffect(1.0 + p2 * 0.34 * amp)
                    .opacity((1.0 - p2) * 0.42)
            }

        case .volEcoDirecional:
            let phase = (effectiveTime / 2.6) * 2.0 * .pi
            let spread = (0.5 - 0.5 * cos(phase)) * 10.5 * amp
            lightweightGhostWord(color: baseTint)
                .offset(x: -spread)
                .opacity(0.28)
            lightweightGhostWord(color: baseTint)
                .offset(x: spread)
                .opacity(0.28)

        case .volBerroDistorcido:
            let s = min(1.20, 1.0 + 0.18 * amp)
            lightweightGhostWord(color: MorphCRTSafePalette.deepCrimson)
                .scaleEffect(s)
                .offset(x: 2.5, y: -2.0)
                .opacity(0.62)

        case .valSombrasGemeas:
            let phase = (effectiveTime / 2.8) * 2.0 * .pi
            let ax = sin(phase) * 7.5 * amp
            let ay = sin(phase * 2.0) * 4.5 * amp
            lightweightGhostWord(color: MorphCRTSafePalette.deepPink)
                .offset(x: ax, y: ay)
                .opacity(0.62)
            lightweightGhostWord(color: MorphCRTSafePalette.deepCyan)
                .offset(x: -ax, y: -ay)
                .opacity(0.62)

        case .valAberracaoCromatica:
            let phase = (effectiveTime / 2.4) * 2.0 * .pi
            let r = 4.0 * amp
            lightweightGhostWord(color: MorphCRTSafePalette.deepCrimson)
                .offset(x: cos(phase) * r, y: sin(phase) * r)
                .opacity(0.72)
            lightweightGhostWord(color: Color(red: 0.06, green: 0.54, blue: 0.24))
                .offset(x: cos(phase + 2.094) * r, y: sin(phase + 2.094) * r)
                .opacity(0.68)
            lightweightGhostWord(color: MorphCRTSafePalette.deepIndigo)
                .offset(x: cos(phase + 4.188) * r, y: sin(phase + 4.188) * r)
                .opacity(0.72)

        case .valAnaglifo3D:
            let sep = 3.2 * amp
            lightweightGhostWord(color: MorphCRTSafePalette.deepCrimson)
                .offset(x: -sep, y: 0)
                .opacity(0.76)
            lightweightGhostWord(color: MorphCRTSafePalette.deepCyan)
                .offset(x: sep, y: 0)
                .opacity(0.76)

        case .valCartasCMYOrbita:
            let phase = (effectiveTime / 2.2) * 2.0 * .pi
            let r = 4.8 * amp
            lightweightGhostWord(color: MorphCRTSafePalette.deepCyan)
                .offset(x: cos(phase) * r, y: sin(phase) * r)
                .opacity(0.70)
            lightweightGhostWord(color: MorphCRTSafePalette.deepPink)
                .offset(x: cos(phase + 2.094) * r, y: sin(phase + 2.094) * r)
                .opacity(0.70)
            lightweightGhostWord(color: MorphCRTSafePalette.deepPurple)
                .offset(x: cos(phase + 4.188) * r, y: sin(phase + 4.188) * r)
                .opacity(0.70)

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func styledMainWord<Content: View>(_ base: Content) -> some View {
        switch plan.overlay?.effectID {
        case .luzPulseNeon:
            let phase = (effectiveTime / 1.5) * 2.0 * .pi
            let pulse = 0.55 + 0.45 * (0.5 + 0.5 * cos(phase))
            let amp = plan.overlay?.intensity ?? 1.0
            base
                .shadow(color: MorphCRTSafePalette.darkAmber.opacity(0.85 * pulse), radius: CGFloat(5 * amp * pulse))
                .shadow(color: MorphCRTSafePalette.deepCyan.opacity(0.85 * pulse), radius: CGFloat(12 * amp * pulse))
                .opacity(0.75 + 0.25 * pulse)

        case .luzEscurecimento:
            let phase = (effectiveTime / 3.2) * 2.0 * .pi
            let sweep = 0.5 - 0.5 * cos(phase)
            base
                .opacity(max(0.58, 1.0 - sweep * 0.40))

        case .volBerroDistorcido:
            let amp = plan.overlay?.intensity ?? 1.0
            base
                .scaleEffect(min(1.18, 1.0 + 0.16 * amp))
                .rotationEffect(.degrees(-3.5 * amp))

        case .calGelidoQuebradico:
            base
                .modifier(MorphSkewEffect(skewXDeg: 11.0, skewYDeg: 0))
                .overlay {
                    Canvas { ctx, size in
                        var cracks = Path()
                        cracks.move(to: CGPoint(x: size.width * 0.22, y: 0))
                        cracks.addLine(to: CGPoint(x: size.width * 0.34, y: size.height))
                        cracks.move(to: CGPoint(x: size.width * 0.68, y: 0))
                        cracks.addLine(to: CGPoint(x: size.width * 0.56, y: size.height))
                        ctx.stroke(cracks, with: .color(.black.opacity(0.85)), lineWidth: 2.2)
                    }
                    .blendMode(.destinationOut)
                    .allowsHitTesting(false)
                }
                .compositingGroup()

        case .kwSombraOrbitante:
            let phase = (effectiveTime / 3.2) * 2.0 * .pi
            base.shadow(
                color: Color.black.opacity(0.42),
                radius: 3.5,
                x: CGFloat(cos(phase) * 10.0),
                y: CGFloat(sin(phase) * 10.0)
            )

        case .kwTarjaCensurada:
            let tilt: Double = plan.wordIndex.isMultiple(of: 2) ? -1.4 : 1.4
            base
                .padding(.horizontal, 4)
                .overlay {
                    Rectangle()
                        .fill(MorphCRTSafePalette.defaultInk(onWhiteCanvas: onWhiteCanvas))
                        .scaleEffect(x: 1.04, y: 0.82)
                        .rotationEffect(.degrees(tilt))
                        .allowsHitTesting(false)
                }

        case .kwEstouroPopArt:
            let isDeco = plan.typography.isDecorativeSingleWeight
            base
                .shadow(color: Color.black.opacity(isDeco ? 0.0 : 0.82), radius: 0, x: 2.5, y: 2.5)
                .rotationEffect(.degrees(-5.0))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if !isDeco {
                        MorphStarburstShape(points: 12, spinDeg: 10)
                            .fill(Color(red: 0.90, green: 0.66, blue: 0.04))
                            .overlay(
                                MorphStarburstShape(points: 12, spinDeg: 10)
                                    .stroke(MorphCRTSafePalette.deepCrimson, lineWidth: 2.4)
                            )
                            .allowsHitTesting(false)
                    }
                }

        default:
            base
        }
    }

    @ViewBuilder
    private func applyGPUShaderAndParticles<Content: View>(to view: Content) -> some View {
        let erosionParams = resolveErosionParams()
        if let ep = erosionParams {
            applySnowParticlesIfNeeded(
                to: view.visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.morphErosionEffect(
                            .float2(proxy.size),
                            .float(ep.cellSize),
                            .float(ep.threshold),
                            .float(ep.timeTick),
                            .float(ep.verticalBias),
                            .float(ep.minAlphaFloor)
                        )
                    )
                }
            )
        } else {
            applySnowParticlesIfNeeded(to: view)
        }
    }

    @ViewBuilder
    private func applySnowParticlesIfNeeded<Content: View>(to view: Content) -> some View {
        if plan.overlay?.effectID == .calNevascaCristalina {
            let flakes = plan.isEcoMode ? 8 : 16
            let t = effectiveTime
            view.overlay {
                Canvas { ctx, size in
                    for i in 0..<flakes {
                        let u1 = Double(MorphDeterministicHash.mix(i, 1, 560) & 0xFFFF) / 65535.0
                        let u2 = Double(MorphDeterministicHash.mix(i, 2, 561) & 0xFFFF) / 65535.0
                        let u3 = Double(MorphDeterministicHash.mix(i, 3, 562) & 0xFFFF) / 65535.0
                        let u4 = Double(MorphDeterministicHash.mix(i, 4, 563) & 0xFFFF) / 65535.0
                        let speed = 0.35 + u1 * 0.45
                        let yFrac = (t * speed + u2).truncatingRemainder(dividingBy: 1.0)
                        let xFrac = (u3 + t * 0.14).truncatingRemainder(dividingBy: 1.0)
                        let r = CGFloat(1.6 + u4 * 2.2)
                        let rect = CGRect(x: xFrac * size.width - r, y: yFrac * size.height - r, width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(MorphCRTSafePalette.glacialMid.opacity(0.88)))
                        ctx.stroke(Path(ellipseIn: rect), with: .color(MorphCRTSafePalette.deepIndigo.opacity(0.45)), lineWidth: 0.7)
                    }
                }
                .allowsHitTesting(false)
            }
        } else {
            view
        }
    }

    private struct ErosionShaderParams: Sendable {
        let cellSize: Float
        let threshold: Float
        let timeTick: Float
        let verticalBias: Float
        let minAlphaFloor: Float
    }

    private func resolveErosionParams() -> ErosionShaderParams? {
        guard !plan.typography.isDecorativeSingleWeight else { return nil }

        if plan.continuous?.effectID == .fragDesintegracao {
            let amp = plan.continuous?.intensity ?? 1.0
            let phase = (effectiveTime / 2.6) * 2.0 * .pi
            let decay = Float(min(0.62, (0.20 + 0.18 * (0.5 - 0.5 * cos(phase))) * amp))
            let tick = Float(Int(effectiveTime * 10.0) % 256)
            return ErosionShaderParams(cellSize: 4.5, threshold: decay, timeTick: tick, verticalBias: 0.0, minAlphaFloor: 0.0)
        }

        if plan.overlay?.effectID == .fragFadeGranulado {
            let amp = plan.overlay?.intensity ?? 1.0
            let phase = (effectiveTime / 3.2) * 2.0 * .pi
            let erosion = Float(min(0.70, (0.12 + 0.42 * (0.5 - 0.5 * cos(phase))) * amp))
            let tick = Float(Int(effectiveTime * 16.0) % 256)
            return ErosionShaderParams(cellSize: 4.5, threshold: erosion, timeTick: tick, verticalBias: 0.0, minAlphaFloor: 0.16)
        }

        if plan.overlay?.effectID == .fragCorroido {
            let amp = plan.overlay?.intensity ?? 1.0
            return ErosionShaderParams(cellSize: 4.0, threshold: Float(min(0.68, 0.48 * amp)), timeTick: 1.0, verticalBias: 1.0, minAlphaFloor: 0.0)
        }

        return nil
    }
}

// MARK: - Subviews Nominais (Mantêm Substituição de Tipos Opacos em O(1) no SwiftUI)

private struct MorphScaledLayout: Layout {
    let scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let first = subviews.first else { return .zero }
        let raw = first.sizeThatFits(.unspecified)
        guard scale < 0.999 else { return raw }
        return CGSize(width: raw.width * scale, height: raw.height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let first = subviews.first else { return }
        first.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: .unspecified
        )
    }
}

private struct MorphGlyphTextView: View {
    let text: String
    let typography: ResolvedTypography
    let style: AnyShapeStyle
    let tracking: CGFloat

    var body: some View {
        if typography.extraStrokeWidth > 0 && !typography.isDecorativeSingleWeight {
            let d = typography.extraStrokeWidth
            ZStack {
                Text(text).font(typography.font).tracking(tracking).foregroundStyle(style).fixedSize().offset(x: d, y: 0)
                Text(text).font(typography.font).tracking(tracking).foregroundStyle(style).fixedSize().offset(x: -d, y: 0)
                Text(text).font(typography.font).tracking(tracking).foregroundStyle(style).fixedSize().offset(x: 0, y: d * 0.7)
                Text(text).font(typography.font).tracking(tracking).foregroundStyle(style).fixedSize().offset(x: 0, y: -d * 0.7)
                Text(text).font(typography.font).tracking(tracking).foregroundStyle(style).fixedSize()
            }
        } else {
            Text(text)
                .font(typography.font)
                .tracking(tracking)
                .foregroundStyle(style)
                .fixedSize()
        }
    }
}

private struct MorphStyledCharactersRowView: View {
    private static let slotReelChars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    let plan: WordAnimationPlan
    let displayWord: String
    let elapsedTime: TimeInterval
    let effectiveTime: Double
    let isEntranceActive: Bool
    let safeLetterSpacing: CGFloat
    let glowTintColor: Color
    let onWhiteCanvas: Bool
    var overrideColor: Color? = nil
    var forceVisible: Bool = false

    var body: some View {
        let typography = plan.typography
        let needsPerChar = plan.needsPerCharLayout(entranceActive: isEntranceActive)

        if !needsPerChar {
            let tf = MorphGlyphTransformEngine.evaluate(
                plan: plan,
                charIndex: 0,
                totalChars: 1,
                elapsed: elapsedTime
            )
            let style: AnyShapeStyle = overrideColor.map(AnyShapeStyle.init) ?? MorphSurfaceResolver.foregroundStyle(
                plan: plan,
                elapsed: elapsedTime,
                effectiveTime: effectiveTime,
                charIndex: 0,
                totalChars: 1,
                onWhiteCanvas: onWhiteCanvas
            )
            MorphGlyphTextView(text: displayWord, typography: typography, style: style, tracking: safeLetterSpacing)
                .modifier(
                    MorphCapabilityTransformModifier(
                        tf: tf,
                        plan: plan,
                        glowColor: glowTintColor,
                        allowGlow: overrideColor == nil,
                        forceVisible: forceVisible
                    )
                )
        } else {
            let chars = Array(displayWord)
            let hasRocket = (plan.entrance?.effectID == .calLancamentoFoguete) && isEntranceActive
            let rocketDur = MorphGlyphTransformEngine.entranceDuration(for: .calLancamentoFoguete)
            let isSlotReel = (plan.entrance?.effectID == .kwRoloCassino) && isEntranceActive
            let slotDur = MorphGlyphTransformEngine.entranceDuration(for: .kwRoloCassino)
            let hasSoapBubbles = (plan.entrance?.effectID == .kwBolhasSabao) && isEntranceActive
            let bubbleDur = MorphGlyphTransformEngine.entranceDuration(for: .kwBolhasSabao)

            HStack(spacing: safeLetterSpacing) {
                ForEach(Array(chars.enumerated()), id: \.offset) { charIdx, ch in
                    let tf = MorphGlyphTransformEngine.evaluate(
                        plan: plan,
                        charIndex: charIdx,
                        totalChars: chars.count,
                        elapsed: elapsedTime
                    )
                    let style: AnyShapeStyle = overrideColor.map(AnyShapeStyle.init) ?? MorphSurfaceResolver.foregroundStyle(
                        plan: plan,
                        elapsed: elapsedTime,
                        effectiveTime: effectiveTime,
                        charIndex: charIdx,
                        totalChars: chars.count,
                        onWhiteCanvas: onWhiteCanvas
                    )
                    let realStr = String(ch)
                    let spinningStr: String? = {
                        guard isSlotReel else { return nil }
                        let reelT = MorphGlyphTransformEngine.charEntranceProgress(
                            elapsed: elapsedTime,
                            charIndex: charIdx,
                            duration: slotDur,
                            delayStep: 0.05
                        )
                        guard reelT > 0.01 && reelT < 0.85 else { return nil }
                        let tick = Int(reelT * 24.0)
                        let reel = Self.slotReelChars
                        let pick = Int(MorphDeterministicHash.mix(plan.wordIndex, tick, charIdx) % UInt64(reel.count))
                        return String(reel[pick])
                    }()

                    // Molde de largura fixo na letra real (evita pulos no Rolo de Cassino) + decorações em background/overlay (0 impacto no layout).
                    Group {
                        if let spinningStr {
                            MorphGlyphTextView(text: realStr, typography: typography, style: style, tracking: 0)
                                .hidden()
                                .overlay {
                                    MorphGlyphTextView(text: spinningStr, typography: typography, style: style, tracking: 0)
                                }
                        } else {
                            MorphGlyphTextView(text: realStr, typography: typography, style: style, tracking: 0)
                        }
                    }
                    .modifier(
                        MorphCapabilityTransformModifier(
                            tf: tf,
                            plan: plan,
                            glowColor: glowTintColor,
                            allowGlow: overrideColor == nil,
                            forceVisible: forceVisible
                        )
                    )
                    .background {
                        if hasRocket && overrideColor == nil {
                            let raw = MorphGlyphTransformEngine.charEntranceProgress(
                                elapsed: elapsedTime,
                                charIndex: charIdx,
                                duration: rocketDur,
                                delayStep: 0.045
                            )
                            let trail = (raw > 0.02 && raw < 0.85) ? (1.0 - raw) : 0.0
                            if trail > 0.02 {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [MorphCRTSafePalette.darkAmber, MorphCRTSafePalette.burntOrange, .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 5, height: CGFloat(trail * 38))
                                    .offset(y: tf.dy + CGFloat(trail * 20))
                                    .blur(radius: 1.5)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .overlay {
                        if hasSoapBubbles && overrideColor == nil {
                            let raw = MorphGlyphTransformEngine.charEntranceProgress(
                                elapsed: elapsedTime,
                                charIndex: charIdx,
                                duration: bubbleDur,
                                delayStep: 0.05
                            )
                            if raw > 0.02 && raw < 0.78 {
                                let p = MorphEasing.smoothstep(raw)
                                let bubbleSize = typography.fontSize * (0.85 + 0.45 * p)
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            colors: [
                                                MorphCRTSafePalette.deepCyan,
                                                MorphCRTSafePalette.deepPink,
                                                MorphCRTSafePalette.darkAmber,
                                                MorphCRTSafePalette.oceanBright,
                                                MorphCRTSafePalette.deepCyan
                                            ],
                                            center: .center
                                        ),
                                        lineWidth: 1.8
                                    )
                                    .frame(width: bubbleSize, height: bubbleSize)
                                    .offset(x: tf.dx, y: tf.dy)
                                    .opacity(0.85)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Modificadores Condicionados por Capacidade (Zero Blur/3D/Skew Mortos nas 90+ Demais Animações)

private struct MorphCapabilityTransformModifier: ViewModifier {
    let tf: MorphGlyphTransform
    let plan: WordAnimationPlan
    let glowColor: Color
    let allowGlow: Bool
    let forceVisible: Bool

    func body(content: Content) -> some View {
        let step1 = applyGlow(to: content)
        let step2 = step1.scaleEffect(x: max(0.05, tf.scaleX), y: max(0.05, tf.scaleY), anchor: tf.anchor)
        let step3 = applySkew(to: step2)
        let step4 = step3.rotationEffect(.degrees(tf.rotationDeg), anchor: tf.anchor)
        let step5 = apply3D(to: step4)
        let step6 = step5.offset(x: tf.dx, y: tf.dy)
        let step7 = applyBlur(to: step6)
        step7.opacity(forceVisible ? 1.0 : min(1.0, max(0.0, tf.opacity)))
    }

    @ViewBuilder
    private func applyGlow<V: View>(to view: V) -> some View {
        if allowGlow && plan.usesGlowModifier {
            view.modifier(MorphGlowModifier(radius: tf.glowRadius, opacity: tf.glowOpacity, glowColor: glowColor))
        } else {
            view
        }
    }

    @ViewBuilder
    private func applySkew<V: View>(to view: V) -> some View {
        if plan.usesSkewModifier {
            view.modifier(MorphSkewEffect(skewXDeg: tf.skewXDeg, skewYDeg: tf.skewYDeg))
        } else {
            view
        }
    }

    @ViewBuilder
    private func apply3D<V: View>(to view: V) -> some View {
        if plan.uses3DRotationModifier {
            view
                .rotation3DEffect(.degrees(tf.rotateXDeg), axis: (x: 1, y: 0, z: 0), anchor: tf.anchor, perspective: 0.55)
                .rotation3DEffect(.degrees(tf.rotateYDeg), axis: (x: 0, y: 1, z: 0), anchor: tf.anchor, perspective: 0.55)
        } else {
            view
        }
    }

    @ViewBuilder
    private func applyBlur<V: View>(to view: V) -> some View {
        if plan.usesBlurModifier {
            view.blur(radius: tf.blur)
        } else {
            view
        }
    }
}

private struct MorphGlowModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double
    let glowColor: Color

    func body(content: Content) -> some View {
        if radius > 0.2 && opacity > 0.01 {
            content
                .shadow(color: glowColor.opacity(opacity), radius: radius, x: 0, y: 0)
                .shadow(color: Color.black.opacity(opacity * 0.22), radius: 1.5, x: 0, y: 0.8)
        } else {
            content
        }
    }
}

struct MorphSplitHalfClip: Shape {
    let isTop: Bool

    func path(in rect: CGRect) -> Path {
        let halfH = rect.height * 0.5
        let sub = isTop
            ? CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: halfH)
            : CGRect(x: rect.minX, y: rect.minY + halfH, width: rect.width, height: halfH)
        return Path(sub)
    }
}

struct MorphDiagonalHalfClip: Shape {
    let isUpper: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isUpper {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.34))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.72))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.72))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.34))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

struct MorphBandClip: Shape {
    let index: Int
    let total: Int

    func path(in rect: CGRect) -> Path {
        let bandH = rect.height / CGFloat(max(1, total))
        let y = rect.minY + CGFloat(index) * bandH
        return Path(CGRect(x: rect.minX, y: y, width: rect.width, height: bandH + 0.5))
    }
}

struct MorphBottomUpFillClip: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let p = CGFloat(min(max(progress, 0), 1))
        let h = rect.height * p
        return Path(CGRect(x: rect.minX, y: rect.maxY - h, width: rect.width, height: h))
    }
}

struct MorphStarburstShape: Shape {
    let points: Int
    let spinDeg: Double

    func path(in rect: CGRect) -> Path {
        let count = max(4, points)
        let cx = rect.midX
        let cy = rect.midY
        let outerRX = rect.width * 0.54
        let outerRY = rect.height * 0.58
        let innerRX = outerRX * 0.72
        let innerRY = outerRY * 0.66
        let baseRad = spinDeg * .pi / 180.0

        var path = Path()
        for i in 0..<(count * 2) {
            let angle = baseRad + Double(i) * .pi / Double(count)
            let rx = i.isMultiple(of: 2) ? outerRX : innerRX
            let ry = i.isMultiple(of: 2) ? outerRY : innerRY
            let pt = CGPoint(x: cx + CGFloat(cos(angle)) * rx, y: cy + CGFloat(sin(angle)) * ry)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Auditoria de Cobertura dos 114 Efeitos (Verificada em Compilação e Execução)

enum MorphRendererSelfCheck {
    enum RenderRoute {
        case typography
        case glyphTransform
        case wordLayer
        case surfaceStyle
        case gpuShaderOrParticle
    }

    static func renderRoute(for id: MorphEffectID) -> RenderRoute {
        switch id {
        case .domTamanhoFonte, .domEspessuraFonte, .tomFonte, .abertEspacamentoLetras:
            return .typography

        case .fragDesabamento,
             .ativBounceInRight, .ativBounce, .ativFlipIn, .ativShakeY, .ativRicocheteLateral,
             .ativCartasZigueZague, .ativPulaPulaElastico, .ativMicroOrbitas, .ativPulsoRitmicoRegular,
             .domLenteInflada,
             .tensTada, .tensGlitch, .tensSqueezeExpand, .tensTensaoContida, .tensOndaSismica,
             .tensDesalinhamentoMecanico, .tensPressaoCrescente, .tensAmeacaLatente, .tensVibracaoPalavra,
             .andSpeedDash, .andRollIn, .andLetargia,
             .calChamaAscendente, .calFogoVivo, .calArrepioGelado, .calTremocaoFrio,
             .luzGlowIn, .luzFlicker, .luzFlickerIn,
             .abertTrackingContract, .abertUltraCondensado, .abertUltraEstirado, .abertPingentesVento,
             .distEngrenagemRelogio, .distArrastoTemporal,
             .volGritoExplosivo, .volPanoramica3D,
             .pesoFlutuacaoZeroG, .pesoAntiGravity, .pesoFlutuarTopo, .pesoMovieCredits,
             .pesoDropIn, .pesoEsmagar, .pesoAfundarComPeso, .pesoFallingLeaves,
             .fluidRigidezMecanica, .fluidWaterDrop, .fluidDerretido, .fluidWave,
             .fluidOndaInclinacao, .fluidDancaTipografica, .fluidOndulacaoVertical, .fluidFluidoViscoso,
             .fluidEspelhoLiquido, .fluidSubmarino, .fluidLuzPiscina,
             .valCascataArcoIris,
             .kwHeartbeatBurst, .kwRespiracaoOrganica, .kwLetreiroNeon, .kwArcoCurvado,
             .kwEscadaDiagonal, .kwRoloCassino, .kwPenduloNewton, .kwArcoFlexivel,
             .kwStopMotion6fps, .kwLinhaDesconstruida, .kwCaosImprevisivel, .kwTontura:
            return .glyphTransform

        case .fragDespedacar, .fragCisao, .fragCorteAoMeio, .fragRachado,
             .calMiragemCalor, .calNevoaAscendente, .calSmokeOut, .calGelidoQuebradico,
             .luzPulseNeon, .luzEscurecimento,
             .distVisaoDupla,
             .volOndasEco, .volEcoDirecional, .volBerroDistorcido,
             .pesoRastroVertical,
             .fluidRefracaoSubmersa,
             .valCaleidoscopioPrismatico, .valImpressaoCMYK, .valSombrasGemeas,
             .valAberracaoCromatica, .valAnaglifo3D, .valCartasCMYOrbita,
             .kwSombraOrbitante, .kwTarjaCensurada, .kwBolhasSabao, .kwEstouroPopArt, .kwTracoParaTinta:
            return .wordLayer

        case .fluidBrilhoMetalico,
             .valFluxoArcoIris, .valLampadaLava, .valPulsoSaturacao,
             .valRotacaoMatiz, .valCameraTermica, .valMercurioLiquido:
            return .surfaceStyle

        case .fragDesintegracao, .fragCorroido, .fragFadeGranulado,
             .calLancamentoFoguete, .calNevascaCristalina,
             .volSolidToOutline:
            return .gpuShaderOrParticle
        }
    }

    static func runSelfCheck() {
        WordEffectResolver.runSelfCheck()

        // Garante que palavras neutras não ativam TimelineView nem layout por caractere nem folga desnecessária
        let plain = WordEffectResolver.resolveWord(word: "casa", wordIndex: 0, scores: ParameterScores(), phraseSeed: 1)
        assert(!plain.hasContinuousTimeAnimation && plain.entrance == nil)
        assert(!plain.needsPerCharLayout(entranceActive: false))
        assert(!plain.usesBlurModifier && !plain.uses3DRotationModifier && !plain.usesSkewModifier && !plain.usesGlowModifier)
        assert(plain.horizontalVisualOverhang == 0 && plain.verticalVisualOverhang.top == 0 && plain.verticalVisualOverhang.bottom == 0)

        let viscous = WordEffectResolver.resolveWord(word: "escorrimento", wordIndex: 0, scores: ParameterScores(), phraseSeed: 1)
        assert(viscous.verticalVisualOverhang.bottom > 10, "Fluido Viscoso deve reservar folga inferior")
        let chaos = WordEffectResolver.resolveWord(word: "caótico", wordIndex: 0, scores: ParameterScores(), phraseSeed: 1)
        assert(chaos.horizontalVisualOverhang >= 10, "Caos Imprevisível deve reservar folga horizontal")

        let sampleTimes: [Double] = [0.0, 0.2, 0.5, 0.85, 1.0, 2.4]
        for spec in MorphEffectCatalog.allSpecs {
            _ = renderRoute(for: spec.id)

            for t in sampleTimes {
                switch spec.channel {
                case .typography:
                    let tf = MorphGlyphTransformEngine.evaluateStatic(effectID: spec.id, intensity: 1.0, charIndex: 2, totalChars: 6)
                    assert(tf.isFinite && tf.scaleY <= 1.48, "Estático inválido em \(spec.id)")

                case .entrance:
                    let tf = MorphGlyphTransformEngine.evaluateEntrance(effectID: spec.id, intensity: 1.0, charIndex: 2, totalChars: 6, wordIndex: 1, elapsed: t)
                    assert(tf.isFinite, "Entrada não finita em \(spec.id) t=\(t)")
                    if t >= 2.0 {
                        assert(tf.opacity >= 0.99, "Entrada \(spec.id) terminou invisível (opacity=\(tf.opacity))")
                    }

                case .continuous:
                    let tf = MorphGlyphTransformEngine.evaluateContinuous(effectID: spec.id, intensity: 1.0, charIndex: 2, totalChars: 6, wordIndex: 1, time: t).clampedForSteadyState()
                    assert(tf.isFinite, "Contínuo não finito em \(spec.id) t=\(t)")
                    assert(tf.opacity >= 0.55, "Contínuo \(spec.id) ficou invisível (opacity=\(tf.opacity))")
                    assert(tf.scaleY <= 1.48 && abs(tf.dy) <= 24.0, "Contínuo \(spec.id) violou teto CRT")

                case .surface, .overlay:
                    break
                }
            }
        }

        for i in 0..<100 {
            let c = MorphCRTSafePalette.safeSpectrumColor(phase: Double(i) / 100.0)
            let resolved = c.resolve(in: EnvironmentValues())
            assert(resolved.red.isFinite && resolved.green.isFinite && resolved.blue.isFinite)
        }
    }
}
