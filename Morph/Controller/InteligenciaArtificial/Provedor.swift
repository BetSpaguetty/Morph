import Foundation
import FoundationModels

enum NivelRaciocinio: String, CaseIterable, Identifiable, Hashable {
    case minimal
    case low
    case medium
    case high

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .minimal: return "Mínimo"
        case .low: return "Baixo"
        case .medium: return "Médio"
        case .high: return "Alto"
        }
    }
}

enum Provedor: String, CaseIterable, Identifiable, Hashable {
    case gemini

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .gemini: return "Gemini (API)"
        }
    }

    var tituloCurto: String {
        switch self {
        case .gemini: return "Gemini"
        }
    }
}

struct ConfiguracaoProvedor: Equatable {
    var provedor: Provedor = .gemini
    var modeloGemini: String = "gemini-3.5-flash-lite"
    var chaveGemini: String = ""
    var baseURLGemini: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!
    var nivelRaciocinio: NivelRaciocinio = .high

    var modelo: String {
        switch provedor {
        case .gemini: return "\(modeloGemini) · \(nivelRaciocinio.titulo)"
        }
    }

    var temChave: Bool {
        !chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct RespostaModelo<T: Generable> {
    let content: T
    let tokensEntrada: Int?
    let tokensEntradaCache: Int?
    let tokensSaida: Int?
}

@MainActor
extension ConfiguracaoProvedor {
    var indisponibilidade: String? {
        switch provedor {
        case .gemini:
            return temChave ? nil : "Informe a chave da API do Gemini."
        }
    }

    var contextSize: Int {
        switch provedor {
        case .gemini: return 1_000_000
        }
    }

    func estimarTokens(_ texto: String) async -> Int {
        max(1, texto.count / 4)
    }

    func opcoes(deterministico: Bool) -> GenerationOptions {
        GenerationOptions(
            temperature: deterministico ? 0 : nil,
            maximumResponseTokens: 65_536
        )
    }

    func novaSessao(instructions: String) -> LanguageModelSession {
        guard #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) else {
            fatalError("O caminho de LanguageModelSession exige iOS/macOS 27.")
        }
        let modelo = ChatCompletionsLanguageModel(
            name: modeloGemini,
            url: baseURLGemini,
            additionalHeaders: [
                "Authorization": "Bearer \(chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines))"
            ],
            reasoningEffort: nivelRaciocinio.rawValue
        )
        return LanguageModelSession(model: modelo, instructions: instructions)
    }

    func responder<T: Generable & Sendable>(
        instructions: String,
        prompt: String,
        generating tipo: T.Type,
        deterministico: Bool,
        opcoes: GenerationOptions
    ) async throws -> RespostaModelo<T> {
        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            let sessao = novaSessao(instructions: instructions)
            let resposta = try await sessao.respond(
                to: prompt,
                generating: tipo,
                options: opcoes
            )
            return RespostaModelo(
                content: resposta.content,
                tokensEntrada: resposta.usage.input.totalTokenCount,
                tokensEntradaCache: resposta.usage.input.cachedTokenCount,
                tokensSaida: resposta.usage.output.totalTokenCount
            )
        } else {
            guard provedor == .gemini else {
                throw ChatCompletionsLanguageModel.RequestError.invalidRequest(
                    "Provedor não suportado nesta versão do sistema."
                )
            }
            let modelo = ChatCompletionsLanguageModel(
                name: modeloGemini,
                url: baseURLGemini,
                additionalHeaders: [
                    "Authorization": "Bearer \(chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines))"
                ],
                reasoningEffort: nivelRaciocinio.rawValue
            )
            let resposta = try await modelo.respondDirect(
                instructions: instructions,
                prompt: prompt,
                generating: tipo,
                temperature: deterministico ? 0 : nil,
                maxCompletionTokens: opcoes.maximumResponseTokens
            )
            return RespostaModelo(
                content: resposta.content,
                tokensEntrada: resposta.promptTokens,
                tokensEntradaCache: resposta.cachedPromptTokens,
                tokensSaida: resposta.completionTokens
            )
        }
    }
}
