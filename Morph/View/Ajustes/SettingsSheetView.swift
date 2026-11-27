import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case teclado = "Teclado"
    case telaCRT = "Tela CRT"
    case som = "Som"
    case ia = "IA"
    case analise = "Análise"

    var id: String { rawValue }
}

struct SettingsSheetView: View {
    @AppStorage("morph.sineToneEnabled") private var sineToneEnabled = true
    @Bindable var interpretador: Interpretador
    @Bindable var crtConfig: CRTBarrelConfig
    @Bindable var keyboardConfig: MorphKeyboardVisualConfig
    @Binding var texto: String
    @Binding var modo: ModoChamadas
    @Binding var estrutura: EstruturaResposta
    @Binding var comEvidencia: Bool
    @Binding var deterministico: Bool
    @Binding var filtros: Filtros

    var onTriggerRun: (Int) -> Void
    var onSelectExample: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var abaSelecionada: SettingsTab = .teclado
    @State private var referencia: ConfiguracaoResultado?
    @State private var latenciaAberta = true
    @State private var comparativoAberto = true
    @State private var comparacaoAberta = true
    @State private var exemplosAberto = false

    private var statusColor: Color {
        if interpretador.executando { return .orange }
        if interpretador.erro != nil { return .red }
        if interpretador.indisponibilidade != nil { return .orange }
        return .green
    }

    private var statusTexto: String {
        if interpretador.executando { return "\(interpretador.provedor.tituloCurto) · Interpretando..." }
        if interpretador.erro != nil { return "\(interpretador.provedor.tituloCurto) · Erro na requisição" }
        if interpretador.indisponibilidade != nil { return "\(interpretador.provedor.tituloCurto) · Chave pendente" }
        return "\(interpretador.provedor.tituloCurto) · Pronto"
    }

    private var descricaoDoModo: String {
        switch modo {
        case .umaChamada:
            return "Um schema com os 15 parâmetros. Menos chamadas, mas prompt maior e saída mais longa."
        case .porGrupo:
            return "Três schemas de cinco parâmetros. Equilíbrio entre contexto e tamanho da saída."
        case .porParametro:
            return "Quinze schemas de um parâmetro. Instruções mais curtas por chamada, porém com 15 idas ao modelo."
        }
    }

