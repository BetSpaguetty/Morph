import SwiftUI

struct SettingsSheetView: View {
    @Bindable var interpretador: Interpretador
    @Bindable var crtConfig: CRTBarrelConfig
    @Binding var texto: String
    @Binding var modo: ModoChamadas
    @Binding var comEvidencia: Bool
    @Binding var deterministico: Bool
    @Binding var filtros: Filtros

    var onTriggerRun: (Int) -> Void
    var onSelectExample: (String) -> Void

    @Environment(\.dismiss) private var dismiss

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
        if interpretador.executando { return "Gemini · Interpretando..." }
        if interpretador.erro != nil { return "Gemini · Erro na requisição" }
        if interpretador.indisponibilidade != nil { return "Gemini · Chave pendente" }
        return "Gemini · Pronto"
    }

    private var descricaoDoModo: String {
        switch modo {
        case .umaChamada:
            return "Um schema com os 15 parâmetros. Menos chamadas, mas prompt maior e saída mais longa."
        case .porGrupo:
            return "Três schemas de cinco parâmetros. Equilíbrio entre contexto, paralelismo e tamanho da saída."
        case .porParametro:
            return "Quinze schemas de um parâmetro. Instruções mais curtas por chamada, porém com 15 idas ao modelo."
        }
    }

    private var promptsVisiveis: [(String, String)] {
        switch modo {
        case .umaChamada:
            return [("Chamada única (15 parâmetros)", Instrucoes.sistema(defs: Catalogo.todos, comEvidencia: comEvidencia))]
        case .porGrupo:
            return GrupoChamada.allCases.map { g in
                (g.titulo, Instrucoes.sistema(defs: Catalogo.definicoes(do: g), comEvidencia: comEvidencia))
            }
        case .porParametro:
            let d = Catalogo.todos[0]
            return [("Exemplo: chamada de \(d.nome)", Instrucoes.sistema(defs: [d], comEvidencia: comEvidencia))]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    painelDebugCurvatura
                    painelGemini
                    painelExemplos
                    painelConfiguracaoExecucao
                    painelLatenciaETokens
                    painelComparativo
                    painelResultadosComparados
                    painelParametrosEEvidencias
                }
                .padding()
            }
            .font(FontRegistrationManager.chicago(size: 14))
            .navigationTitle("Ajustes e Diagnóstico IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluído") { dismiss() }
                        .font(FontRegistrationManager.chicago(size: 14))
                }
            }
        }
    }

    // MARK: - 0. Debug: Curvatura Barril e Sombreamento do Vidro CRT

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

                Toggle("Incluir evidências (citação do trecho)", isOn: $comEvidencia)
                Text(comEvidencia
                     ? "Com citação: permite distribuir as animações palavra a palavra na frase."
                     : "Só números: menos tokens de saída, aplica o valor global na frase.")
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
                    LabeledContent("Configuração", value: "\(u.modo.tituloCurto) · \(u.comEvidencia ? "com evidência" : "só números") · \(u.deterministico ? "greedy" : "amostragem")")
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
                    modo: modo, comEvidencia: comEvidencia,
                    deterministico: deterministico, texto: interpretador.textoDoLote
                )
                if !q.isEmpty {
                    LabeledContent("Média nesta configuração (sem a frio)", value: fmt(q.reduce(0, +) / Double(q.count)))
                    LabeledContent("Mínima / máxima", value: "\(fmt(q.min() ?? 0)) / \(fmt(q.max() ?? 0))")
                }
                if let fria = interpretador.execucoes.first(where: \.fria) {
                    LabeledContent("Partida a frio", value: "\(fmt(fria.segundos)) · \(fria.modo.tituloCurto) · \(fria.comEvidencia ? "com evidência" : "só números")")
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
                                Text("\(r.modo.tituloCurto) · \(r.comEvidencia ? "com evidência" : "só números") · \(r.deterministico ? "greedy" : "amostragem")")
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
                                ultimo: interpretador.ultimo(d.id)
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

// MARK: - Subcomponentes de Exibição dos Parâmetros

struct PainelRecolhivel<Conteudo: View>: View {
    let titulo: String
    @Binding var aberto: Bool
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $aberto) {
                conteudo.padding(.top, 6)
            } label: {
                Text(titulo)
                    .font(FontRegistrationManager.chicago(size: 14))
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct LinhaParametro: View {
    let def: DefinicaoParametro
    let media: Double
    let desvio: Double?
    let ultimo: ResultadoParametro?

    private var semValor: Bool { def.escala == .bipolar && abs(media) < 0.05 }

    private var rotulo: String {
        if semValor { return "sem valor" }
        var s = def.escala == .unipolar
            ? String(format: "%.1f", media)
            : String(format: "%+.1f", media)
        if let d = desvio { s += String(format: " ± %.2f", d) }
        return s
    }

    private var nivelFormatado: String {
        guard let u = ultimo else { return "" }
        return def.escala == .unipolar ? "\(u.nivel)" : (u.nivel > 0 ? "+\(u.nivel)" : "\(u.nivel)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(def.nome).font(FontRegistrationManager.chicago(size: 14))
                if def.candidata {
                    Text("candidata")
                        .font(FontRegistrationManager.chicago(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Text(rotulo)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(semValor ? .secondary : .primary)
            }

            if def.escala == .unipolar {
                BarraUnipolar(valor: max(0, media)).frame(height: 10)
            } else {
                BarraBipolar(valor: media).frame(height: 10)
            }

            HStack {
                Text(def.poloNegativo)
                Spacer()
                Text(def.poloPositivo)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let u = ultimo, (u.evidencia != nil || !u.ancoras.isEmpty), (u.nivel != 0 || def.escala == .unipolar || !u.ancoras.isEmpty) {
                VStack(alignment: .leading, spacing: 2) {
                    if let ev = u.evidencia {
                        Text("Última execução: nível \(nivelFormatado), evidência “\(ev)”")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                    let extras = u.ancoras.filter { !$0.principal }
                    if !extras.isEmpty {
                        let listaExtras = extras.map { a in
                            let valStr = def.escala == .unipolar ? "\(a.nivel)" : (a.nivel > 0 ? "+\(a.nivel)" : "\(a.nivel)")
                            return "“\(a.trecho)” (\(valStr))"
                        }.joined(separator: " · ")
                        Text("Âncoras extras: \(listaExtras)")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    if u.contradicao {
                        Label("o modelo deu nível sem apresentar evidência", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if u.naoLiteral {
                        Label("citação não encontrada literalmente no texto", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct BarraBipolar: View {
    let valor: Double

    var body: some View {
        GeometryReader { g in
            let meio = g.size.width / 2
            let largura = abs(valor) * meio
            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary)
                Rectangle()
                    .fill(valor >= 0 ? Color.indigo : Color.teal)
                    .frame(width: largura)
                    .offset(x: valor >= 0 ? meio : meio - largura)
                Rectangle().fill(.secondary).frame(width: 1).offset(x: meio)
            }
            .clipShape(Capsule())
        }
    }
}

struct BarraUnipolar: View {
    let valor: Double

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary)
                Rectangle()
                    .fill(Color.indigo)
                    .frame(width: CGFloat(max(0, min(1, valor))) * g.size.width)
            }
            .clipShape(Capsule())
        }
    }
}
