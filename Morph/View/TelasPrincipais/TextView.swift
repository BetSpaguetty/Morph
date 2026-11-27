import SwiftUI

struct TextView: View {
    @Environment(MorphRouter.self) private var router
    @Environment(CRTBarrelConfig.self) private var crtConfig
    @Environment(MorphKeyboardVisualConfig.self) private var keyboardConfig
    @Environment(CRTTextInputBridge.self) private var textInputBridge

    @State private var interpretador = Interpretador()
    @State private var scrollController = RetroScrollController()
    @State private var texto: String = ""
    @State private var modo: ModoChamadas = .umaChamada
    @State private var comEvidencia: Bool = true
    @State private var deterministico: Bool = false
    @State private var filtros = Filtros()

    @State private var isEditingText: Bool = true
    @State private var showingSettingsSheet: Bool = false
    @State private var isDismissingScreen: Bool = false
    @State private var suppressKeyboardTrigger: Bool = false
    @State private var focusRequestID: Int = 0

    @State private var stageReferenceDate: Date = .now
    @State private var phraseSeed: Int = 1
    @State private var cachedWordScores: [ParameterScores] = []
    @State private var cachedWordPlans: [WordAnimationPlan] = []
    @State private var cachedWordSpacings: [CGFloat] = []
    @State private var cachedLayoutKey: Int = 0
    @State private var tarefaInterpretacao: Task<Void, Never>?

    private var trimmedText: String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasText: Bool { !trimmedText.isEmpty }

    private var isShowingEditor: Bool {
        isEditingText || interpretador.lote.isEmpty || !hasText
    }

    private var isVirtualKeyboardVisible: Bool {
        isShowingEditor && scrollController.isFocused && !isDismissingScreen
    }

    private var hasInterpretedCurrentText: Bool {
        !interpretador.lote.isEmpty && interpretador.textoDoLote == trimmedText
    }

    private var activeScores: ParameterScores {
        interpretador.parameterScores(filtros: filtros)
    }

    private var wordTokens: [String] {
        let split = texto
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { !$0.isEmpty }
        return split.isEmpty ? ["Morph"] : split
    }

