import Foundation
import Observation
import FoundationModels

/// Filtros aplicados na exibição (não exigem rodar o modelo de novo).
struct Filtros {
    var zerarContradicoes = true     // evidência 'nenhuma' com nível ≠ 0
    var zerarNaoLiterais = false     // citação que não aparece literalmente no texto
    var limiar = 0                   // ignora |nível| menor que este valor
}

struct AncoraPalavra: Identifiable, Hashable, Sendable {
    var id: String { "\(trecho)|\(nivel)|\(principal)" }
    let trecho: String
    let nivel: Int
    let literal: Bool
    let principal: Bool

    var valor: Double { Double(nivel) / 5.0 }
}

struct ResultadoParametro {
    let nivel: Int               // -5...+5 (bipolar) ou 0...+5 (unipolar)
    let evidencia: String?       // nil no modo "só números"
    let contradicao: Bool        // nível ≠ 0, mas evidência 'nenhuma'
    let naoLiteral: Bool         // nível ≠ 0, evidência presente, mas ausente do texto
    var ancoras: [AncoraPalavra] = []

    var valor: Double { Double(nivel) / 5.0 }

    func valorEfetivo(_ f: Filtros) -> Double {
        if abs(nivel) < f.limiar { return 0 }
        if f.zerarContradicoes && contradicao { return 0 }
        if f.zerarNaoLiterais && naoLiteral { return 0 }
        return valor
    }
}

struct ChamadaExecucao: Identifiable {
    let id = UUID()
    let rotulo: String
    let segundos: Double
    let caracteresPrompt: Int
    let tokensEntrada: Int?
    let tokensEntradaCache: Int?
    let tokensSaida: Int?
    var variantePrompt: VarianteCompacta? = nil
    var tokensPromptEstimados: Int? = nil
    var contextSize: Int? = nil
}

struct FalhaConfiguracao: Identifiable {
    let id = UUID()
    let modo: ModoChamadas
    let comEvidencia: Bool
    let modelo: String
    let mensagem: String
}

struct Execucao: Identifiable {
    let id = UUID()
    let numero: Int
    let texto: String
    let modo: ModoChamadas
    let comEvidencia: Bool
    let deterministico: Bool
    let modelo: String
    let resultados: [String: ResultadoParametro]
    let chamadas: [ChamadaExecucao]
    let fria: Bool

    var segundos: Double { chamadas.reduce(0) { $0 + $1.segundos } }
    var caracteresPrompt: Int { chamadas.reduce(0) { $0 + $1.caracteresPrompt } }
    var tokensEntrada: Int { chamadas.compactMap(\.tokensEntrada).reduce(0, +) }
    var tokensEntradaCache: Int { chamadas.compactMap(\.tokensEntradaCache).reduce(0, +) }
    var tokensSaida: Int { chamadas.compactMap(\.tokensSaida).reduce(0, +) }
    var contradicoes: Int { resultados.values.filter(\.contradicao).count }
    var naoLiterais: Int { resultados.values.filter(\.naoLiteral).count }
}

struct ResumoConfiguracao: Identifiable {
    let modo: ModoChamadas
    let comEvidencia: Bool
    let deterministico: Bool
    let amostras: Int
    let media: Double
    let minima: Double
    let maxima: Double
    let mediaTokensEntrada: Double
    let mediaTokensSaida: Double

    var id: String { "\(modo.rawValue)|\(comEvidencia)|\(deterministico)" }
}

struct ConfiguracaoResultado: Identifiable, Hashable {
    let modo: ModoChamadas
    let comEvidencia: Bool
    let deterministico: Bool

    var id: String { "\(modo.rawValue)|\(comEvidencia)|\(deterministico)" }
    var titulo: String {
        "\(modo.tituloCurto) · \(comEvidencia ? "com evidência" : "só números")\(deterministico ? " · greedy" : "")"
    }
}

struct LinhaComparacao: Identifiable {
    let def: DefinicaoParametro
    let valores: [String: Int]
    let evidencias: [String: String]

    var id: String { def.id }
}

struct MetricaComparacao: Identifiable {
    let configuracao: ConfiguracaoResultado
    let exatos: Int
    let comparaveis: Int
    let diferencaMedia: Double
    let concordanciaSinal: Double

    var id: String { configuracao.id }
}

struct ComparacaoResultados {
    let referencia: ConfiguracaoResultado
    let configuracoes: [ConfiguracaoResultado]
    let linhas: [LinhaComparacao]
    let metricas: [MetricaComparacao]
}