    private var promptsVisiveis: [(String, String)] {
        let evidencias = estrutura == .partes ? true : comEvidencia
        switch modo {
        case .umaChamada:
            return [("Chamada única (15 parâmetros; pode ser compactada automaticamente)",
                     Instrucoes.sistema(defs: Catalogo.todos, comEvidencia: evidencias,
                                        estrutura: estrutura))]
        case .porGrupo:
            return GrupoChamada.allCases.map { g in
                (g.titulo, Instrucoes.sistema(defs: Catalogo.definicoes(do: g),
                                              comEvidencia: evidencias,
                                              estrutura: estrutura))
            }
        case .porParametro:
            let d = Catalogo.todos[0]
            return [("Exemplo: chamada de \(d.nome) (as outras seguem o mesmo molde)",
                     Instrucoes.sistema(defs: [d], comEvidencia: evidencias,
                                        estrutura: estrutura))]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Categoria", selection: $abaSelecionada) {
                    ForEach(SettingsTab.allCases) { aba in
                        Text(aba.rawValue).tag(aba)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch abaSelecionada {
                        case .teclado:
                            painelTeclado
                        case .telaCRT:
                            painelDebugCurvatura
                        case .som:
                            painelSom
                        case .ia:
                            painelGemini
                            painelConfiguracaoExecucao
                            painelExemplos
                        case .analise:
                            painelLatenciaETokens
                            painelComparativo
                            painelResultadosComparados
                            painelParametrosEEvidencias
                        }
                    }
                    .padding()
                }
            }
            .font(FontRegistrationManager.chicago(size: 14))
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluído") { dismiss() }
                        .font(FontRegistrationManager.chicago(size: 14))
                }
            }
        }
    }

    // MARK: - 0a. Teclado Virtual (Relevo, Sombra e Camada Intermediária)

    private var painelSom: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Som senoidal de 130 Hz", isOn: $sineToneEnabled)
                Text("Toca enquanto o app estiver em primeiro plano. Desative aqui quando quiser silenciar.")
                    .font(FontRegistrationManager.chicago(size: 11))
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Áudio", systemImage: "waveform")
        }
    }

    private var painelTeclado: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Toggle("Opacidade no fundo dos botões", isOn: $keyboardConfig.keyFillEnabled)
                    Text("Adiciona preenchimento translúcido claro dentro de cada tecla.")
                        .font(FontRegistrationManager.chicago(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Toggle("Sombra abaixo dos botões", isOn: $keyboardConfig.keyShadowEnabled)
                    Text("Projeta uma leve sombra sob cada tecla com recuo ao pressionar.")
                        .font(FontRegistrationManager.chicago(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 3) {
                    Toggle("Fundo opaco atrás do teclado", isOn: $keyboardConfig.trayBackgroundEnabled)
                    Text("Camada intermediária opaca separando o teclado da área de escrita.")
                        .font(FontRegistrationManager.chicago(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 10) {
                    Button("Voltar ao estado chapado") {
                        keyboardConfig.revertToFlat()
                    }
                    .font(FontRegistrationManager.chicago(size: 12))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(keyboardConfig.isFlatState)

                    Spacer()

                    if !keyboardConfig.isDefaultState {
                        Button("Restaurar padrões") {
                            keyboardConfig.restoreDefaults()
                        }
                        .font(FontRegistrationManager.chicago(size: 12))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .font(FontRegistrationManager.chicago(size: 13))
        } label: {
            Text("Aparência do Teclado Virtual")
                .font(FontRegistrationManager.chicago(size: 14))
        }
    }

    // MARK: - 0b. Debug: Curvatura Barril e Sombreamento do Vidro CRT

    private var painelDebugCurvatura: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                debugSliderRow(
                    titulo: "Curvatura Barril",
                    constante: "defaultCurvature",
                    valor: $crtConfig.curvature,
                    range: CRTBarrelConfig.curvatureRange
                )
                debugSliderRow(
                    titulo: "Vinheta Convexa (Domo)",
                    constante: "defaultVignetteStrength",
                    valor: $crtConfig.vignetteStrength,
                    range: CRTBarrelConfig.vignetteRange
                )
                debugSliderRow(
                    titulo: "Sombra da Moldura (Recuo)",
                    constante: "defaultBezelShadowStrength",
                    valor: $crtConfig.bezelShadowStrength,
                    range: CRTBarrelConfig.bezelShadowRange
                )
                debugSliderRow(
                    titulo: "Reflexo de Vidro (Centro)",
                    constante: "defaultGlassGlareStrength",
                    valor: $crtConfig.glassGlareStrength,
                    range: CRTBarrelConfig.glassGlareRange
                )

                HStack {
                    Text("Valores diretos para CRTBarrelConfig")
                        .font(FontRegistrationManager.chicago(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if crtConfig.hasCustomValues {
                        Button("Restaurar padrões") {
                            crtConfig.resetToDefaults()
                        }
                        .font(FontRegistrationManager.chicago(size: 11))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .font(FontRegistrationManager.chicago(size: 13))
        } label: {
            Text("Debug · Vidro CRT (Curvatura e Sombreamento)")
                .font(FontRegistrationManager.chicago(size: 14))
        }
    }

    private func debugSliderRow(
        titulo: String,
        constante: String,
        valor: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(titulo)
                Spacer()
                Text(String(format: "%.2f", valor.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Slider(value: valor, in: range, step: 0.01)
            Text(constante)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 1. Configuração e Status da API do Gemini

    private var painelGemini: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 9, height: 9)
                    Text(statusTexto)
                        .font(FontRegistrationManager.chicago(size: 13))
                    Spacer()
                }
                .padding(.bottom, 2)

                TextField("Modelo (ex: gemini-3.5-flash-lite)", text: $interpretador.modeloGemini)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Chave pessoal da API do Gemini (opcional)", text: $interpretador.chaveGemini)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: interpretador.chaveGemini) { _, nova in
                        UserDefaults.standard.set(nova, forKey: "geminiAPIKey")
                    }

                Picker("Nível de raciocínio", selection: $interpretador.nivelRaciocinio) {
                    ForEach(NivelRaciocinio.allCases) { nivel in
                        Text(nivel.titulo).tag(nivel)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: interpretador.nivelRaciocinio) { _, novo in
                    UserDefaults.standard.set(novo.rawValue, forKey: "geminiThinking")
                }
                Text("Thinking alto melhora a qualidade, mas aumenta tokens de saída, custo e TPM. O nível é enviado ao Gemini como reasoning_effort.")
                    .font(FontRegistrationManager.chicago(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button {
                        interpretador.usarChaveDaBuild()
                    } label: {
                        Label(
                            interpretador.usandoChaveBuild ? "Usando chave da build" : "Usar chave da API da build",
                            systemImage: interpretador.usandoChaveBuild ? "checkmark.circle.fill" : "key.fill"
                        )
                        .font(FontRegistrationManager.chicago(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!interpretador.temChaveBuild || interpretador.usandoChaveBuild)

                    if !interpretador.temChaveBuild {
                        Text("Sem chave em Secrets.plist")
                            .font(FontRegistrationManager.chicago(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Free tier: 3.5/3.1 Flash-Lite ~500 req/dia e 250K tokens/min.")
                    .font(FontRegistrationManager.chicago(size: 11))
                    .foregroundStyle(.secondary)
            }
            .font(FontRegistrationManager.chicago(size: 13))
        } label: {
            Text("Gemini (API)")
                .font(FontRegistrationManager.chicago(size: 14))
        }
    }

    // MARK: - 1b. Exemplos Rápidos

    private var painelExemplos: some View {
        PainelRecolhivel(titulo: "Exemplos", aberto: $exemplosAberto) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Exemplo.todos) { ex in
                    Button {
                        onSelectExample(ex.texto)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.titulo)
                                .font(FontRegistrationManager.chicago(size: 13))
                                .foregroundStyle(.primary)
                            Text(ex.texto)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 2. Estratégia e Execução

    private var painelConfiguracaoExecucao: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Estratégia de schema")
                    Spacer()
                    Picker("Estratégia de schema", selection: $modo) {
                        ForEach(ModoChamadas.allCases) { Text($0.tituloCurto).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Text(descricaoDoModo)
                    .font(FontRegistrationManager.chicago(size: 11))
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Estrutura da resposta")
                    Spacer()
                    Picker("Estrutura da resposta", selection: $estrutura) {
                        ForEach(EstruturaResposta.allCases) { Text($0.tituloCurto).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
                Text(estrutura == .partes
                     ? "Partes por parâmetro: cada parâmetro traz trechos com início, fim, núcleos e nível próprio. O nível do parâmetro é o da parte dominante. A evidência é sempre exigida."
                     : "Nível único para o texto inteiro, com uma citação de evidência por parâmetro.")
                    .font(FontRegistrationManager.chicago(size: 11))
                    .foregroundStyle(.secondary)

                Toggle("Incluir evidências (citação do trecho)", isOn: $comEvidencia)
                    .disabled(estrutura == .partes)
                Text(estrutura == .partes
                     ? "Na estrutura por partes, a própria parte é a evidência; esta opção não se aplica."
                     : (comEvidencia
                        ? "Com citação: permite distribuir as animações palavra a palavra na frase."
                        : "Só números: menos tokens de saída, aplica o valor global na frase."))
                    .font(FontRegistrationManager.chicago(size: 11))
                    .foregroundStyle(.secondary)

                Toggle("Determinístico (greedy / temp 0)", isOn: $deterministico)

                HStack {
                    Button("Interpretar") { onTriggerRun(1) }
                        .buttonStyle(.borderedProminent)
                    Button("Rodar 5×") { onTriggerRun(5) }
                        .buttonStyle(.bordered)
                }
                .disabled(interpretador.executando || interpretador.indisponibilidade != nil || texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if interpretador.executando {
                    HStack {
                        ProgressView()
                        Text(interpretador.progresso).font(FontRegistrationManager.chicago(size: 12))
                    }
                }
                if let aviso = interpretador.indisponibilidade {
                    Label(aviso, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(FontRegistrationManager.chicago(size: 12))
                }
                if let erro = interpretador.erro {
                    Label(erro, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                        .font(FontRegistrationManager.chicago(size: 12))
                }

                DisclosureGroup("Prompts de instruções enviados") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(promptsVisiveis, id: \.0) { titulo, conteudo in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(titulo).font(FontRegistrationManager.chicago(size: 12))
                                    Spacer()
                                    Text("\(conteudo.count) caracteres")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(conteudo)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .font(FontRegistrationManager.chicago(size: 13))
        } label: {
            Text("Estratégia e Execução")
                .font(FontRegistrationManager.chicago(size: 14))
        }
    }

    // MARK: - 3. Latência, Tempo Gasto e Tokens

    private var painelLatenciaETokens: some View {
        PainelRecolhivel(titulo: "Latência e Tokens", aberto: $latenciaAberta) {
            VStack(alignment: .leading, spacing: 6) {
                if let u = interpretador.execucoes.last {
                    LabeledContent("Última (total)", value: fmt(u.segundos) + (u.fria ? " (partida a frio)" : ""))
                    LabeledContent("Modelo", value: "Gemini · \(u.modelo)")
                    LabeledContent("Configuração", value: "\(u.modo.tituloCurto) · \(u.estrutura.tituloCurto) · \(u.comEvidencia ? "com evidência" : "só números") · \(u.deterministico ? "greedy" : "amostragem")")
                    let n = u.chamadas.count
                    LabeledContent("Chamadas", value: "\(n), média \(fmt(u.segundos / Double(max(n, 1))))")
                    LabeledContent("Prompt total", value: "\(u.caracteresPrompt) caracteres")
                    LabeledContent("Tokens", value: "\(u.tokensEntrada) entrada (cache \(u.tokensEntradaCache)) · \(u.tokensSaida) saída")

                    DisclosureGroup("Tempos e tokens por chamada") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(u.chamadas) { c in
                                LabeledContent(c.rotulo) {
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(fmt(c.segundos))
                                        Text("\(c.tokensEntrada.map(String.init) ?? "—") in · \(c.tokensSaida.map(String.init) ?? "—") out")
                                            .foregroundStyle(.secondary)
                                    }
                                    .monospacedDigit()
                                }
                            }
                        }
                        .font(.caption)
                    }
                } else {
                    Text("Sem execuções ainda.").foregroundStyle(.secondary)
                }

                let q = interpretador.latenciasQuentes(
                    modo: modo, estrutura: estrutura,
                    comEvidencia: estrutura == .partes ? true : comEvidencia,
                    deterministico: deterministico, texto: interpretador.textoDoLote
                )
                if !q.isEmpty {
                    LabeledContent("Média nesta configuração (sem a frio)", value: fmt(q.reduce(0, +) / Double(q.count)))
                    LabeledContent("Mínima / máxima", value: "\(fmt(q.min() ?? 0)) / \(fmt(q.max() ?? 0))")
                }
                if let fria = interpretador.execucoes.first(where: \.fria) {
                    LabeledContent("Partida a frio", value: "\(fmt(fria.segundos)) · \(fria.modo.tituloCurto) · \(fria.estrutura.tituloCurto) · \(fria.comEvidencia ? "com evidência" : "só números")")
                }
                LabeledContent("Execuções no app", value: "\(interpretador.execucoes.count)")
            }
            .font(FontRegistrationManager.chicago(size: 13))
        }
    }

    // MARK: - 4. Comparativo entre Configurações

    private var painelComparativo: some View {
        PainelRecolhivel(titulo: "Comparativo entre configurações (sem partidas a frio)", aberto: $comparativoAberto) {
            let resumos = interpretador.resumosPorConfiguracao(texto: interpretador.textoDoLote)
            if resumos.isEmpty {
                Text("Rode pelo menos uma configuração para comparar. A primeira execução fica fora da média aquecida.")
                    .font(FontRegistrationManager.chicago(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(resumos) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(r.modo.tituloCurto) · \(r.estrutura.tituloCurto) · \(r.comEvidencia ? "com evidência" : "só números") · \(r.deterministico ? "greedy" : "amostragem")")
                                    .font(FontRegistrationManager.chicago(size: 12))
                                Spacer()
                                Text("\(r.amostras)× · média \(fmt(r.media))")
                                    .font(.caption.monospacedDigit())
                            }
                            Text("mín. \(fmt(r.minima)) · máx. \(fmt(r.maxima)) · tokens \(Int(r.mediaTokensEntrada)) in / \(Int(r.mediaTokensSaida)) out")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var painelResultadosComparados: some View {
        PainelRecolhivel(titulo: "Comparação de resultados", aberto: $comparacaoAberta) {
            if let comp = interpretador.comparar(texto: interpretador.textoDoLote, referencia: referencia) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Referência", selection: $referencia) {
                        Text("Automática (15 chamadas com evidência)").tag(nil as ConfiguracaoResultado?)
                        ForEach(comp.configuracoes) { c in
                            Text(c.titulo).tag(c as ConfiguracaoResultado?)
                        }
                    }
                    .pickerStyle(.menu)

                    ScrollView(.horizontal) {
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
                            GridRow {
                                Text("Parâmetro").font(FontRegistrationManager.chicago(size: 12)).gridColumnAlignment(.leading)
                                ForEach(comp.configuracoes) { c in
                                    Text(c.titulo).font(.caption2.bold()).frame(width: 92, alignment: .leading)
                                }
                            }
                            ForEach(comp.linhas) { linha in
                                GridRow {
                                    Text(linha.def.nome).font(FontRegistrationManager.chicago(size: 12))
                                    ForEach(comp.configuracoes) { c in
                                        Text(valorComparado(linha.valores[c.id], escala: linha.def.escala))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(c.id == comp.referencia.id ? .primary : .secondary)
                                            .frame(width: 92, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Métricas contra a referência").font(FontRegistrationManager.chicago(size: 12))
                        ForEach(comp.metricas) { m in
                            HStack {
                                Text(m.configuracao.titulo).font(.caption2)
                                Spacer()
                                Text("exatos \(m.exatos)/\(m.comparaveis) · Δ \(String(format: "%.1f", m.diferencaMedia)) · sinal \(Int((m.concordanciaSinal * 100).rounded()))%")
                                    .font(.caption2.monospacedDigit())
                            }
                        }
                    }
                }
            } else {
                Text("Rode configurações para comparar os níveis.")
                    .font(FontRegistrationManager.chicago(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 5. Valores dos Parâmetros e Evidências da IA

    @ViewBuilder
    private var painelParametrosEEvidencias: some View {
        if interpretador.lote.isEmpty {
            Text("Escreva um texto e toque em Interpretar. Parâmetros bipolares vão de -1 a +1; Distância e Fragmentação vão de 0 a +1.")
                .font(FontRegistrationManager.chicago(size: 12))
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Text(interpretador.lote.count > 1
                     ? "Média de \(interpretador.lote.count) execuções (± desvio)"
                     : "Resultado dos Parâmetros e Evidências")
                    .font(FontRegistrationManager.chicago(size: 15))
                Spacer()
                ShareLink(item: interpretador.jsonDoLote, preview: SharePreview("Resultados do lote"))
            }

            painelFiltros

            ForEach(Grupo.allCases, id: \.self) { grupo in
                let defs = Catalogo.todos.filter { $0.grupo == grupo }
                if !defs.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(grupo.rawValue)
                            .font(FontRegistrationManager.chicago(size: 14))
                            .foregroundStyle(.secondary)
                        ForEach(defs) { d in
                            LinhaParametro(
                                def: d,
                                media: interpretador.media(d.id, filtros),
                                desvio: interpretador.desvio(d.id, filtros),
                                ultimo: interpretador.ultimo(d.id),
                                estrutura: interpretador.lote.last?.estrutura ?? estrutura
                            )
                        }
                    }
                }
            }
        }
    }

    private var painelFiltros: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let u = interpretador.lote.last, interpretador.evidenciaNoLote {
                    Text("Última execução: \(u.contradicoes) contradição(ões), \(u.naoLiterais) citação(ões) não literal(is).")
                        .font(FontRegistrationManager.chicago(size: 12))
                        .foregroundStyle(.secondary)
                    Toggle("Zerar contradições (nível ≠ 0 com evidência 'nenhuma')", isOn: $filtros.zerarContradicoes)
                    Toggle("Zerar citações que não aparecem literalmente no texto", isOn: $filtros.zerarNaoLiterais)
                }
                Picker("Ignorar |nível| menor que", selection: $filtros.limiar) {
                    Text("0").tag(0)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)
            }
            .font(FontRegistrationManager.chicago(size: 13))
        } label: {
            Text("Filtros de exibição (não rodam o modelo de novo)")
                .font(FontRegistrationManager.chicago(size: 13))
        }
    }

    private func valorComparado(_ nivel: Int?, escala: Escala) -> String {
        guard let nivel else { return "—" }
        return escala == .unipolar ? "\(nivel)" : (nivel > 0 ? "+\(nivel)" : "\(nivel)")
    }

    private func fmt(_ s: Double) -> String { String(format: "%.2f s", s) }
}
