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