    var body: some View {
        GeometryReader { containerGeo in
            let metrics = RetroFrameMetrics(containerSize: containerGeo.size)
            let bodySize = CGSize(
                width: metrics.frameSize.width,
                height: max(120, metrics.frameSize.height - metrics.headerHeight)
            )

            VStack(spacing: 0) {
                RetroHeaderBar(
                    metrics: metrics,
                    onHome: sairParaInicio,
                    onSettings: abrirConfiguracoes,
                    onTapEmptySpace: { scrollController.resignFocus() }
                )
                .zIndex(1)

                ZStack(alignment: .bottomTrailing) {
                    canvasArea(metrics: metrics)
                    statusOverlay(metrics: metrics)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)

                if isVirtualKeyboardVisible {
                    MorphVirtualKeyboardView(
                        bodySize: bodySize,
                        frameMetrics: metrics,
                        visualConfig: keyboardConfig,
                        startsCapitalized: texto.isEmpty,
                        onInsert: { scrollController.insertText($0) },
                        onDeleteBackward: { scrollController.deleteBackward() },
                        onDismiss: { scrollController.resignFocus() }
                    )
                    .zIndex(2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isVirtualKeyboardVisible)
            .clipShape(RoundedRectangle(cornerSize: metrics.cornerSize, style: .circular))
            .overlay(
                RetroWindowFrameShape(metrics: metrics)
                    .stroke(
                        RetroTerminalStyle.ink,
                        style: StrokeStyle(
                            lineWidth: metrics.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .allowsHitTesting(false)
            )
            .padding(.horizontal, metrics.horizontalOuterPadding)
            .padding(.vertical, metrics.verticalOuterPadding)
            .onAppear { syncTextInputSession(metrics: metrics) }
            .onChange(of: metrics) { _, newMetrics in syncTextInputSession(metrics: newMetrics) }
            .onChange(of: isShowingEditor) { _, _ in syncTextInputSession(metrics: metrics) }
            .onChange(of: scrollController.isFocused) { _, _ in syncTextInputSession(metrics: metrics) }
            .onChange(of: isVirtualKeyboardVisible) { _, visible in
                if !visible && textInputBridge.keyboardStartYInCRT != -1.0 {
                    textInputBridge.keyboardStartYInCRT = -1.0
                }
            }
            .onChange(of: focusRequestID) { _, _ in syncTextInputSession(metrics: metrics) }
        }
        .sheet(isPresented: $showingSettingsSheet, onDismiss: {
            suppressKeyboardTrigger = false
        }) {
            SettingsSheetView(
                interpretador: interpretador,
                crtConfig: crtConfig,
                keyboardConfig: keyboardConfig,
                texto: $texto,
                modo: $modo,
                comEvidencia: $comEvidencia,
                deterministico: $deterministico,
                filtros: $filtros,
                onTriggerRun: { reps in executarInterpretacao(repeticoes: reps) },
                onSelectExample: { novoTexto in selecionarExemplo(novoTexto) }
            )
        }
        .onChange(of: texto) { _, _ in recomputarScoresPorPalavra() }
        .onChange(of: interpretador.lote.count) { _, _ in recomputarScoresPorPalavra() }
        .onChange(of: filtros.limiar) { _, _ in recomputarScoresPorPalavra() }
        .onChange(of: filtros.zerarContradicoes) { _, _ in recomputarScoresPorPalavra() }
        .onChange(of: filtros.zerarNaoLiterais) { _, _ in recomputarScoresPorPalavra() }
        .onDisappear {
            isDismissingScreen = true
            tarefaInterpretacao?.cancel()
            textInputBridge.session = nil
            textInputBridge.excludedFramesInCRT.removeAll()
            textInputBridge.keyboardStartYInCRT = -1.0
        }
    }

    // MARK: - Área Central (Canvas Curvado com Caret SVG + Scrollbar Condicional vs Palco de Animações)

    @ViewBuilder
    private func canvasArea(metrics: RetroFrameMetrics) -> some View {
        if isShowingEditor {
            ZStack(alignment: .trailing) {
                RetroTextCanvasView(
                    scrollController: scrollController,
                    metrics: metrics,
                    text: texto
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                RetroScrollbarView(
                    metrics: metrics,
                    controller: scrollController
                )
            }
            .animation(.easeInOut(duration: 0.18), value: scrollController.metrics.needsScroll)
        } else {
            GeometryReader { geo in
                let plans = activeStagePlans
                let spacings = cachedWordSpacings.count == plans.count
                    ? cachedWordSpacings
                    : MorphWordsCanvasView.computeWordSpacings(plans: plans)
                let layoutKey = cachedWordPlans.count == plans.count
                    ? cachedLayoutKey
                    : MorphWordsCanvasView.computeLayoutKey(plans: plans)

                MorphStageScrollContainer(
                    viewportSize: geo.size,
                    resetTrigger: stageReferenceDate,
                    onTap: voltarParaEdicao,
                    content: MorphWordsCanvasView(
                        plans: plans,
                        wordSpacings: spacings,
                        layoutKey: layoutKey,
                        scope: .wholePhrase,
                        selectedWordIndex: 0,
                        stageReferenceDate: stageReferenceDate,
                        isAndamentoPaused: false,
                        onWhiteCanvas: true,
                        maxAvailableWidth: max(180, geo.size.width - 56)
                    )
                    .equatable()
                )
            }
        }
    }

    // MARK: - Feedback Minimalista (Processamento e Aviso de Erro/Chave)

    @ViewBuilder
    private func statusOverlay(metrics: RetroFrameMetrics) -> some View {
        let scale = metrics.headerScale

        if interpretador.executando {
            RetroProcessingIndicator(scale: scale)
                .padding(.trailing, scrollController.metrics.needsScroll ? 58 * scale : 20 * scale)
                .padding(.bottom, 16 * scale)
                .transition(.opacity)
        } else if let erro = interpretador.erro ?? interpretador.indisponibilidade {
            HStack(spacing: 8 * scale) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13 * scale, weight: .semibold))
                Text(erro)
                    .font(.system(size: 12 * scale, weight: .medium, design: .monospaced))
                    .lineLimit(2)
                Button("Ajustes") { abrirConfiguracoes() }
                    .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
                    .underline()
                    .crtHitAdjusted()
                    .buttonStyle(.plain)
            }
            .foregroundStyle(RetroTerminalStyle.ink)
            .padding(.horizontal, 12 * scale)
            .padding(.vertical, 8 * scale)
            .background(
                RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                    .fill(Color(red: 238.0 / 255, green: 230.0 / 255, blue: 184.0 / 255).opacity(0.92))
                    .stroke(RetroTerminalStyle.ink.opacity(0.65), lineWidth: max(1.5, 2 * scale))
            )
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(CRTCoordinateSpace.name))
            } action: { frame in
                textInputBridge.setExcludedFrame(frame, for: "statusBanner")
            }
            .onDisappear {
                textInputBridge.setExcludedFrame(.zero, for: "statusBanner")
            }
            .padding(.horizontal, 20 * scale)
            .padding(.bottom, 14 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sessão de Input, Navegação, Teclado e Execução da IA

    private func syncTextInputSession(metrics: RetroFrameMetrics) {
        if isShowingEditor && !isDismissingScreen {
            textInputBridge.session = CRTTextInputBridge.Session(
                text: $texto,
                metrics: metrics,
                scrollController: scrollController,
                focusRequestID: focusRequestID,
                useSystemKeyboard: false,
                isVirtualKeyboardVisible: isVirtualKeyboardVisible,
                onKeyboardDismissed: aoAbaixarTeclado
            )
        } else {
            textInputBridge.session = nil
        }
    }

    private func sairParaInicio() {
        isDismissingScreen = true
        suppressKeyboardTrigger = true
        tarefaInterpretacao?.cancel()
        scrollController.resignFocus()
        textInputBridge.session = nil
        router.pop()
    }

    private func abrirConfiguracoes() {
        suppressKeyboardTrigger = true
        scrollController.resignFocus()
        showingSettingsSheet = true
    }

    private func voltarParaEdicao() {
        focusRequestID += 1
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditingText = true
        }
    }

    /// Ponto único de disparo ao encerrar o teclado virtual interno na TV.
    private func aoAbaixarTeclado() {
        guard !isDismissingScreen, !suppressKeyboardTrigger, !showingSettingsSheet else { return }
        guard hasText else { return }

        if hasInterpretedCurrentText {
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditingText = false
            }
            return
        }

        guard !interpretador.executando, interpretador.indisponibilidade == nil else { return }
        executarInterpretacao(repeticoes: 1)
    }

    private var activeStagePlans: [WordAnimationPlan] {
        let tokens = wordTokens
        if cachedWordPlans.count == tokens.count {
            return cachedWordPlans
        }
        return WordEffectResolver.resolvePhrase(
            tokens: tokens,
            scoresPerWord: Array(repeating: activeScores, count: tokens.count),
            phraseSeed: phraseSeed
        )
    }

    private func recomputarScoresPorPalavra() {
        let tokens = wordTokens
        let scores = interpretador.wordParameterScores(tokens: tokens, filtros: filtros)
        let plans = WordEffectResolver.resolvePhrase(
            tokens: tokens,
            scoresPerWord: scores,
            phraseSeed: phraseSeed
        )
        cachedWordScores = scores
        cachedWordPlans = plans
        cachedWordSpacings = MorphWordsCanvasView.computeWordSpacings(plans: plans)
        cachedLayoutKey = MorphWordsCanvasView.computeLayoutKey(plans: plans)
    }

    private func selecionarExemplo(_ novoTexto: String) {
        texto = novoTexto
        executarInterpretacao(repeticoes: 1)
    }

    private func executarInterpretacao(repeticoes: Int) {
        guard hasText, interpretador.indisponibilidade == nil else { return }
        suppressKeyboardTrigger = true
        scrollController.resignFocus()
        suppressKeyboardTrigger = false
        tarefaInterpretacao?.cancel()

        let textoAlvo = texto
        tarefaInterpretacao = Task {
            await interpretador.rodar(
                texto: textoAlvo,
                repeticoes: repeticoes,
                modo: modo,
                comEvidencia: comEvidencia,
                deterministico: deterministico
            )
            await MainActor.run {
                if !interpretador.lote.isEmpty && !isDismissingScreen {
                    // Opção A: gera novo seed 1x por interpretação concluída e congela os planos fora dos 60fps.
                    phraseSeed = Int.random(in: 1...Int.max)
                    recomputarScoresPorPalavra()
                    stageReferenceDate = .now
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isEditingText = false
                    }
                }
            }
        }
    }
}