extension Duration {
    var segundos: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

private struct LeituraBruta {
    let evidencia: String?
    let nivel: Int
    var extras: [(trecho: String, nivel: Int)] = []
}

private struct Resposta {
    let leituras: [String: LeituraBruta]
    let tokensEntrada: Int?
    let tokensEntradaCache: Int?
    let tokensSaida: Int?
}

private struct InstrucoesSelecionadas {
    let texto: String
    let variante: VarianteCompacta?
    let tokensPromptEstimados: Int
    let contextSize: Int
}

@MainActor
@Observable
final class Interpretador {
    var execucoes: [Execucao] = []
    var lote: [Execucao] = []
    var execucoesDoClique: [Execucao] = []
    var falhasDoClique: [FalhaConfiguracao] = []
    var textoDoLote = ""
    var modoDoLote: ModoChamadas = .umaChamada
    var evidenciaNoLote = true
    var deterministicoNoLote = false
    var executando = false
    var progresso = ""
    var erro: String?

    var modeloGemini = "gemini-3.5-flash-lite"
    var chaveGemini = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    var modeloDoLote = ""

    var configuracao: ConfiguracaoProvedor {
        ConfiguracaoProvedor(modeloGemini: modeloGemini, chaveGemini: chaveGemini)
    }

    var indisponibilidade: String? { configuracao.indisponibilidade }

    private var jaExecutou = false

    init() {
        assert(Set(Catalogo.todos.map(\.id)).count == Catalogo.todos.count, "IDs duplicados no catálogo.")
        assert(Catalogo.todos.count == 15, "O catálogo deve ter 15 parâmetros.")
    }

    // MARK: - Execução

    func rodar(texto: String, repeticoes: Int, modo: ModoChamadas, comEvidencia: Bool, deterministico: Bool) async {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { erro = "Digite um texto para interpretar."; return }

        let config = configuracao
        UserDefaults.standard.set(chaveGemini, forKey: "geminiAPIKey")

        executando = true
        erro = nil
        lote = []
        execucoesDoClique = []
        falhasDoClique = []
        textoDoLote = limpo
        modoDoLote = modo
        evidenciaNoLote = comEvidencia
        deterministicoNoLote = deterministico
        modeloDoLote = config.modelo

        for i in 1...repeticoes {
            if Task.isCancelled { break }
            do {
                let e = try await executarUma(
                    texto: limpo, numero: i, de: repeticoes, modo: modo,
                    comEvidencia: comEvidencia, deterministico: deterministico, config: config
                )
                lote.append(e)
                execucoesDoClique.append(e)
                execucoes.append(e)
            } catch is CancellationError {
                break
            } catch {
                let msg = mensagem(para: error)
                falhasDoClique.append(FalhaConfiguracao(modo: modo, comEvidencia: comEvidencia, modelo: config.modelo, mensagem: msg))
                erro = msg
                break
            }
        }
        progresso = ""
        executando = false
    }

