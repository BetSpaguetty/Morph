import Foundation
import Observation
import FoundationModels
import OSLog

/// Normaliza texto para comparação: sem acentos, sem caixa, só palavras separadas por espaço.
func normalizarTexto(_ s: String) -> String {
    let base = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
    let limpo = base.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
    return String(limpo).split(separator: " ").joined(separator: " ")
}

private struct LeituraBruta {
    let evidencia: String?
    let nivel: Int
}

private struct ParteBruta {
    let parametro: String?
    let inicio: String
    let fim: String
    let nivel: Int
    let nucleos: [String]
}

private struct Resposta {
    let leituras: [String: LeituraBruta]
    var partes: [String: [ParteBruta]] = [:]
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

nonisolated let logGemini = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Morph",
    category: "Gemini"
)

@MainActor
@Observable
final class Interpretador {
    var execucoes: [Execucao] = []          // todas desde a abertura do app
    var lote: [Execucao] = []               // execuções exibidas (a última configuração)
    var execucoesDoClique: [Execucao] = []  // todas as execuções do último clique, para exportação
    var falhasDoClique: [FalhaConfiguracao] = []
    var textoDoLote = ""
    var modoDoLote: ModoChamadas = .umaChamada
    var estruturaNoLote: EstruturaResposta = .partes
    var evidenciaNoLote = true
    var deterministicoNoLote = false
    var executando = false
    var progresso = ""
    var erro: String?

    var orcamento = OrcamentoChamadas()
    private var orcamentoEmUso: OrcamentoChamadas?
    private var prioridadeEmUso: PrioridadeChamada = .diagnostico

    var provedor: Provedor = .gemini
    var modeloGemini = "gemini-3.5-flash-lite"
    var chaveGemini = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
    var nivelRaciocinio = NivelRaciocinio(
        rawValue: UserDefaults.standard.string(forKey: "geminiThinking") ?? ""
    ) ?? .high
    var provedorDoLote: Provedor = .gemini
    var modeloDoLote = ""

    private static let chaveBuild: String = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let key = dict["GEMINI_API_KEY"] as? String else { return "" }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    var temChaveBuild: Bool { !Self.chaveBuild.isEmpty }

    var usandoChaveBuild: Bool {
        chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && temChaveBuild
    }

