import Foundation
import FoundationModels

struct ConfiguracaoProvedor: Equatable {
    var modeloGemini: String = "gemini-3.5-flash-lite"
    var chaveGemini: String = ""
    var baseURLGemini: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!

    var modelo: String { modeloGemini }

    var temChave: Bool {
        !chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var indisponibilidade: String? {
        temChave ? nil : "Informe a chave da API do Gemini nos Ajustes."
    }

    var contextSize: Int { 1_000_000 }

    func estimarTokens(_ texto: String) -> Int {
        max(1, texto.count / 4)
    }

    func opcoes(deterministico: Bool) -> GenerationOptions {
        deterministico ? GenerationOptions(temperature: 0) : GenerationOptions()
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
    func responder<T: Generable & Sendable>(
        instructions: String,
        prompt: String,
        generating tipo: T.Type,
        deterministico: Bool
    ) async throws -> RespostaModelo<T> {
        let modelo = ChatCompletionsLanguageModel(
            name: modeloGemini,
            url: baseURLGemini,
            additionalHeaders: [
                "Authorization": "Bearer \(chaveGemini.trimmingCharacters(in: .whitespacesAndNewlines))"
            ]
        )

        if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
            let sessao = LanguageModelSession(model: modelo, instructions: instructions)
            let resposta = try await sessao.respond(
                to: prompt,
                generating: tipo,
                options: opcoes(deterministico: deterministico)
            )
            return RespostaModelo(
                content: resposta.content,
                tokensEntrada: resposta.usage.input.totalTokenCount,
                tokensEntradaCache: resposta.usage.input.cachedTokenCount,
                tokensSaida: resposta.usage.output.totalTokenCount
            )
        } else {
            let resposta = try await modelo.respondDirect(
                instructions: instructions,
                prompt: prompt,
                generating: tipo,
                temperature: deterministico ? 0 : nil
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