    private func executarUma(
        texto: String, numero: Int, de total: Int, modo: ModoChamadas,
        comEvidencia: Bool, deterministico: Bool, config: ConfiguracaoProvedor
    ) async throws -> Execucao {
        try Task.checkCancellation()
        let fria = !jaExecutou
        var resultados: [String: ResultadoParametro] = [:]
        var chamadas: [ChamadaExecucao] = []
        let base = "Execução \(numero) de \(total)"
        let pedido = Instrucoes.pedido(texto)

        switch modo {
        case .umaChamada:
            progresso = "\(base) · todos os parâmetros"
            let selecionada = selecionarInstrucoes(defs: Catalogo.todos, comEvidencia: comEvidencia, pedido: pedido, config: config)
            let instrucoes = selecionada.texto
            let inicio = ContinuousClock.now
            let resposta: Resposta = comEvidencia
                ? try await chamarComEvidencia(TodosLeituras.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                : try await chamarSoNiveis(TodosNiveis.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)

            chamadas.append(ChamadaExecucao(
                rotulo: "Todos os parâmetros",
                segundos: (ContinuousClock.now - inicio).segundos,
                caracteresPrompt: instrucoes.count + pedido.count,
                tokensEntrada: resposta.tokensEntrada,
                tokensEntradaCache: resposta.tokensEntradaCache,
                tokensSaida: resposta.tokensSaida,
                variantePrompt: selecionada.variante,
                tokensPromptEstimados: selecionada.tokensPromptEstimados,
                contextSize: selecionada.contextSize
            ))
            for (id, b) in resposta.leituras {
                if let def = Catalogo.porID[id] {
                    resultados[id] = Self.resultado(de: b, texto: texto, definicao: def)
                }
            }

        case .porGrupo:
            for g in GrupoChamada.allCases {
                try Task.checkCancellation()
                progresso = "\(base) · \(g.titulo)"
                let defs = Catalogo.definicoes(do: g)
                let instrucoes = Instrucoes.sistema(defs: defs, comEvidencia: comEvidencia)
                let inicio = ContinuousClock.now
                let resposta: Resposta
                switch (g, comEvidencia) {
                case (.afetoVoz, true):
                    resposta = try await chamarComEvidencia(GrupoAfetoVoz.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                case (.afetoVoz, false):
                    resposta = try await chamarSoNiveis(GrupoAfetoVozN.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                case (.narrativaEstrutura, true):
                    resposta = try await chamarComEvidencia(GrupoNarrativaEstrutura.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                case (.narrativaEstrutura, false):
                    resposta = try await chamarSoNiveis(GrupoNarrativaEstruturaN.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                case (.sensorial, true):
                    resposta = try await chamarComEvidencia(GrupoSensorial.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                case (.sensorial, false):
                    resposta = try await chamarSoNiveis(GrupoSensorialN.self, instrucoes: instrucoes, pedido: pedido, deterministico: deterministico, config: config)
                }
                chamadas.append(ChamadaExecucao(
                    rotulo: g.titulo,
                    segundos: (ContinuousClock.now - inicio).segundos,
                    caracteresPrompt: instrucoes.count + pedido.count,
                    tokensEntrada: resposta.tokensEntrada,
                    tokensEntradaCache: resposta.tokensEntradaCache,
                    tokensSaida: resposta.tokensSaida
                ))
                for (id, b) in resposta.leituras {
                    if let def = Catalogo.porID[id] {
                        resultados[id] = Self.resultado(de: b, texto: texto, definicao: def)
                    }
                }
            }

        case .porParametro:
            for (k, d) in Catalogo.todos.enumerated() {
                try Task.checkCancellation()
                progresso = "\(base) · \(d.nome) (\(k + 1)/\(Catalogo.todos.count))"
                let instrucoes = Instrucoes.sistema(defs: [d], comEvidencia: comEvidencia)
                let inicio = ContinuousClock.now
                let bruta: LeituraBruta
                let tokensEntrada: Int?
                let tokensEntradaCache: Int?
                let tokensSaida: Int?

                if comEvidencia {
                    switch d.escala {
                    case .bipolar:
                        let r = try await config.responder(instructions: instrucoes, prompt: pedido, generating: LeituraDetalhada.self, deterministico: deterministico)
                        let extras = r.content.ancorasExtras.map { ($0.trecho, $0.nivel) }
                        bruta = LeituraBruta(evidencia: r.content.evidencia, nivel: r.content.nivel, extras: extras)
                        (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                    case .unipolar:
                        let r = try await config.responder(instructions: instrucoes, prompt: pedido, generating: LeituraUnipolarDetalhada.self, deterministico: deterministico)
                        let extras = r.content.ancorasExtras.map { ($0.trecho, $0.nivel) }
                        bruta = LeituraBruta(evidencia: r.content.evidencia, nivel: r.content.nivel, extras: extras)
                        (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                    }
                } else {
                    switch d.escala {
                    case .bipolar:
                        let r = try await config.responder(instructions: instrucoes, prompt: pedido, generating: Nivel.self, deterministico: deterministico)
                        bruta = LeituraBruta(evidencia: nil, nivel: r.content.nivel)
                        (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                    case .unipolar:
                        let r = try await config.responder(instructions: instrucoes, prompt: pedido, generating: NivelUnipolar.self, deterministico: deterministico)
                        bruta = LeituraBruta(evidencia: nil, nivel: r.content.nivel)
                        (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                    }
                }
                chamadas.append(ChamadaExecucao(
                    rotulo: d.nome,
                    segundos: (ContinuousClock.now - inicio).segundos,
                    caracteresPrompt: instrucoes.count + pedido.count,
                    tokensEntrada: tokensEntrada,
                    tokensEntradaCache: tokensEntradaCache,
                    tokensSaida: tokensSaida
                ))
                resultados[d.id] = Self.resultado(de: bruta, texto: texto, definicao: d)
            }
        }

        jaExecutou = true
        return Execucao(
            numero: numero, texto: texto, modo: modo, comEvidencia: comEvidencia,
            deterministico: deterministico, modelo: config.modelo,
            resultados: resultados, chamadas: chamadas, fria: fria
        )
    }

    private func selecionarInstrucoes(
        defs: [DefinicaoParametro], comEvidencia: Bool, pedido: String, config: ConfiguracaoProvedor
    ) -> InstrucoesSelecionadas {
        let contextSize = config.contextSize
        let pedidoTokens = max(1, pedido.count / 4)
        let completo = Instrucoes.sistema(defs: defs, comEvidencia: comEvidencia)
        let tokensCompleto = config.estimarTokens(completo)
        return InstrucoesSelecionadas(
            texto: completo,
            variante: nil,
            tokensPromptEstimados: tokensCompleto + pedidoTokens,
            contextSize: contextSize
        )
    }

    private func chamarComEvidencia<T: GrupoLeituras & Sendable>(
        _ tipo: T.Type, instrucoes: String, pedido: String, deterministico: Bool, config: ConfiguracaoProvedor
    ) async throws -> Resposta {
        let r = try await config.responder(instructions: instrucoes, prompt: pedido, generating: tipo, deterministico: deterministico)
        var extrasPorParametro: [String: [(trecho: String, nivel: Int)]] = [:]
        for ancora in r.content.ancorasAdicionais {
            let keyNorm = Self.normalizar(ancora.parametro)
            let targetKey = Catalogo.todos.first { Self.normalizar($0.id) == keyNorm || Self.normalizar($0.nome) == keyNorm }?.id ?? keyNorm
            extrasPorParametro[targetKey, default: []].append((ancora.trecho, ancora.nivel))
        }
        let leiturasMapeadas = Dictionary(uniqueKeysWithValues: r.content.leituras.map { chave, valor in
            (chave, LeituraBruta(evidencia: valor.evidencia, nivel: valor.nivel, extras: extrasPorParametro[chave] ?? []))
        })
        return Resposta(
            leituras: leiturasMapeadas,
            tokensEntrada: r.tokensEntrada,
            tokensEntradaCache: r.tokensEntradaCache,
            tokensSaida: r.tokensSaida
        )
    }

    private func chamarSoNiveis<T: GrupoNiveis & Sendable>(
        _ tipo: T.Type, instrucoes: String, pedido: String, deterministico: Bool, config: ConfiguracaoProvedor
    ) async throws -> Resposta {
        let r = try await config.responder(instructions: instrucoes, prompt: pedido, generating: tipo, deterministico: deterministico)
        return Resposta(
            leituras: r.content.niveis.mapValues { LeituraBruta(evidencia: nil, nivel: $0.nivel) },
            tokensEntrada: r.tokensEntrada,
            tokensEntradaCache: r.tokensEntradaCache,
            tokensSaida: r.tokensSaida
        )
    }

    // MARK: - Verificação da Evidência

    private static func resultado(de b: LeituraBruta, texto: String, definicao: DefinicaoParametro) -> ResultadoParametro {
        let escala = definicao.escala
        let minimo = escala == .unipolar ? 0 : -5
        let nivel = max(minimo, min(5, b.nivel))
        func clampNivel(_ raw: Int) -> Int { max(minimo, min(5, raw)) }

        var ancorasExtrasValidadas: [AncoraPalavra] = []
        for extra in b.extras {
            let trechoLimpo = extra.trecho.trimmingCharacters(in: .whitespacesAndNewlines)
            let normTrecho = normalizar(trechoLimpo)
            guard !normTrecho.isEmpty, normTrecho != "nenhuma", normTrecho != "nenhum" else { continue }
            ancorasExtrasValidadas.append(AncoraPalavra(
                trecho: trechoLimpo,
                nivel: clampNivel(extra.nivel),
                literal: citacaoLiteral(trechoLimpo, em: texto),
                principal: false
            ))
        }

        guard let ev = b.evidencia else {
            return ResultadoParametro(nivel: nivel, evidencia: nil, contradicao: false, naoLiteral: false)
        }

        let norm = normalizar(ev)
        let semEvidencia = norm.isEmpty || norm == "nenhuma" || norm == "nenhum"
        if nivel == 0 && ancorasExtrasValidadas.isEmpty {
            return ResultadoParametro(nivel: 0, evidencia: ev, contradicao: false, naoLiteral: false)
        }
        if semEvidencia && ancorasExtrasValidadas.isEmpty {
            return ResultadoParametro(nivel: nivel, evidencia: ev, contradicao: true, naoLiteral: false)
        }

        var ancorasPrincipais: [AncoraPalavra] = []
        if !semEvidencia {
            for seg in parsearSegmentosEvidencia(ev, nivelPadrao: nivel, clampNivel: clampNivel) {
                let normSeg = normalizar(seg.trecho)
                guard !normSeg.isEmpty, normSeg != "nenhuma", normSeg != "nenhum" else { continue }
                ancorasPrincipais.append(AncoraPalavra(
                    trecho: seg.trecho,
                    nivel: seg.nivel,
                    literal: citacaoLiteral(seg.trecho, em: texto),
                    principal: true
                ))
            }
        }

        var todasAncoras: [AncoraPalavra] = []
        var vistos = Set<String>()
        for ancora in ancorasPrincipais + ancorasExtrasValidadas {
            let chaveUnica = "\(normalizar(ancora.trecho))|\(ancora.nivel)"
            if vistos.insert(chaveUnica).inserted {
                todasAncoras.append(ancora)
            }
        }

        let algumaPrincipalNaoLiteral = !ancorasPrincipais.isEmpty && ancorasPrincipais.contains(where: { !$0.literal })
        let todasExtrasNaoLiterais = ancorasPrincipais.isEmpty && !ancorasExtrasValidadas.isEmpty && ancorasExtrasValidadas.allSatisfy { !$0.literal }
        return ResultadoParametro(
            nivel: nivel,
            evidencia: ev,
            contradicao: semEvidencia && !ancorasExtrasValidadas.isEmpty ? false : (nivel != 0 && semEvidencia),
            naoLiteral: algumaPrincipalNaoLiteral || todasExtrasNaoLiterais,
            ancoras: todasAncoras
        )
    }

    private static func parsearSegmentosEvidencia(
        _ ev: String, nivelPadrao: Int, clampNivel: (Int) -> Int
    ) -> [(trecho: String, nivel: Int)] {
        ev.replacingOccurrences(of: "|", with: ";")
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { parte in
                if let colonIdx = parte.lastIndex(of: ":") {
                    let sufixo = parte[parte.index(after: colonIdx)...]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "+", with: "")
                    if let nivelExplicito = Int(sufixo) {
                        let trecho = String(parte[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trecho.isEmpty {
                            return (trecho, clampNivel(nivelExplicito))
                        }
                    }
                }
                return (parte, nivelPadrao)
            }
    }

    private static func citacaoLiteral(_ citacao: String, em texto: String) -> Bool {
        let alvo = normalizar(texto)
        let partes = citacao
            .replacingOccurrences(of: "…", with: "...")
            .components(separatedBy: "...")
            .map(normalizar)
            .filter { !$0.isEmpty }
        guard !partes.isEmpty else { return false }
        return partes.allSatisfy { alvo.contains($0) }
    }

    private static func normalizar(_ s: String) -> String {
        let base = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
        let limpo = base.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(limpo).split(separator: " ").joined(separator: " ")
    }

    private func mensagem(para erro: Error) -> String {
        if let e = erro as? ChatCompletionsLanguageModel.RequestError {
            switch e {
            case .invalidRequest(let descricao):
                return "Requisição inválida: \(descricao)"
            case .invalidStreamData:
                return "Resposta inválida do Gemini (stream)."
            case .httpError(let statusCode, let data):
                let corpo = String(data: data, encoding: .utf8) ?? ""
                switch statusCode {
                case 400: return "O Gemini rejeitou a requisição (400). \(corpo)"
                case 401, 403: return "Chave da API do Gemini inválida ou sem permissão (\(statusCode))."
                case 404: return "Modelo não encontrado (404). Confira o nome do modelo nos Ajustes."
                case 429: return "Limite de requisições atingido (429). Aguarde alguns instantes."
                default: return "Erro HTTP \(statusCode). \(corpo)"
                }
            }
        }
        if let e = erro as? ChatCompletionsLanguageModel.APIError {
            return "Erro da API: \(e.message)"
        }
        if let e = erro as? URLError {
            return "Falha de rede: \(e.localizedDescription)"
        }
        return "Erro: \(erro.localizedDescription)"
    }

    // MARK: - Estatísticas do Lote

    func ultimo(_ id: String) -> ResultadoParametro? { lote.last?.resultados[id] }

    func media(_ id: String, _ f: Filtros) -> Double {
        let v = lote.compactMap { $0.resultados[id]?.valorEfetivo(f) }
        guard !v.isEmpty else { return 0 }
        return v.reduce(0, +) / Double(v.count)
    }

    func desvio(_ id: String, _ f: Filtros) -> Double? {
        let v = lote.compactMap { $0.resultados[id]?.valorEfetivo(f) }
        guard v.count > 1 else { return nil }
        let m = v.reduce(0, +) / Double(v.count)
        let s = v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(v.count - 1)
        return s.squareRoot()
    }

    func execucoesAquecidas(modo: ModoChamadas, comEvidencia: Bool, deterministico: Bool, texto: String? = nil) -> [Execucao] {
        let modelo = configuracao.modelo
        return execucoes.filter {
            !$0.fria && $0.modelo == modelo
                && $0.modo == modo && $0.comEvidencia == comEvidencia
                && $0.deterministico == deterministico && (texto == nil || $0.texto == texto)
        }
    }

    func latenciasQuentes(modo: ModoChamadas, comEvidencia: Bool, deterministico: Bool, texto: String? = nil) -> [Double] {
        execucoesAquecidas(modo: modo, comEvidencia: comEvidencia, deterministico: deterministico, texto: texto).map(\.segundos)
    }

    func resumosPorConfiguracao(texto: String) -> [ResumoConfiguracao] {
        ModoChamadas.allCases.flatMap { modo in
            [true, false].flatMap { evidencia in
                [true, false].compactMap { deterministico -> ResumoConfiguracao? in
                    let execs = execucoesAquecidas(modo: modo, comEvidencia: evidencia, deterministico: deterministico, texto: texto)
                    guard !execs.isEmpty else { return nil }
                    let latencias = execs.map(\.segundos)
                    return ResumoConfiguracao(
                        modo: modo, comEvidencia: evidencia, deterministico: deterministico,
                        amostras: execs.count,
                        media: latencias.reduce(0, +) / Double(latencias.count),
                        minima: latencias.min() ?? 0,
                        maxima: latencias.max() ?? 0,
                        mediaTokensEntrada: Double(execs.map(\.tokensEntrada).reduce(0, +)) / Double(execs.count),
                        mediaTokensSaida: Double(execs.map(\.tokensSaida).reduce(0, +)) / Double(execs.count)
                    )
                }
            }
        }
    }

    // MARK: - Comparação de Resultados

    func configuracoesDisponiveis(texto: String) -> [ConfiguracaoResultado] {
        ModoChamadas.allCases.flatMap { modo in
            [true, false].flatMap { evidencia in
                [true, false].compactMap { deterministico -> ConfiguracaoResultado? in
                    let c = ConfiguracaoResultado(modo: modo, comEvidencia: evidencia, deterministico: deterministico)
                    return ultimaExecucao(c, texto: texto) == nil ? nil : c
                }
            }
        }
    }

    func comparar(texto: String, referencia: ConfiguracaoResultado? = nil) -> ComparacaoResultados? {
        let configs = configuracoesDisponiveis(texto: texto)
        guard !configs.isEmpty else { return nil }
        let ref = referencia.flatMap { configs.contains($0) ? $0 : nil }
            ?? configs.first { $0.modo == .porParametro && $0.comEvidencia && $0.deterministico == deterministicoNoLote }
            ?? configs.first { $0.modo == .porParametro && $0.comEvidencia }
            ?? configs[0]
        guard let refExec = ultimaExecucao(ref, texto: texto) else { return nil }

        let linhas = Catalogo.todos.map { d in
            var valores: [String: Int] = [:]
            var evidencias: [String: String] = [:]
            for c in configs {
                guard let e = ultimaExecucao(c, texto: texto), let r = e.resultados[d.id] else { continue }
                valores[c.id] = r.nivel
                if let ev = r.evidencia, !ev.isEmpty { evidencias[c.id] = ev }
            }
            return LinhaComparacao(def: d, valores: valores, evidencias: evidencias)
        }

        let metricas = configs.compactMap { c -> MetricaComparacao? in
            guard let e = ultimaExecucao(c, texto: texto) else { return nil }
            var exatos = 0, comparaveis = 0, sinais = 0
            var soma = 0.0
            for d in Catalogo.todos {
                guard let a = refExec.resultados[d.id]?.nivel, let b = e.resultados[d.id]?.nivel else { continue }
                comparaveis += 1
                if a == b { exatos += 1 }
                soma += Double(abs(a - b))
                if Self.sinal(a, d.escala) == Self.sinal(b, d.escala) { sinais += 1 }
            }
            return MetricaComparacao(
                configuracao: c, exatos: exatos, comparaveis: comparaveis,
                diferencaMedia: comparaveis > 0 ? soma / Double(comparaveis) : 0,
                concordanciaSinal: comparaveis > 0 ? Double(sinais) / Double(comparaveis) : 0
            )
        }

        return ComparacaoResultados(referencia: ref, configuracoes: configs, linhas: linhas, metricas: metricas)
    }

    private func ultimaExecucao(_ c: ConfiguracaoResultado, texto: String) -> Execucao? {
        let modelo = configuracao.modelo
        return execucoes.last {
            $0.modelo == modelo && $0.texto == texto && $0.modo == c.modo
                && $0.comEvidencia == c.comEvidencia && $0.deterministico == c.deterministico
        }
    }

    private static func sinal(_ nivel: Int, _ escala: Escala) -> Int {
        if escala == .unipolar { return nivel == 0 ? 0 : 1 }
        return nivel > 0 ? 1 : (nivel < 0 ? -1 : 0)
    }

    // MARK: - Exportação JSON

    var jsonDoLote: String {
        let itens: [[String: Any]] = execucoesDoClique.map { e in
            let params: [String: Any] = Dictionary(uniqueKeysWithValues: e.resultados.map { id, r in
                (id, [
                    "escala": Catalogo.porID[id]?.escala.rawValue ?? Escala.bipolar.rawValue,
                    "nivel": r.nivel,
                    "valor": r.valor,
                    "evidencia": r.evidencia ?? NSNull(),
                    "ancoras": r.ancoras.map { a in
                        ["trecho": a.trecho, "nivel": a.nivel, "literal": a.literal, "principal": a.principal] as [String: Any]
                    },
                    "contradicao": r.contradicao,
                    "citacao_nao_literal": r.naoLiteral
                ] as [String: Any])
            })
            let chamadas: [[String: Any]] = e.chamadas.map { c in
                [
                    "rotulo": c.rotulo,
                    "segundos": c.segundos,
                    "caracteres_prompt": c.caracteresPrompt,
                    "tokens_entrada": c.tokensEntrada ?? NSNull(),
                    "tokens_entrada_cache": c.tokensEntradaCache ?? NSNull(),
                    "tokens_saida": c.tokensSaida ?? NSNull()
                ] as [String: Any]
            }
            return [
                "execucao": e.numero,
                "provedor": "gemini",
                "modelo": e.modelo,
                "modo": e.modo.rawValue,
                "com_evidencia": e.comEvidencia,
                "latencia_total_s": e.segundos,
                "chamadas": chamadas,
                "caracteres_prompt_total": e.caracteresPrompt,
                "tokens_entrada_total": e.tokensEntrada,
                "tokens_entrada_cache_total": e.tokensEntradaCache,
                "tokens_saida_total": e.tokensSaida,
                "deterministico": e.deterministico,
                "partida_a_frio": e.fria,
                "contradicoes": e.contradicoes,
                "citacoes_nao_literais": e.naoLiterais,
                "parametros": params
            ]
        }
        let raiz: [String: Any] = [
            "texto": textoDoLote,
            "caracteres": textoDoLote.count,
            "provedor": "gemini",
            "modelo": modeloDoLote,
            "modo": modoDoLote.rawValue,
            "com_evidencia": evidenciaNoLote,
            "deterministico": deterministicoNoLote,
            "execucoes": itens
        ]
        let dados = try? JSONSerialization.data(withJSONObject: raiz, options: [.prettyPrinted, .sortedKeys])
        return String(data: dados ?? Data(), encoding: .utf8) ?? "{}"
    }

    // MARK: - Mapeamento para ParameterScores (Frase e Por Palavra)

    func parameterScores(filtros: Filtros) -> ParameterScores {
        var scores = ParameterScores()
        guard !lote.isEmpty else { return scores }
        for param in MorphParameter.allCases {
            let avgNormalized = media(param.catalogoId, filtros)
            scores[param] = Int((avgNormalized * 5.0).rounded())
        }
        return scores
    }

    func wordParameterScores(tokens: [String], filtros: Filtros) -> [ParameterScores] {
        guard !tokens.isEmpty else { return [] }
        guard !lote.isEmpty else {
            return Array(repeating: ParameterScores(), count: tokens.count)
        }

        let flatParts = Self.achatarTokens(tokens)
        var somasPorPalavra = Array(
            repeating: Dictionary(uniqueKeysWithValues: MorphParameter.allCases.map { ($0, 0.0) }),
            count: tokens.count
        )

        for exec in lote {
            for param in MorphParameter.allCases {
                guard let res = exec.resultados[param.catalogoId] else { continue }

                if !exec.comEvidencia {
                    let nivelGlobal = Int((res.valorEfetivo(filtros) * 5.0).rounded())
                    if nivelGlobal != 0 {
                        for idx in tokens.indices {
                            somasPorPalavra[idx][param, default: 0] += Double(nivelGlobal)
                        }
                    }
                    continue
                }

                if res.contradicao && filtros.zerarContradicoes { continue }

                let ancorasValidas = res.ancoras.filter { a in
                    abs(a.nivel) >= filtros.limiar && (!filtros.zerarNaoLiterais || a.literal)
                }

                var nivelPorPalavra: [Int: (nivel: Int, especifica: Bool)] = [:]
                for ancora in ancorasValidas where ancora.nivel != 0 {
                    for idx in Self.indicesCorrespondentes(trecho: ancora.trecho, em: flatParts) {
                        let ehEspecifica = !ancora.principal
                        if let atual = nivelPorPalavra[idx] {
                            if (ehEspecifica && !atual.especifica) || (ehEspecifica == atual.especifica && abs(ancora.nivel) >= abs(atual.nivel)) {
                                nivelPorPalavra[idx] = (ancora.nivel, ehEspecifica)
                            }
                        } else {
                            nivelPorPalavra[idx] = (ancora.nivel, ehEspecifica)
                        }
                    }
                }

                if nivelPorPalavra.isEmpty {
                    let fallback = Int((res.valorEfetivo(filtros) * 5.0).rounded())
                    if fallback != 0 && !filtros.zerarNaoLiterais {
                        for idx in tokens.indices {
                            somasPorPalavra[idx][param, default: 0] += Double(fallback)
                        }
                    }
                } else {
                    for (idx, info) in nivelPorPalavra {
                        somasPorPalavra[idx][param, default: 0] += Double(info.nivel)
                    }
                }
            }
        }

        let divisor = Double(lote.count)
        return somasPorPalavra.map { mapa in
            var scores = ParameterScores()
            for param in MorphParameter.allCases {
                scores[param] = Int(((mapa[param] ?? 0) / divisor).rounded())
            }
            return scores
        }
    }

    private struct TokenParte {
        let wordIndex: Int
        let text: String
    }

    private static let palavrasConectivas: Set<String> = [
        "a", "o", "as", "os", "e", "ou", "de", "do", "da", "dos", "das",
        "em", "no", "na", "nos", "nas", "num", "numa", "um", "uma", "uns", "umas",
        "ao", "aos", "com", "por", "para", "pro", "pra", "se", "que",
        "seu", "sua", "seus", "suas", "meu", "minha", "teu", "tua"
    ]

    private static func partesNormalizadas(_ s: String) -> [String] {
        normalizar(s).split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    private static func achatarTokens(_ tokens: [String]) -> [TokenParte] {
        tokens.enumerated().flatMap { idx, token in
            partesNormalizadas(token).map { TokenParte(wordIndex: idx, text: $0) }
        }
    }

    private static func indicesCorrespondentes(trecho: String, em flatParts: [TokenParte]) -> [Int] {
        let citParts = partesNormalizadas(trecho)
        guard !citParts.isEmpty, !flatParts.isEmpty else { return [] }

        // 1. Correspondência exata contígua
        if flatParts.count >= citParts.count {
            var encontrados = Set<Int>()
            for start in 0...(flatParts.count - citParts.count) {
                if (0..<citParts.count).allSatisfy({ flatParts[start + $0].text == citParts[$0] }) {
                    for k in 0..<citParts.count {
                        encontrados.insert(flatParts[start + k].wordIndex)
                    }
                }
            }
            if !encontrados.isEmpty { return encontrados.sorted() }
        }

        // 2. Palavras individuais significativas
        let significativas = citParts.filter { !palavrasConectivas.contains($0) }
        let alvos = significativas.isEmpty ? citParts : significativas
        let exatas = Set(flatParts.filter { alvos.contains($0.text) }.map(\.wordIndex))
        if !exatas.isEmpty { return exatas.sorted() }

        // 3. Radical comum / flexão
        var radicais = Set<Int>()
        for alvo in alvos where alvo.count >= 3 {
            for fp in flatParts where fp.text.count >= 3 {
                let prefixMatch = (fp.text.hasPrefix(alvo) || alvo.hasPrefix(fp.text)) && abs(fp.text.count - alvo.count) <= 2
                let comum = fp.text.commonPrefix(with: alvo).count
                let minLen = min(fp.text.count, alvo.count)
                let radicalMatch = minLen >= 4 && comum >= max(4, minLen - 2)
                if prefixMatch || radicalMatch {
                    radicais.insert(fp.wordIndex)
                }
            }
        }
        return radicais.sorted()
    }
}
