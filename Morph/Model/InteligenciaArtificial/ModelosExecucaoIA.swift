import Foundation
import Observation
import FoundationModels

/// Filtros aplicados na exibição (não exigem rodar o modelo de novo).
struct Filtros {
    var zerarContradicoes = true     // evidência 'nenhuma' com nível ≠ 0
    var zerarNaoLiterais = false     // citação que não aparece literalmente no texto
    var limiar = 0                   // ignora |nível| menor que este valor
}

/// Trecho contínuo do texto ao qual um parâmetro se aplica, com nível próprio
/// e núcleos (pontos de maior intensidade) medidos em offsets UTF-16.
struct ParteIntervalo: Identifiable, Hashable, Sendable {
    let inicioUTF16: Int
    let fimUTF16: Int
    let nivel: Int
    let nucleos: [Range<Int>]        // offsets UTF-16 dentro do texto
    let nucleosTexto: [String]
    let inicioTexto: String
    let fimTexto: String

    var id: String { "\(inicioUTF16)-\(fimUTF16)-\(nivel)" }
}

struct ResultadoParametro {
    let nivel: Int               // -5...+5 (bipolar) ou 0...+5 (unipolar), nível dominante
    let evidencia: String?       // nil no modo "só números"
    let contradicao: Bool        // nível ≠ 0, mas evidência 'nenhuma'
    let naoLiteral: Bool         // nível ≠ 0, evidência presente, mas ausente do texto
    var partes: [ParteIntervalo] = []

    var valor: Double { Double(nivel) / 5.0 }   // escala exibida: -1...+1

    func valorEfetivo(_ f: Filtros) -> Double {
        if abs(nivel) < f.limiar { return 0 }
        if f.zerarContradicoes && contradicao { return 0 }
        if f.zerarNaoLiterais && naoLiteral { return 0 }
        return valor
    }
}

/// Uma chamada individual ao modelo dentro de uma execução.
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
    let estrutura: EstruturaResposta
    let comEvidencia: Bool
    let provedor: Provedor
    let modelo: String
    let mensagem: String
}

struct Execucao: Identifiable {
    let id = UUID()
    let numero: Int
    let texto: String
    let modo: ModoChamadas
    let estrutura: EstruturaResposta
    let comEvidencia: Bool
    let deterministico: Bool
    let provedor: Provedor
    let modelo: String
    let resultados: [String: ResultadoParametro]
    let chamadas: [ChamadaExecucao]
    let fria: Bool            // primeira execução desde a abertura do app (sem pré-aquecimento)

    var segundos: Double { chamadas.reduce(0) { $0 + $1.segundos } }
    var caracteresPrompt: Int { chamadas.reduce(0) { $0 + $1.caracteresPrompt } }
    var tokensEntrada: Int { chamadas.compactMap(\.tokensEntrada).reduce(0, +) }
    var tokensEntradaCache: Int { chamadas.compactMap(\.tokensEntradaCache).reduce(0, +) }
    var tokensSaida: Int { chamadas.compactMap(\.tokensSaida).reduce(0, +) }
    var contradicoes: Int { resultados.values.filter(\.contradicao).count }
    var naoLiterais: Int { resultados.values.filter(\.naoLiteral).count }
}

/// Resumo de latência por configuração, usado no painel comparativo.
struct ResumoConfiguracao: Identifiable {
    let modo: ModoChamadas
    let estrutura: EstruturaResposta
    let comEvidencia: Bool
    let deterministico: Bool
    let amostras: Int
    let media: Double
    let minima: Double
    let maxima: Double
    let mediaTokensEntrada: Double
    let mediaTokensSaida: Double

    var id: String { "\(modo.rawValue)|\(estrutura.rawValue)|\(comEvidencia)|\(deterministico)" }
}

struct ConfiguracaoResultado: Identifiable, Hashable {
    let modo: ModoChamadas
    let estrutura: EstruturaResposta
    let comEvidencia: Bool
    let deterministico: Bool

    var id: String { "\(modo.rawValue)|\(estrutura.rawValue)|\(comEvidencia)|\(deterministico)" }
    var titulo: String {
        let base = estrutura == .partes
            ? "\(modo.tituloCurto) · partes"
            : "\(modo.tituloCurto) · \(comEvidencia ? "com evidência" : "só números")"
        return base + (deterministico ? " · greedy" : "")
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
