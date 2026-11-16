import SwiftUI

enum AutomatedAnimationScope: String, CaseIterable, Identifiable {
    case contextualPerWord = "Por Palavra (IA)"
    case wholePhrase = "Frase Inteira"
    case specificWord = "Palavra Manual"

    var id: String { rawValue }

    var tituloCurto: String {
        switch self {
        case .contextualPerWord: return "Palavras"
        case .wholePhrase: return "Frase"
        case .specificWord: return "Manual"
        }
    }
}

struct TextView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var interpretador = Interpretador()
    @State private var texto: String = ""
    @State private var modo: ModoChamadas = .umaChamada
    @State private var comEvidencia: Bool = true
    @State private var deterministico: Bool = false
    @State private var filtros = Filtros()

    @State private var isEditingText: Bool = true
    @State private var autoInterpretOnPause: Bool = true
    @State private var showingSettingsSheet: Bool = false
    @State private var showingScoresSummary: Bool = false

    @State private var scopeMode: AutomatedAnimationScope = .contextualPerWord
    @State private var selectedWordIndex: Int = 0
    @State private var inspectedWordIndex: Int? = nil
    @State private var stageReferenceDate: Date = .now
    @State private var cachedWordScores: [ParameterScores] = []

    @State private var tarefaInterpretacao: Task<Void, Never>?
    @State private var tarefaAutoPause: Task<Void, Never>?
    @FocusState private var editorFocused: Bool

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

    private var hasText: Bool {
        !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasInterpretedCurrentText: Bool {
        !interpretador.lote.isEmpty && interpretador.textoDoLote == texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack(alignment: .bottom) {
                canvasArea
                bottomControls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
        .containerBackground(.clear, for: .navigation)
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsSheetView(
                interpretador: interpretador,
                texto: $texto,
                modo: $modo,
                comEvidencia: $comEvidencia,
                deterministico: $deterministico,
                filtros: $filtros,
                autoInterpretOnPause: $autoInterpretOnPause,
                onTriggerRun: { reps in executarInterpretacao(repeticoes: reps) },
                onSelectExample: { novoTexto in selecionarExemplo(novoTexto) }
            )
        }
        .onChange(of: texto) { oldValue, newValue in
            inspectedWordIndex = nil
            recomputarScoresPorPalavra()
            agendarAutoInterpretacao(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: interpretador.lote.count) { _, _ in
            inspectedWordIndex = nil
            recomputarScoresPorPalavra()
        }
        .onChange(of: filtros.limiar) { _, _ in recomputarScoresPorPalavra() }
        .onChange(of: filtros.zerarContradicoes) { _, _ in recomputarScoresPorPalavra() }
        .onChange(of: filtros.zerarNaoLiterais) { _, _ in recomputarScoresPorPalavra() }
    }

    // MARK: - Barra Superior

    private var topBar: some View {
        HStack(spacing: 10) {
            iconButton(systemName: "house.fill", label: "Início") {
                dismiss()
            }

            Spacer()

            if !texto.isEmpty {
                Button(role: .destructive, action: apagarTudo) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(width: 38, height: 38)
                        .background(Color.red.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apagar texto")
            }

            iconButton(systemName: "gearshape.fill", label: "Ajustes") {
                showingSettingsSheet = true
            }
        }
        // Folga superior/lateral para não colidir com os cantos arredondados da moldura da TV
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 6)
    }

    private func iconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Área Central (Editor de Texto vs Palco de Animações)

    private var canvasArea: some View {
        GeometryReader { geo in
            if isEditingText || interpretador.lote.isEmpty || !hasText {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $texto)
                        .focused($editorFocused)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(.black.opacity(0.88))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 28)
                        .padding(.top, 10)
                        .padding(.bottom, 120)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Button("Apagar tudo", role: .destructive, action: apagarTudo)
                                    .font(FontRegistrationManager.chicago(size: 13))
                                    .disabled(texto.isEmpty)
                                Spacer()
                                Toggle("Auto-interpretar", isOn: $autoInterpretOnPause)
                                    .toggleStyle(.button)
                                    .font(FontRegistrationManager.chicago(size: 12))
                                Button {
                                    executarInterpretacao(repeticoes: 1)
                                } label: {
                                    Label("Concluir e Animar", systemImage: "sparkles")
                                        .font(FontRegistrationManager.chicago(size: 13))
                                }
                                .disabled(!hasText || interpretador.executando || interpretador.indisponibilidade != nil)
                            }
                        }

                    if texto.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clique aqui para escrever seu texto...")
                                .font(FontRegistrationManager.chicago(size: 22))
                                .foregroundStyle(.black.opacity(0.35))
                            Text("A IA do Gemini interpretará os parâmetros da frase e animará cada palavra.")
                                .font(FontRegistrationManager.chicago(size: 13))
                                .foregroundStyle(.black.opacity(0.40))
                        }
                        .padding(.horizontal, 33)
                        .padding(.top, 18)
                        .allowsHitTesting(false)
                    }
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let elapsed = context.date.timeIntervalSince(stageReferenceDate)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            Spacer(minLength: max(24, geo.size.height * 0.14))

                            MorphWordsCanvasView(
                                tokens: wordTokens,
                                scope: canvasScope,
                                selectedWordIndex: bindingWordIndex,
                                elapsedTime: elapsed,
                                isAndamentoPaused: false,
                                isolatedParameter: nil,
                                onWhiteCanvas: true,
                                onWordTap: { idx in
                                    withAnimation(.snappy(duration: 0.2)) {
                                        switch scopeMode {
                                        case .specificWord: selectedWordIndex = idx
                                        case .contextualPerWord: inspectedWordIndex = (inspectedWordIndex == idx) ? nil : idx
                                        case .wholePhrase: break
                                        }
                                    }
                                },
                                scoresProvider: { idx in effectiveScores(for: idx) }
                            )
                            .padding(.horizontal, 28)
                            .padding(.vertical, 80)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height * 0.45)

                            Spacer(minLength: 110)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
        }
    }

    private var canvasScope: ModificationScope {
        switch scopeMode {
        case .wholePhrase: return .wholePhrase
        case .specificWord: return .specificWord
        case .contextualPerWord: return inspectedWordIndex == nil ? .wholePhrase : .specificWord
        }
    }

    private var bindingWordIndex: Binding<Int> {
        Binding(
            get: {
                switch scopeMode {
                case .specificWord: return selectedWordIndex
                case .contextualPerWord: return inspectedWordIndex ?? 0
                case .wholePhrase: return 0
                }
            },
            set: { nova in
                if scopeMode == .specificWord {
                    selectedWordIndex = nova
                } else if scopeMode == .contextualPerWord {
                    inspectedWordIndex = nova
                }
            }
        )
    }

    // MARK: - Controles Inferiores Flutuantes

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if let erro = interpretador.erro ?? interpretador.indisponibilidade {
                bannerAviso(erro)
            }

            if interpretador.executando {
                barraProgresso
            }

            if !interpretador.lote.isEmpty && hasText {
                painelResumoEAcoes
            } else if !interpretador.executando {
                HStack {
                    Spacer()
                    Button {
                        executarInterpretacao(repeticoes: 1)
                    } label: {
                        Label("Interpretar", systemImage: "wand.and.stars")
                            .font(FontRegistrationManager.chicago(size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 42)
                            .background(
                                (hasText && interpretador.indisponibilidade == nil) ? Color.accentColor : Color.gray.opacity(0.45),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasText || interpretador.indisponibilidade != nil)
                }
                .padding(.horizontal, 28)
            }
        }
        .padding(.bottom, 22)
    }

    private func bannerAviso(_ mensagem: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(mensagem)
                .font(FontRegistrationManager.chicago(size: 12))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(3)
            Spacer(minLength: 6)
            Button("Ajustes") { showingSettingsSheet = true }
                .font(FontRegistrationManager.chicago(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.22), in: Capsule())
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 28)
    }

    private var barraProgresso: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.accentColor)
            Text(interpretador.progresso.isEmpty ? "Interpretando semântica do texto..." : interpretador.progresso)
                .font(FontRegistrationManager.chicago(size: 12))
                .foregroundStyle(.black)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Cancelar") { tarefaInterpretacao?.cancel() }
                .font(FontRegistrationManager.chicago(size: 12))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.white.opacity(0.95)).shadow(color: .black.opacity(0.12), radius: 8, y: 3))
        .padding(.horizontal, 28)
    }

    private var painelResumoEAcoes: some View {
        VStack(alignment: .leading, spacing: 10) {
            if scopeMode == .contextualPerWord,
               !isEditingText,
               let idx = inspectedWordIndex,
               idx >= 0, idx < wordTokens.count {
                inspecaoPalavraView(idx: idx)
            }

            if showingScoresSummary {
                resumoParametrosAtivosView
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy) { showingScoresSummary.toggle() }
                } label: {
                    let activeCount = MorphParameter.allCases.filter { activeScores[$0] != 0 }.count
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                        Text("\(activeCount) ativos")
                        if let ultima = interpretador.lote.last {
                            Text("· \(String(format: "%.2fs", ultima.segundos)) · \(ultima.tokensEntrada + ultima.tokensSaida) tok")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: showingScoresSummary ? "chevron.down" : "chevron.up")
                            .font(.caption2)
                    }
                    .font(FontRegistrationManager.chicago(size: 12))
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 6)

                if !isEditingText && wordTokens.count > 1 {
                    scopeSelector
                }
            }

            Divider().overlay(Color.black.opacity(0.08))

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingText.toggle()
                        editorFocused = isEditingText
                    }
                } label: {
                    Label(isEditingText ? "Ver Animação" : "Editar Texto", systemImage: isEditingText ? "play.fill" : "pencil")
                        .font(FontRegistrationManager.chicago(size: 13))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.black.opacity(0.06), in: Capsule())
                        .foregroundStyle(.black.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button {
                    if interpretador.executando {
                        tarefaInterpretacao?.cancel()
                    } else {
                        executarInterpretacao(repeticoes: 1)
                    }
                } label: {
                    Label(
                        hasInterpretedCurrentText ? "Interpretar" : "Atualizar IA",
                        systemImage: hasInterpretedCurrentText ? "wand.and.stars" : "arrow.triangle.2.circlepath"
                    )
                    .font(FontRegistrationManager.chicago(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(
                        interpretador.indisponibilidade == nil ? Color.accentColor : Color.gray.opacity(0.45),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(interpretador.indisponibilidade != nil && !interpretador.executando)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        )
        .padding(.horizontal, 28)
    }

    private var scopeSelector: some View {
        HStack(spacing: 2) {
            ForEach(AutomatedAnimationScope.allCases) { option in
                let selected = scopeMode == option
                Button {
                    scopeMode = option
                } label: {
                    Text(option.tituloCurto)
                        .font(FontRegistrationManager.chicago(size: 11))
                        .foregroundStyle(selected ? .black : .black.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(selected ? Color.white : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.08), in: Capsule())
    }

    private func inspecaoPalavraView(idx: Int) -> some View {
        let wordScores = effectiveScores(for: idx)
        let wordNonZero = MorphParameter.allCases.filter { wordScores[$0] != 0 }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Palavra “\(wordTokens[idx])”:")
                    .font(FontRegistrationManager.chicago(size: 12))
                    .foregroundStyle(.black)
                Spacer()
                Button {
                    withAnimation(.snappy) { inspectedWordIndex = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if wordNonZero.isEmpty {
                        Text("Sem animação própria nesta palavra (0)")
                            .font(FontRegistrationManager.chicago(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(wordNonZero) { param in
                            let val = wordScores[param]
                            HStack(spacing: 4) {
                                Image(systemName: param.safeIcon).font(.system(size: 10))
                                Text("\(param.rawValue): \(param.formattedScore(val))")
                                    .font(FontRegistrationManager.chicago(size: 11))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.18), in: Capsule())
                            .foregroundStyle(Color(red: 0.0, green: 0.45, blue: 0.68))
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var resumoParametrosAtivosView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let nonZero = MorphParameter.allCases.filter { activeScores[$0] != 0 }
                if nonZero.isEmpty {
                    Text("Todos os parâmetros neutros (0)")
                        .font(FontRegistrationManager.chicago(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nonZero) { param in
                        let val = activeScores[param]
                        let ancorasTexto: String = {
                            guard scopeMode == .contextualPerWord,
                                  let res = interpretador.lote.last?.resultados[param.catalogoId],
                                  !res.ancoras.isEmpty else { return "" }
                            let trechos = res.ancoras.map { a in
                                res.ancoras.count > 1
                                    ? "“\(a.trecho)”(\(a.nivel > 0 ? "+\(a.nivel)" : "\(a.nivel)"))"
                                    : "“\(a.trecho)”"
                            }
                            return " · " + trechos.joined(separator: ", ")
                        }()
                        HStack(spacing: 4) {
                            Image(systemName: param.safeIcon).font(.system(size: 10))
                            Text("\(param.rawValue): \(param.formattedScore(val))\(ancorasTexto)")
                                .font(FontRegistrationManager.chicago(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Lógica de Scores e Execução

    private func recomputarScoresPorPalavra() {
        cachedWordScores = interpretador.wordParameterScores(tokens: wordTokens, filtros: filtros)
    }

    private func effectiveScores(for wordIndex: Int) -> ParameterScores {
        switch scopeMode {
        case .contextualPerWord:
            return (wordIndex >= 0 && wordIndex < cachedWordScores.count) ? cachedWordScores[wordIndex] : activeScores
        case .wholePhrase:
            return activeScores
        case .specificWord:
            let safeIdx = min(max(0, selectedWordIndex), max(0, wordTokens.count - 1))
            return wordIndex == safeIdx ? activeScores : ParameterScores()
        }
    }

    private func agendarAutoInterpretacao(oldValue: String, newValue: String) {
        tarefaAutoPause?.cancel()
        guard autoInterpretOnPause else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, newValue != oldValue else { return }

        tarefaAutoPause = Task {
            try? await Task.sleep(for: .milliseconds(2200))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if hasText && !interpretador.executando && interpretador.indisponibilidade == nil && !hasInterpretedCurrentText {
                    executarInterpretacao(repeticoes: 1)
                }
            }
        }
    }

    private func apagarTudo() {
        tarefaAutoPause?.cancel()
        tarefaInterpretacao?.cancel()
        texto = ""
        isEditingText = true
        editorFocused = true
    }

    private func selecionarExemplo(_ novoTexto: String) {
        tarefaAutoPause?.cancel()
        texto = novoTexto
        executarInterpretacao(repeticoes: 1)
    }

    private func executarInterpretacao(repeticoes: Int) {
        guard hasText, interpretador.indisponibilidade == nil else { return }
        tarefaAutoPause?.cancel()
        editorFocused = false
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
                if !interpretador.lote.isEmpty {
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
