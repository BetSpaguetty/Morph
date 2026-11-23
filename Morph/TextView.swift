import SwiftUI

struct TextView: View {
    @Environment(\.dismiss) private var dismiss

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
    @State private var cachedWordScores: [ParameterScores] = []
    @State private var tarefaInterpretacao: Task<Void, Never>?

    private var trimmedText: String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasText: Bool { !trimmedText.isEmpty }

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

            VStack(spacing: 0) {
                RetroHeaderBar(
                    metrics: metrics,
                    onHome: sairParaInicio,
                    onSettings: abrirConfiguracoes,
                    onTapEmptySpace: { scrollController.resignFocus() }
                )

                ZStack(alignment: .bottomTrailing) {
                    canvasArea(metrics: metrics)
                    statusOverlay(metrics: metrics)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
        .sheet(isPresented: $showingSettingsSheet, onDismiss: {
            suppressKeyboardTrigger = false
        }) {
            SettingsSheetView(
                interpretador: interpretador,
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
        }
    }

    // MARK: - Área Central (Editor com Caret SVG + Scrollbar Condicional vs Palco de Animações)

    @ViewBuilder
    private func canvasArea(metrics: RetroFrameMetrics) -> some View {
        if isEditingText || interpretador.lote.isEmpty || !hasText {
            ZStack(alignment: .trailing) {
                RetroTextEditor(
                    text: $texto,
                    metrics: metrics,
                    scrollController: scrollController,
                    focusRequestID: focusRequestID,
                    useSystemKeyboard: true,
                    onKeyboardDismissed: aoAbaixarTeclado
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
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let elapsed = context.date.timeIntervalSince(stageReferenceDate)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            Spacer(minLength: max(24, geo.size.height * 0.14))

                            MorphWordsCanvasView(
                                tokens: wordTokens,
                                scope: .wholePhrase,
                                selectedWordIndex: .constant(0),
                                elapsedTime: elapsed,
                                isAndamentoPaused: false,
                                isolatedParameter: nil,
                                onWhiteCanvas: true,
                                onWordTap: { _ in voltarParaEdicao() },
                                scoresProvider: { idx in effectiveScores(for: idx) }
                            )
                            .padding(.horizontal, 28)
                            .padding(.vertical, 60)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height * 0.45)

                            Spacer(minLength: 40)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { voltarParaEdicao() }
                }
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
            .padding(.horizontal, 20 * scale)
            .padding(.bottom, 14 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Navegação, Teclado e Execução da IA

    private func sairParaInicio() {
        isDismissingScreen = true
        suppressKeyboardTrigger = true
        tarefaInterpretacao?.cancel()
        scrollController.resignFocus()
        dismiss()
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

    /// Ponto único de disparo ao encerrar o teclado (hoje teclado do sistema; futuramente teclado virtual na TV).
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

    private func recomputarScoresPorPalavra() {
        cachedWordScores = interpretador.wordParameterScores(tokens: wordTokens, filtros: filtros)
    }

    private func effectiveScores(for wordIndex: Int) -> ParameterScores {
        (wordIndex >= 0 && wordIndex < cachedWordScores.count) ? cachedWordScores[wordIndex] : activeScores
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
                    stageReferenceDate = .now
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isEditingText = false
                    }
                }
            }
        }
    }
}

#Preview {
    TextView()
}