    private var chaveEfetiva: String {
        let pessoal = chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines)
        return pessoal.isEmpty ? Self.chaveBuild : pessoal
    }

    var configuracao: ConfiguracaoProvedor {
        ConfiguracaoProvedor(provedor: provedor, modeloGemini: modeloGemini,
                             chaveGemini: chaveEfetiva, nivelRaciocinio: nivelRaciocinio)
    }

    var modeloAtual: String { configuracao.modelo }

    var indisponibilidade: String? { configuracao.indisponibilidade }

    func usarChaveDaBuild() {
        chaveGemini = ""
        UserDefaults.standard.removeObject(forKey: "geminiAPIKey")
        erro = nil
    }

    private var jaExecutou = false
    private var falhasConsecutivas = 0
    private let maxFalhasConsecutivas = 3

    init() {
        assert(Set(Catalogo.todos.map(\.id)).count == Catalogo.todos.count, "IDs duplicados no catálogo.")
        assert(Catalogo.todos.count == 15, "O catálogo deve ter 15 parâmetros.")
        for grupo in GrupoChamada.allCases {
            assert(Catalogo.definicoes(do: grupo).count == 5, "Cada chamada deve ter 5 parâmetros.")
        }
    }

    // MARK: - Execução

    func rodar(texto: String, repeticoes: Int, modo: ModoChamadas,
               estrutura: EstruturaResposta = .partes,
               comEvidencia: Bool, deterministico: Bool) async {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { erro = "Digite um texto para interpretar."; return }

        let config = configuracao
        let evidencia = estrutura == .partes ? true : comEvidencia
        UserDefaults.standard.set(chaveGemini, forKey: "geminiAPIKey")
        UserDefaults.standard.set(nivelRaciocinio.rawValue, forKey: "geminiThinking")

        executando = true
        erro = nil
        falhasConsecutivas = 0
        lote = []
        execucoesDoClique = []
        falhasDoClique = []
        textoDoLote = limpo
        modoDoLote = modo
        estruturaNoLote = estrutura
        evidenciaNoLote = evidencia
        deterministicoNoLote = deterministico
        provedorDoLote = config.provedor
        modeloDoLote = config.modelo

        var ultimaFalha: String?
        for i in 1...repeticoes {
            if Task.isCancelled { break }
            do {
                let e = try await executarUma(texto: limpo, numero: i, de: repeticoes, modo: modo,
                                              estrutura: estrutura, comEvidencia: evidencia,
                                              deterministico: deterministico, config: config,
                                              orcamento: orcamento, prioridade: .diagnostico)
                lote.append(e)
                execucoesDoClique.append(e)
                execucoes.append(e)
                falhasConsecutivas = 0
                ultimaFalha = nil
                erro = nil
            } catch is CancellationError {
                break
            } catch {
                let texto = mensagem(para: error)
                falhasDoClique.append(FalhaConfiguracao(modo: modo, estrutura: estrutura,
                                                        comEvidencia: evidencia,
                                                        provedor: config.provedor, modelo: config.modelo,
                                                        mensagem: texto))
                falhasConsecutivas += 1
                let detalhe = "Execução \(i)/\(repeticoes) falhou (\(falhasConsecutivas) consecutiva(s)): \(texto)"
                logGemini.error("\(detalhe, privacy: .public)")

                if !erroRetentavel(error) {
                    erro = texto
                    break
                }
                if falhasConsecutivas >= maxFalhasConsecutivas {
                    erro = "Provedor instável: \(maxFalhasConsecutivas) falhas consecutivas. "
                        + "Interrompendo para não consumir cota. Última falha: \(texto)"
                    logGemini.error("Circuit breaker acionado após \(self.falhasConsecutivas) falhas")
                    break
                }
                ultimaFalha = texto
            }
        }
        if erro == nil, !Task.isCancelled {
            erro = ultimaFalha
        }
        progresso = ""
        executando = false
    }

    private func executarGrupo(_ g: GrupoChamada, estrutura: EstruturaResposta,
                               comEvidencia: Bool, pedido: String, opcoes: GenerationOptions,
                               deterministico: Bool, config: ConfiguracaoProvedor, base: String)
        async throws -> (Resposta, ChamadaExecucao) {
        progresso = "\(base) · \(g.titulo)"
        let defs = Catalogo.definicoes(do: g)
        let schema = Self.schema(do: g, estrutura: estrutura, comEvidencia: comEvidencia)
        let selecionada = await selecionarInstrucoes(defs: defs, estrutura: estrutura,
                                                     comEvidencia: comEvidencia,
                                                     schema: schema,
                                                     pedido: pedido, config: config)
        let instrucoes = selecionada.texto
        let inicio = ContinuousClock.now
        let resposta: Resposta
        if estrutura == .partes {
            resposta = try await chamarPartes(RespostaPartes.self, instrucoes: instrucoes,
                                              pedido: pedido, opcoes: opcoes,
                                              deterministico: deterministico, config: config)
        } else {
            switch (g, comEvidencia) {
            case (.afetoVoz, true):
                resposta = try await chamarComEvidencia(GrupoAfetoVoz.self, instrucoes: instrucoes,
                                                        pedido: pedido, opcoes: opcoes,
                                                        deterministico: deterministico, config: config)
            case (.afetoVoz, false):
                resposta = try await chamarSoNiveis(GrupoAfetoVozN.self, instrucoes: instrucoes,
                                                    pedido: pedido, opcoes: opcoes,
                                                    deterministico: deterministico, config: config)
            case (.narrativaEstrutura, true):
                resposta = try await chamarComEvidencia(GrupoNarrativaEstrutura.self, instrucoes: instrucoes,
                                                        pedido: pedido, opcoes: opcoes,
                                                        deterministico: deterministico, config: config)
            case (.narrativaEstrutura, false):
                resposta = try await chamarSoNiveis(GrupoNarrativaEstruturaN.self, instrucoes: instrucoes,
                                                    pedido: pedido, opcoes: opcoes,
                                                    deterministico: deterministico, config: config)
            case (.sensorial, true):
                resposta = try await chamarComEvidencia(GrupoSensorial.self, instrucoes: instrucoes,
                                                        pedido: pedido, opcoes: opcoes,
                                                        deterministico: deterministico, config: config)
            case (.sensorial, false):
                resposta = try await chamarSoNiveis(GrupoSensorialN.self, instrucoes: instrucoes,
                                                    pedido: pedido, opcoes: opcoes,
                                                    deterministico: deterministico, config: config)
            }
        }
        let chamada = ChamadaExecucao(rotulo: g.titulo,
                                      segundos: (ContinuousClock.now - inicio).segundos,
                                      caracteresPrompt: instrucoes.count + pedido.count,
                                      tokensEntrada: resposta.tokensEntrada,
                                      tokensEntradaCache: resposta.tokensEntradaCache,
                                      tokensSaida: resposta.tokensSaida,
                                      variantePrompt: selecionada.variante,
                                      tokensPromptEstimados: selecionada.tokensPromptEstimados,
                                      contextSize: selecionada.contextSize)
        return (resposta, chamada)
    }

    private func executarUma(texto: String, numero: Int, de total: Int, modo: ModoChamadas,
                             estrutura: EstruturaResposta, comEvidencia solicitada: Bool,
                             deterministico: Bool, prefixo: String = "",
                             config: ConfiguracaoProvedor,
                             orcamento: OrcamentoChamadas? = nil,
                             prioridade: PrioridadeChamada = .diagnostico) async throws -> Execucao {
        try Task.checkCancellation()
        let comEvidencia = estrutura == .partes ? true : solicitada
        let opcoes = config.opcoes(deterministico: deterministico)
        orcamentoEmUso = config.provedor == .gemini ? orcamento : nil
        prioridadeEmUso = prioridade
        defer {
            orcamentoEmUso = nil
            prioridadeEmUso = .diagnostico
        }
        let fria = !jaExecutou
        var resultados: [String: ResultadoParametro] = [:]
        var chamadas: [ChamadaExecucao] = []
        let base = prefixo.isEmpty ? "Execução \(numero) de \(total)" : "\(prefixo) · \(numero)/\(total)"
        let pedido = Instrucoes.pedido(texto)

        switch modo {
        case .umaChamada:
            progresso = "\(base) · todos os parâmetros"
            let defs = Catalogo.todos
            let schema = estrutura == .partes
                ? RespostaPartes.generationSchema
                : (comEvidencia ? TodosLeituras.generationSchema : TodosNiveis.generationSchema)
            let selecionada = await selecionarInstrucoes(defs: defs, estrutura: estrutura,
                                                         comEvidencia: comEvidencia,
                                                         schema: schema,
                                                         pedido: pedido, config: config)
            let instrucoes = selecionada.texto
            let inicio = ContinuousClock.now
            let resposta: Resposta
            if estrutura == .partes {
                resposta = try await chamarPartes(RespostaPartes.self, instrucoes: instrucoes,
                                                  pedido: pedido, opcoes: opcoes,
                                                  deterministico: deterministico, config: config)
            } else if comEvidencia {
                resposta = try await chamarComEvidencia(TodosLeituras.self, instrucoes: instrucoes,
                                                        pedido: pedido, opcoes: opcoes,
                                                        deterministico: deterministico, config: config)
            } else {
                resposta = try await chamarSoNiveis(TodosNiveis.self, instrucoes: instrucoes,
                                                    pedido: pedido, opcoes: opcoes,
                                                    deterministico: deterministico, config: config)
            }
            chamadas.append(ChamadaExecucao(rotulo: "Todos os parâmetros",
                                            segundos: (ContinuousClock.now - inicio).segundos,
                                            caracteresPrompt: instrucoes.count + pedido.count,
                                            tokensEntrada: resposta.tokensEntrada,
                                            tokensEntradaCache: resposta.tokensEntradaCache,
                                            tokensSaida: resposta.tokensSaida,
                                            variantePrompt: selecionada.variante,
                                            tokensPromptEstimados: selecionada.tokensPromptEstimados,
                                            contextSize: selecionada.contextSize))
            Self.aplicar(resposta, em: &resultados, texto: texto, definicoes: defs)

        case .porGrupo:
            for g in GrupoChamada.allCases {
                try Task.checkCancellation()
                let item = try await executarGrupo(g, estrutura: estrutura,
                                                   comEvidencia: comEvidencia, pedido: pedido,
                                                   opcoes: opcoes, deterministico: deterministico,
                                                   config: config, base: base)
                chamadas.append(item.1)
                Self.aplicar(item.0, em: &resultados, texto: texto,
                             definicoes: Catalogo.definicoes(do: g))
            }

        case .porParametro:
            for (k, d) in Catalogo.todos.enumerated() {
                try Task.checkCancellation()
                progresso = "\(base) · \(d.nome) (\(k + 1)/\(Catalogo.todos.count))"
                let instrucoes = Instrucoes.sistema(defs: [d], comEvidencia: comEvidencia,
                                                    estrutura: estrutura)
                let inicio = ContinuousClock.now
                let resposta: Resposta
                if estrutura == .partes {
                    let r = try await responder(RespostaPartesParametro.self,
                                                instrucoes: instrucoes, pedido: pedido,
                                                opcoes: opcoes, deterministico: deterministico,
                                                config: config, contexto: d.id)
                    let partes = r.content.partes.map {
                        ParteBruta(parametro: d.id, inicio: $0.inicio, fim: $0.fim,
                                   nivel: $0.nivel, nucleos: $0.nucleos)
                    }
                    resposta = Resposta(leituras: [:], partes: [d.id: partes],
                                        tokensEntrada: r.tokensEntrada,
                                        tokensEntradaCache: r.tokensEntradaCache,
                                        tokensSaida: r.tokensSaida)
                } else {
                    let bruta: LeituraBruta
                    var tokensEntrada: Int?
                    var tokensEntradaCache: Int?
                    var tokensSaida: Int?
                    if comEvidencia {
                        switch d.escala {
                        case .bipolar:
                            let r = try await responder(Leitura.self,
                                                        instrucoes: instrucoes, pedido: pedido,
                                                        opcoes: opcoes, deterministico: deterministico,
                                                        config: config, contexto: d.id)
                            bruta = LeituraBruta(evidencia: r.content.evidencia, nivel: r.content.nivel)
                            (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                        case .unipolar:
                            let r = try await responder(LeituraUnipolar.self,
                                                        instrucoes: instrucoes, pedido: pedido,
                                                        opcoes: opcoes, deterministico: deterministico,
                                                        config: config, contexto: d.id)
                            bruta = LeituraBruta(evidencia: r.content.evidencia, nivel: r.content.nivel)
                            (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                        }
                    } else {
                        switch d.escala {
                        case .bipolar:
                            let r = try await responder(Nivel.self,
                                                        instrucoes: instrucoes, pedido: pedido,
                                                        opcoes: opcoes, deterministico: deterministico,
                                                        config: config, contexto: d.id)
                            bruta = LeituraBruta(evidencia: nil, nivel: r.content.nivel)
                            (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                        case .unipolar:
                            let r = try await responder(NivelUnipolar.self,
                                                        instrucoes: instrucoes, pedido: pedido,
                                                        opcoes: opcoes, deterministico: deterministico,
                                                        config: config, contexto: d.id)
                            bruta = LeituraBruta(evidencia: nil, nivel: r.content.nivel)
                            (tokensEntrada, tokensEntradaCache, tokensSaida) = (r.tokensEntrada, r.tokensEntradaCache, r.tokensSaida)
                        }
                    }
                    resposta = Resposta(leituras: [d.id: bruta],
                                        tokensEntrada: tokensEntrada,
                                        tokensEntradaCache: tokensEntradaCache,
                                        tokensSaida: tokensSaida)
                }
                chamadas.append(ChamadaExecucao(rotulo: d.nome,
                                                segundos: (ContinuousClock.now - inicio).segundos,
                                                caracteresPrompt: instrucoes.count + pedido.count,
                                                tokensEntrada: resposta.tokensEntrada,
                                                tokensEntradaCache: resposta.tokensEntradaCache,
                                                tokensSaida: resposta.tokensSaida))
                Self.aplicar(resposta, em: &resultados, texto: texto, definicoes: [d])
            }
        }

        jaExecutou = true
        return Execucao(numero: numero, texto: texto, modo: modo, estrutura: estrutura,
                        comEvidencia: comEvidencia,
                        deterministico: deterministico, provedor: config.provedor, modelo: config.modelo,
                        resultados: resultados, chamadas: chamadas, fria: fria)
    }

    private static func schema(do grupo: GrupoChamada, estrutura: EstruturaResposta,
                               comEvidencia: Bool) -> GenerationSchema {
        if estrutura == .partes { return RespostaPartes.generationSchema }
        switch (grupo, comEvidencia) {
        case (.afetoVoz, true): return GrupoAfetoVoz.generationSchema
        case (.afetoVoz, false): return GrupoAfetoVozN.generationSchema
        case (.narrativaEstrutura, true): return GrupoNarrativaEstrutura.generationSchema
        case (.narrativaEstrutura, false): return GrupoNarrativaEstruturaN.generationSchema
        case (.sensorial, true): return GrupoSensorial.generationSchema
        case (.sensorial, false): return GrupoSensorialN.generationSchema
        }
    }

    private func selecionarInstrucoes(defs: [DefinicaoParametro], estrutura: EstruturaResposta,
                                      comEvidencia: Bool, schema: GenerationSchema,
                                      pedido: String, config: ConfiguracaoProvedor) async -> InstrucoesSelecionadas {
        let contextSize = config.contextSize
        let reserva = estrutura == .partes ? 1500 : (comEvidencia ? 900 : 500)
        let schemaTokens = 0
        let pedidoTokens = max(1, pedido.count / 4)
        let disponivel = max(0, contextSize - reserva - schemaTokens - pedidoTokens)

        let completo = Instrucoes.sistema(defs: defs, comEvidencia: comEvidencia, estrutura: estrutura)
        let tokensCompleto = await config.estimarTokens(completo)
        if tokensCompleto <= disponivel {
            return InstrucoesSelecionadas(texto: completo, variante: nil,
                                          tokensPromptEstimados: tokensCompleto + schemaTokens + pedidoTokens,
                                          contextSize: contextSize)
        }

        for variante in VarianteCompacta.allCases {
            let texto = Instrucoes.sistemaCompacto(defs: defs, comEvidencia: comEvidencia,
                                                   variante: variante, estrutura: estrutura)
            let tokens = await config.estimarTokens(texto)
            if tokens <= disponivel {
                return InstrucoesSelecionadas(texto: texto, variante: variante,
                                              tokensPromptEstimados: tokens + schemaTokens + pedidoTokens,
                                              contextSize: contextSize)
            }
        }

        let texto = Instrucoes.sistemaCompacto(defs: defs, comEvidencia: comEvidencia,
                                               variante: .semExemplos, estrutura: estrutura)
        let tokens = await config.estimarTokens(texto)
        return InstrucoesSelecionadas(texto: texto, variante: .semExemplos,
                                      tokensPromptEstimados: tokens + schemaTokens + pedidoTokens,
                                      contextSize: contextSize)
    }

    private func responder<T: Generable>(
        _ tipo: T.Type,
        instrucoes: String,
        pedido: String,
        opcoes: GenerationOptions,
        deterministico: Bool,
        config: ConfiguracaoProvedor,
        contexto: String
    ) async throws -> RespostaModelo<T> {
        try await comRetentativa(contexto: contexto) {
            try await config.responder(instructions: instrucoes, prompt: pedido,
                                       generating: tipo, deterministico: deterministico,
                                       opcoes: opcoes)
        }
    }

    private func comRetentativa<T>(
        contexto: String,
        _ operacao: () async throws -> T
    ) async throws -> T {
        let maxTentativas = 3
        var ultimoErro: Error?

        for tentativa in 1...maxTentativas {
            try Task.checkCancellation()
            if let orcamento = orcamentoEmUso {
                progresso = "\(contexto) · aguardando vaga na cota"
                try await orcamento.reservar(1, prioridade: prioridadeEmUso)
            }
            do {
                let resultado = try await operacao()
                orcamentoEmUso?.registrarSucesso()
                return resultado
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                ultimoErro = error
                if let orcamento = orcamentoEmUso, ehLimiteDeCota(error) {
                    orcamento.registrarRecusaDeLimite()
                }
                let diagnostico = Self.descricaoDiagnostica(de: error)
                let texto = "Gemini falhou em \(contexto), tentativa \(tentativa)/\(maxTentativas): \(diagnostico)"
                logGemini.error("\(texto, privacy: .public)")

                guard erroRetentavel(error), tentativa < maxTentativas else {
                    throw error
                }

                let espera = pow(2.0, Double(tentativa - 1)) + Double.random(in: 0...0.3)
                progresso = "\(contexto) · nova tentativa \(tentativa + 1)/\(maxTentativas) "
                    + "em \(String(format: "%.1f", espera))s"
                try await Task.sleep(for: .seconds(espera))
            }
        }

        throw ultimoErro ?? CancellationError()
    }

    private func ehLimiteDeCota(_ erro: Error) -> Bool {
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            if let e = erro as? ChatCompletionsLanguageModel.RequestError {
                if case .httpError(let statusCode, let data) = e {
                    if statusCode == 429 { return true }
                    let corpo = String(data: data, encoding: .utf8)?.lowercased() ?? ""
                    return corpo.contains("quota")
                        || corpo.contains("rate")
                        || corpo.contains("resource_exhausted")
                }
            }
            if let e = erro as? ChatCompletionsLanguageModel.APIError {
                let texto = "\(e.code ?? "") \(e.type ?? "") \(e.message)".lowercased()
                return texto.contains("quota")
                    || texto.contains("rate")
                    || texto.contains("resource_exhausted")
            }
            if let e = erro as? LanguageModelError, case .rateLimited = e { return true }
        }
        if case let erro as ChatCompletionsLanguageModel.RequestError = erro {
            if case .httpError(let statusCode, let data) = erro {
                if statusCode == 429 { return true }
                let corpo = String(data: data, encoding: .utf8)?.lowercased() ?? ""
                return corpo.contains("quota")
                    || corpo.contains("rate")
                    || corpo.contains("resource_exhausted")
            }
        }
        if case let erro as ChatCompletionsLanguageModel.APIError = erro {
            let texto = "\(erro.code ?? "") \(erro.type ?? "") \(erro.message)".lowercased()
            return texto.contains("quota")
                || texto.contains("rate")
                || texto.contains("resource_exhausted")
        }
        return false
    }

    private func erroRetentavel(_ erro: Error) -> Bool {
        if erro is CancellationError { return false }
        if erro is ErroOrcamento { return false }

        if let e = erro as? ChatCompletionsLanguageModel.RequestError {
            switch e {
            case .httpError(let statusCode, _):
                return statusCode == 408 || statusCode == 425 || statusCode == 429
                    || (500...599).contains(statusCode)
            case .incompleteStream, .outputTruncated, .emptyResponse, .invalidStreamData:
                return true
            case .invalidRequest, .contentFiltered:
                return false
            }
        }

        if let e = erro as? ChatCompletionsLanguageModel.APIError {
            let texto = "\(e.code ?? "") \(e.type ?? "") \(e.message)".lowercased()
            return texto.contains("unavailable")
                || texto.contains("overloaded")
                || texto.contains("high demand")
                || texto.contains("rate")
                || texto.contains("temporar")
                || texto.contains("resource_exhausted")
        }

        if let e = erro as? URLError {
            return e.code != .cancelled && e.code != .userCancelledAuthentication
        }

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            if let e = erro as? LanguageModelError {
                switch e {
                case .rateLimited, .timeout:
                    return true
                default:
                    return false
                }
            }
            if erro is GeneratedContent.ParsingError {
                return true
            }
        }

        return false
    }

    private static func descricaoDiagnostica(de erro: Error) -> String {
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            if let e = erro as? GeneratedContent.ParsingError {
                let trecho = e.rawContent.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)
                return "ParsingError; trecho=\(trecho)"
            }
            if let e = erro as? ChatCompletionsLanguageModel.RequestError {
                if case .httpError(let statusCode, let data) = e {
                    let corpo = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
                    return "HTTP \(statusCode); corpo=\(corpo)"
                }
            }
        }
        return erro.localizedDescription
    }

    private func chamarComEvidencia<T: GrupoLeituras>(_ tipo: T.Type, instrucoes: String, pedido: String,
                                                      opcoes: GenerationOptions,
                                                      deterministico: Bool,
                                                      config: ConfiguracaoProvedor) async throws -> Resposta {
        let r = try await responder(tipo, instrucoes: instrucoes, pedido: pedido,
                                    opcoes: opcoes, deterministico: deterministico,
                                    config: config, contexto: "com evidência")
        return Resposta(
            leituras: r.content.leituras.mapValues { LeituraBruta(evidencia: $0.evidencia, nivel: $0.nivel) },
            tokensEntrada: r.tokensEntrada,
            tokensEntradaCache: r.tokensEntradaCache,
            tokensSaida: r.tokensSaida
        )
    }

    private func chamarSoNiveis<T: GrupoNiveis>(_ tipo: T.Type, instrucoes: String, pedido: String,
                                                opcoes: GenerationOptions,
                                                deterministico: Bool,
                                                config: ConfiguracaoProvedor) async throws -> Resposta {
        let r = try await responder(tipo, instrucoes: instrucoes, pedido: pedido,
                                    opcoes: opcoes, deterministico: deterministico,
                                    config: config, contexto: "só níveis")
        return Resposta(
            leituras: r.content.niveis.mapValues { LeituraBruta(evidencia: nil, nivel: $0.nivel) },
            tokensEntrada: r.tokensEntrada,
            tokensEntradaCache: r.tokensEntradaCache,
            tokensSaida: r.tokensSaida
        )
    }

    private func chamarPartes(_ tipo: RespostaPartes.Type, instrucoes: String, pedido: String,
                              opcoes: GenerationOptions,
                              deterministico: Bool,
                              config: ConfiguracaoProvedor) async throws -> Resposta {
        let r = try await responder(tipo, instrucoes: instrucoes, pedido: pedido,
                                    opcoes: opcoes, deterministico: deterministico,
                                    config: config, contexto: "partes")
        var porParametro: [String: [ParteBruta]] = [:]
        for parte in r.content.partes {
            let chave = Self.normalizar(parte.parametro)
            guard !chave.isEmpty else { continue }
            porParametro[chave, default: []].append(
                ParteBruta(parametro: chave, inicio: parte.inicio, fim: parte.fim,
                           nivel: parte.nivel, nucleos: parte.nucleos)
            )
        }
        return Resposta(
            leituras: [:],
            partes: porParametro,
            tokensEntrada: r.tokensEntrada,
            tokensEntradaCache: r.tokensEntradaCache,
            tokensSaida: r.tokensSaida
        )
    }

    // MARK: - Verificação da evidência

    private static func resultado(de b: LeituraBruta, texto: String, definicao: DefinicaoParametro) -> ResultadoParametro {
        let escala = definicao.escala
        let minimo = escala == .unipolar ? 0 : -5
        let nivel = max(minimo, min(5, b.nivel))
        guard let ev = b.evidencia else {
            return ResultadoParametro(nivel: nivel, evidencia: nil, contradicao: false, naoLiteral: false)
        }
        if nivel == 0 {
            return ResultadoParametro(nivel: 0, evidencia: ev, contradicao: false, naoLiteral: false)
        }
        let norm = normalizar(ev)
        let semEvidencia = norm.isEmpty || norm == "nenhuma" || norm == "nenhum"
        if semEvidencia {
            return ResultadoParametro(nivel: nivel, evidencia: ev, contradicao: true, naoLiteral: false)
        }
        return ResultadoParametro(nivel: nivel, evidencia: ev, contradicao: false,
                                  naoLiteral: !citacaoLiteral(ev, em: texto))
    }

    /// Converte uma resposta crua em resultados por parâmetro, cobrindo tanto a
    /// estrutura por níveis quanto a estrutura por partes.
    private static func aplicar(_ resposta: Resposta, em resultados: inout [String: ResultadoParametro],
                                texto: String, definicoes: [DefinicaoParametro]) {
        for def in definicoes {
            resultados[def.id] = ResultadoParametro(nivel: 0, evidencia: nil,
                                                    contradicao: false, naoLiteral: false)
        }
        for (id, leitura) in resposta.leituras {
            guard let def = Catalogo.porID[id] else { continue }
            resultados[id] = resultado(de: leitura, texto: texto, definicao: def)
        }
        for def in definicoes {
            guard let brutas = resposta.partes[def.id] else { continue }
            resultados[def.id] = resultadoPartes(de: brutas, texto: texto, definicao: def)
        }
    }

    private static func resultadoPartes(de brutas: [ParteBruta], texto: String,
                                        definicao: DefinicaoParametro) -> ResultadoParametro {
        let tokens = tokensDoTexto(texto)
        let escala = definicao.escala
        let minimo = escala == .unipolar ? 0 : -5
        var partes: [ParteIntervalo] = []
        var algumaNaoLiteral = false

        for bruta in brutas.prefix(6) {
            let nivel = max(minimo, min(5, bruta.nivel))
            if nivel == 0 && escala == .bipolar { continue }
            guard let inicioToken = localizar(bruta.inicio, em: tokens),
                  let fimToken = localizar(bruta.fim, em: tokens, aPartirDe: inicioToken.lowerBound),
                  fimToken.lowerBound >= inicioToken.lowerBound else {
                algumaNaoLiteral = true
                continue
            }
            let inicioUTF16 = tokens[inicioToken.lowerBound].inicioUTF16
            let fimUTF16 = tokens[fimToken.upperBound - 1].fimUTF16
            guard fimUTF16 > inicioUTF16 || inicioToken == fimToken else {
                algumaNaoLiteral = true
                continue
            }

            var nucleos: [Range<Int>] = []
            var nucleosTexto: [String] = []
            for nucleo in bruta.nucleos.prefix(4) {
                guard let n = localizar(nucleo, em: tokens, aPartirDe: inicioToken.lowerBound),
                      n.upperBound <= fimToken.upperBound else { continue }
                nucleos.append(tokens[n.lowerBound].inicioUTF16..<tokens[n.upperBound - 1].fimUTF16)
                nucleosTexto.append(nucleo)
            }

            let primeiroToken = tokens[inicioToken.lowerBound]
            let ultimoToken = tokens[fimToken.upperBound - 1]
            let parte = ParteIntervalo(inicioUTF16: inicioUTF16, fimUTF16: fimUTF16, nivel: nivel,
                                       nucleos: nucleos, nucleosTexto: nucleosTexto,
                                       inicioTexto: Self.texto(de: primeiroToken.inicioUTF16..<primeiroToken.fimUTF16,
                                                               em: texto) ?? bruta.inicio,
                                       fimTexto: Self.texto(de: ultimoToken.inicioUTF16..<ultimoToken.fimUTF16,
                                                            em: texto) ?? bruta.fim)
            if !partes.contains(where: { $0.inicioUTF16 == parte.inicioUTF16
                && $0.fimUTF16 == parte.fimUTF16 && $0.nivel == parte.nivel }) {
                partes.append(parte)
            }
        }

        guard !partes.isEmpty else {
            return ResultadoParametro(nivel: 0, evidencia: nil, contradicao: false,
                                      naoLiteral: algumaNaoLiteral, partes: [])
        }
        var dominante = partes[0]
        for parte in partes.dropFirst() where abs(parte.nivel) > abs(dominante.nivel) {
            dominante = parte
        }
        let evidencia = dominante.inicioTexto == dominante.fimTexto
            ? dominante.inicioTexto
            : "\(dominante.inicioTexto)…\(dominante.fimTexto)"
        return ResultadoParametro(nivel: dominante.nivel, evidencia: evidencia, contradicao: false,
                                  naoLiteral: algumaNaoLiteral, partes: partes)
    }

    // MARK: - Localização de trechos no texto

    private struct TokenTexto {
        let inicioUTF16: Int
        let fimUTF16: Int
        let normalizado: String
    }

    private static func texto(de faixa: Range<Int>, em texto: String) -> String? {
        let utf16 = texto.utf16
        guard faixa.lowerBound >= 0, faixa.upperBound <= utf16.count,
              let inicio = utf16.index(utf16.startIndex, offsetBy: faixa.lowerBound,
                                       limitedBy: utf16.endIndex),
              let fim = utf16.index(inicio, offsetBy: faixa.upperBound - faixa.lowerBound,
                                    limitedBy: utf16.endIndex) else { return nil }
        return String(decoding: utf16[inicio..<fim], as: UTF16.self)
    }

    private static func tokensDoTexto(_ texto: String) -> [TokenTexto] {
        var tokens: [TokenTexto] = []
        texto.enumerateSubstrings(in: texto.startIndex..<texto.endIndex,
                                  options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            let inicio = range.lowerBound.utf16Offset(in: texto)
            let fim = range.upperBound.utf16Offset(in: texto)
            tokens.append(TokenTexto(inicioUTF16: inicio, fimUTF16: fim,
                                     normalizado: normalizar(String(texto[range]))))
        }
        return tokens
    }

    /// Localiza uma citação como sequência de palavras normalizadas e devolve
    /// o intervalo de tokens correspondente.
    private static func localizar(_ citacao: String, em tokens: [TokenTexto],
                                  aPartirDe inicio: Int = 0) -> Range<Int>? {
        let alvo = normalizar(citacao).split(separator: " ").map(String.init)
        guard !alvo.isEmpty, inicio >= 0, inicio < tokens.count,
              alvo.count <= tokens.count - inicio else { return nil }
        for i in inicio...(tokens.count - alvo.count) {
            if (0..<alvo.count).allSatisfy({ tokens[i + $0].normalizado == alvo[$0] }) {
                return i..<(i + alvo.count)
            }
        }
        return nil
    }

    /// Confere se a citação do modelo aparece no texto (ignorando maiúsculas, acentos e pontuação).
    /// Citações com reticências são aceitas se todas as partes aparecem.
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

    static func normalizar(_ s: String) -> String {
        normalizarTexto(s)
    }

    private func mensagem(para erro: Error) -> String {
        if let e = erro as? ChatCompletionsLanguageModel.RequestError {
            switch e {
            case .invalidRequest(let descricao):
                return "Requisição inválida para o provedor: \(descricao)"
            case .invalidStreamData:
                return "Resposta inválida do provedor (stream)."
            case .httpError(let statusCode, let data):
                let corpo = String(data: data, encoding: .utf8) ?? ""
                switch statusCode {
                case 400:
                    return "O provedor rejeitou a requisição (400). \(corpo)"
                case 401, 403:
                    return "Chave da API inválida ou sem permissão (\(statusCode))."
                case 404:
                    return "Endpoint ou modelo não encontrado (404). Confira o nome do modelo."
                case 429:
                    return "Limite de requisições do provedor atingido (429). Aguarde alguns segundos/minutos."
                default:
                    return "Erro HTTP \(statusCode) do provedor. \(corpo)"
                }
            case .incompleteStream:
                return "A resposta do provedor foi interrompida antes do fim (stream incompleto)."
            case .outputTruncated(let caracteres):
                return "A resposta foi cortada no limite de tokens após \(caracteres) caracteres."
            case .emptyResponse:
                return "O provedor retornou uma resposta vazia."
            case .contentFiltered:
                return "O conteúdo foi bloqueado pelo filtro do provedor."
            }
        }
        if let e = erro as? ChatCompletionsLanguageModel.APIError {
            return "Erro do provedor: \(e.message)"
        }
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            if let e = erro as? GeneratedContent.ParsingError {
                let trecho = e.rawContent.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)
                return "Resposta do modelo não pôde ser decodificada. Trecho recebido: \(trecho)"
            }
        }
        if let e = erro as? URLError {
            return "Falha de rede: \(e.localizedDescription)"
        }
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            if let e = erro as? LanguageModelError {
                switch e {
                case .contextSizeExceeded(let info):
                    return "Prompt com \(info.tokenCount) tokens excede a janela de \(info.contextSize). Reduza o texto ou use um modo mais compacto."
                case .guardrailViolation:
                    return "O conteúdo foi bloqueado pelos guardrails do modelo."
                case .unsupportedLanguageOrLocale:
                    return "Idioma ou região não suportados. Confira o idioma do aparelho e da Apple Intelligence."
                case .rateLimited:
                    return "O modelo está limitando a taxa de requisições. Tente novamente em instantes."
                case .refusal:
                    return "O modelo recusou a geração."
                default:
                    return "Erro de geração: \(e.localizedDescription)"
                }
            }
        }
        return "Erro: \(erro.localizedDescription)"
    }

    // MARK: - Estatísticas do lote

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

    /// Execuções sem partida a frio na mesma configuração e no mesmo texto.
    func execucoesAquecidas(modo: ModoChamadas, estrutura: EstruturaResposta,
                            comEvidencia: Bool, deterministico: Bool,
                            texto: String? = nil) -> [Execucao] {
        let config = configuracao
        return execucoes.filter {
            !$0.fria && $0.provedor == config.provedor && $0.modelo == config.modelo
                && $0.modo == modo && $0.estrutura == estrutura && $0.comEvidencia == comEvidencia
                && $0.deterministico == deterministico && (texto == nil || $0.texto == texto)
        }
    }

    /// Latências totais (soma das chamadas) das execuções sem partida a frio, na mesma configuração.
    func latenciasQuentes(modo: ModoChamadas, estrutura: EstruturaResposta,
                          comEvidencia: Bool, deterministico: Bool,
                          texto: String? = nil) -> [Double] {
        execucoesAquecidas(modo: modo, estrutura: estrutura, comEvidencia: comEvidencia,
                           deterministico: deterministico, texto: texto).map(\.segundos)
    }

    private static let configuracoesDeEstrutura: [(EstruturaResposta, Bool)] = [
        (.niveis, true), (.niveis, false), (.partes, true)
    ]

    /// Compara todas as configurações usando apenas execuções aquecidas do mesmo texto.
    func resumosPorConfiguracao(texto: String) -> [ResumoConfiguracao] {
        Self.configuracoesDeEstrutura.flatMap { estrutura, evidencia in
            ModoChamadas.allCases.flatMap { modo in
                [true, false].compactMap { deterministico -> ResumoConfiguracao? in
                    let execs = execucoesAquecidas(modo: modo, estrutura: estrutura,
                                                   comEvidencia: evidencia,
                                                   deterministico: deterministico, texto: texto)
                    guard !execs.isEmpty else { return nil }
                    let latencias = execs.map(\.segundos)
                    return ResumoConfiguracao(modo: modo, estrutura: estrutura,
                                              comEvidencia: evidencia,
                                              deterministico: deterministico,
                                              amostras: execs.count,
                                              media: latencias.reduce(0, +) / Double(latencias.count),
                                              minima: latencias.min() ?? 0,
                                              maxima: latencias.max() ?? 0,
                                              mediaTokensEntrada: Double(execs.map(\.tokensEntrada).reduce(0, +)) / Double(execs.count),
                                              mediaTokensSaida: Double(execs.map(\.tokensSaida).reduce(0, +)) / Double(execs.count))
                }
            }
        }
    }

    // MARK: - Comparação de resultados

    func configuracoesDisponiveis(texto: String) -> [ConfiguracaoResultado] {
        Self.configuracoesDeEstrutura.flatMap { estrutura, evidencia in
            ModoChamadas.allCases.flatMap { modo in
                [true, false].compactMap { deterministico -> ConfiguracaoResultado? in
                    let c = ConfiguracaoResultado(modo: modo, estrutura: estrutura,
                                                  comEvidencia: evidencia,
                                                  deterministico: deterministico)
                    return ultimaExecucao(c, texto: texto) == nil ? nil : c
                }
            }
        }
    }

    func comparar(texto: String, referencia: ConfiguracaoResultado? = nil) -> ComparacaoResultados? {
        let configs = configuracoesDisponiveis(texto: texto)
        guard !configs.isEmpty else { return nil }
        let ref = referencia.flatMap { configs.contains($0) ? $0 : nil }
            ?? configs.first { $0.modo == .porParametro && $0.estrutura == .niveis && $0.comEvidencia && $0.deterministico == deterministicoNoLote }
            ?? configs.first { $0.modo == .porParametro && $0.estrutura == .niveis && $0.comEvidencia }
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
            var exatos = 0
            var comparaveis = 0
            var soma = 0.0
            var sinais = 0
            for d in Catalogo.todos {
                guard let a = refExec.resultados[d.id]?.nivel, let b = e.resultados[d.id]?.nivel else { continue }
                comparaveis += 1
                if a == b { exatos += 1 }
                soma += Double(abs(a - b))
                if Self.sinal(a, d.escala) == Self.sinal(b, d.escala) { sinais += 1 }
            }
            return MetricaComparacao(configuracao: c, exatos: exatos, comparaveis: comparaveis,
                                     diferencaMedia: comparaveis > 0 ? soma / Double(comparaveis) : 0,
                                     concordanciaSinal: comparaveis > 0 ? Double(sinais) / Double(comparaveis) : 0)
        }

        return ComparacaoResultados(referencia: ref, configuracoes: configs, linhas: linhas, metricas: metricas)
    }

    private func ultimaExecucao(_ c: ConfiguracaoResultado, texto: String) -> Execucao? {
        let config = configuracao
        return execucoes.last {
            $0.provedor == config.provedor && $0.modelo == config.modelo
                && $0.texto == texto && $0.modo == c.modo && $0.estrutura == c.estrutura
                && $0.comEvidencia == c.comEvidencia
                && $0.deterministico == c.deterministico
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
                    "contradicao": r.contradicao,
                    "citacao_nao_literal": r.naoLiteral,
                    "partes": r.partes.map { p in
                        [
                            "inicio_utf16": p.inicioUTF16,
                            "fim_utf16": p.fimUTF16,
                            "inicio": p.inicioTexto,
                            "fim": p.fimTexto,
                            "nivel": p.nivel,
                            "nucleos": p.nucleosTexto,
                            "nucleos_faixas": p.nucleos.map {
                                ["inicio_utf16": $0.lowerBound, "fim_utf16": $0.upperBound]
                            }
                        ] as [String: Any]
                    }
                ] as [String: Any])
            })
            let chamadas: [[String: Any]] = e.chamadas.map { c in
                [
                    "rotulo": c.rotulo,
                    "segundos": c.segundos,
                    "caracteres_prompt": c.caracteresPrompt,
                    "tokens_entrada": c.tokensEntrada ?? NSNull(),
                    "tokens_entrada_cache": c.tokensEntradaCache ?? NSNull(),
                    "tokens_saida": c.tokensSaida ?? NSNull(),
                    "variante_prompt": c.variantePrompt?.rawValue ?? NSNull(),
                    "tokens_prompt_estimados": c.tokensPromptEstimados ?? NSNull(),
                    "context_size": c.contextSize ?? NSNull()
                ] as [String: Any]
            }
            return [
                "execucao": e.numero,
                "provedor": e.provedor.rawValue,
                "modelo": e.modelo,
                "modo": e.modo.rawValue,
                "estrutura": e.estrutura.tituloCurto,
                "com_evidencia": e.comEvidencia,
                "latencia_total_s": e.segundos,
                "latencia_por_chamada_s": e.chamadas.map(\.segundos),
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
        let falhas: [[String: Any]] = falhasDoClique.map { f in
            [
                "provedor": f.provedor.rawValue,
                "modelo": f.modelo,
                "modo": f.modo.rawValue,
                "estrutura": f.estrutura.tituloCurto,
                "com_evidencia": f.comEvidencia,
                "mensagem": f.mensagem
            ]
        }
        let raiz: [String: Any] = [
            "texto": textoDoLote,
            "caracteres": textoDoLote.count,
            "provedor": provedorDoLote.rawValue,
            "modelo": modeloDoLote,
            "modo": modoDoLote.rawValue,
            "estrutura": estruturaNoLote.tituloCurto,
            "com_evidencia": evidenciaNoLote,
            "deterministico": deterministicoNoLote,
            "falhas": falhas,
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

        let textoBase = lote.last?.texto ?? ""
        let faixas = Self.faixasDosTokens(tokens: tokens, em: textoBase)
        let flatParts = Self.achatarTokens(tokens)
        var somasPorPalavra = Array(
            repeating: Dictionary(uniqueKeysWithValues: MorphParameter.allCases.map { ($0, 0.0) }),
            count: tokens.count
        )

        for exec in lote {
            for param in MorphParameter.allCases {
                guard let res = exec.resultados[param.catalogoId] else { continue }

                if res.contradicao && filtros.zerarContradicoes { continue }
                if res.naoLiteral && filtros.zerarNaoLiterais { continue }

                if exec.estrutura == .partes, !res.partes.isEmpty {
                    guard !faixas.isEmpty else { continue }
                    for (idx, faixa) in faixas.enumerated() {
                        var melhorNivel: Int?
                        for parte in res.partes {
                            let intersecta = max(parte.inicioUTF16, faixa.lowerBound)
                                < min(parte.fimUTF16, faixa.upperBound)
                            guard intersecta, abs(parte.nivel) >= filtros.limiar else { continue }
                            if let atual = melhorNivel {
                                if abs(parte.nivel) > abs(atual) { melhorNivel = parte.nivel }
                            } else {
                                melhorNivel = parte.nivel
                            }
                        }
                        if let nivel = melhorNivel, nivel != 0 {
                            somasPorPalavra[idx][param, default: 0] += Double(nivel)
                        }
                    }
                    continue
                }

                if !exec.comEvidencia {
                    let nivelGlobal = Int((res.valorEfetivo(filtros) * 5.0).rounded())
                    if nivelGlobal != 0 {
                        for idx in tokens.indices {
                            somasPorPalavra[idx][param, default: 0] += Double(nivelGlobal)
                        }
                    }
                    continue
                }

                let evidencia = res.evidencia?.trimmingCharacters(in: .whitespacesAndNewlines)
                let temEvidencia = !(evidencia ?? "").isEmpty
                    && normalizarTexto(evidencia ?? "") != "nenhuma"
                    && normalizarTexto(evidencia ?? "") != "nenhum"

                var nivelPorPalavra: [Int: Int] = [:]
                if temEvidencia {
                    let nivel = Int((res.valorEfetivo(filtros) * 5.0).rounded())
                    if nivel != 0 {
                        for idx in Self.indicesCorrespondentes(trecho: evidencia ?? "", em: flatParts) {
                            if let atual = nivelPorPalavra[idx] {
                                if abs(nivel) >= abs(atual) { nivelPorPalavra[idx] = nivel }
                            } else {
                                nivelPorPalavra[idx] = nivel
                            }
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
                    for (idx, nivel) in nivelPorPalavra {
                        somasPorPalavra[idx][param, default: 0] += Double(nivel)
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

    private static func faixasDosTokens(tokens: [String], em texto: String) -> [Range<Int>] {
        let partes = texto.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        var faixas: [Range<Int>] = []
        faixas.reserveCapacity(partes.count)
        for parte in partes {
            let inicio = parte.startIndex.utf16Offset(in: texto)
            let fim = parte.endIndex.utf16Offset(in: texto)
            faixas.append(inicio..<fim)
        }
        guard faixas.count == tokens.count else { return [] }
        return faixas
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