// MARK: - Contêiner de Scroll Isolado (Mudanças de Scroll NÃO Reavaliam TextView nem MorphWordsCanvasView)

private struct MorphStageScrollContainer<Content: View>: View {
    let viewportSize: CGSize
    let resetTrigger: Date
    let onTap: () -> Void
    let content: Content

    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat? = nil
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let maxScroll = max(0, contentHeight - viewportSize.height)
        let clampedOffset = min(maxScroll, max(0, scrollOffset))

        ZStack(alignment: .top) {
            Color.clear

            VStack(spacing: 24) {
                Spacer(minLength: max(24, viewportSize.height * 0.14))

                content
                    .padding(.horizontal, 28)
                    .padding(.vertical, 60)
                    .frame(maxWidth: .infinity, minHeight: viewportSize.height * 0.45)

                Spacer(minLength: 40)
            }
            .frame(minHeight: viewportSize.height)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if abs(contentHeight - height) > 0.5 {
                    contentHeight = height
                }
            }
            .offset(y: -clampedOffset)
        }
        .frame(width: viewportSize.width, height: viewportSize.height, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard maxScroll > 0 else { return }
                    if dragStartOffset == nil {
                        dragStartOffset = clampedOffset
                    }
                    let base = dragStartOffset ?? 0
                    scrollOffset = min(maxScroll, max(0, base - value.translation.height))
                }
                .onEnded { _ in
                    dragStartOffset = nil
                }
        )
        .onChange(of: resetTrigger) { _, _ in
            scrollOffset = 0
            dragStartOffset = nil
        }
    }
}

#Preview {
    TextView()
        .environment(MorphRouter())
        .environment(CRTBarrelConfig())
        .environment(MorphKeyboardVisualConfig())
        .environment(CRTTextInputBridge())
}
