import Foundation
import FoundationModels

// MARK: - Esquemas gerados pelo modelo
// Modo com evidência: para cada dimensão, primeiro a citação e depois o nível (inteiro).
// Modo só números: apenas o nível (menos tokens de saída, portanto mais rápido).

struct AncoraBruta: Sendable, Hashable {
    let parametro: String
    let trecho: String
    let nivel: Int
}

@Generable
struct AncoraExtra: Sendable {
    @Guide(description: "ID exato do parâmetro (valencia, ativacao, dominio, volume, tom, tensao, distancia, andamento, fragmentacao, regularidade, calor, luz, abertura, peso, fluidez)")
    var parametro: String
    @Guide(description: "Palavra ou trecho literal curto (1 a 4 palavras) do texto onde este outro foco do parâmetro aparece")
    var trecho: String
    @Guide(description: "Inteiro para este trecho (-5 a +5; ou 0 a 5 para distancia e fragmentacao)", .range(-5...5))
    var nivel: Int
}

@Generable
struct AncoraFoco: Sendable {
    @Guide(description: "Outra palavra ou trecho literal curto (1 a 4 palavras) do texto onde esta dimensão também se manifesta com foco próprio")
    var trecho: String
    @Guide(description: "Inteiro para este trecho (-5 a +5)", .range(-5...5))
    var nivel: Int
}

struct LeituraGeral {
    let evidencia: String?
    let nivel: Int
}

@Generable
struct Leitura {
    @Guide(description: "Palavra ou trecho literal curto (até 4 palavras) que justifica a pontuação, ou exatamente: nenhuma")
    var evidencia: String
    @Guide(description: "Inteiro de -5 a +5. Zero sem evidência própria da dimensão; 1 ou 2 para sinais indiretos ou metafóricos", .range(-5...5))
    var nivel: Int
}

@Generable
struct LeituraDetalhada {
    @Guide(description: "Palavra ou trecho literal curto (até 4 palavras) que mais representa a dimensão, ou exatamente: nenhuma")
    var evidencia: String
    @Guide(description: "Inteiro predominante de -5 a +5. Zero sem evidência própria", .range(-5...5))
    var nivel: Int
    @Guide(description: "Opcional (máx. 3 itens): outros trechos literais da frase onde a mesma dimensão atua com foco ou polo distinto; deixe vazia [] se houver só um foco")
    var ancorasExtras: [AncoraFoco]
}

@Generable
struct Nivel {
    @Guide(description: "Inteiro de -5 a +5. Zero sem evidência própria da dimensão; 1 ou 2 para sinais indiretos ou metafóricos", .range(-5...5))
    var nivel: Int
}

@Generable
struct LeituraUnipolar {
    @Guide(description: "Palavra ou trecho literal curto (até 4 palavras) que justifica a pontuação, ou exatamente: nenhuma")
    var evidencia: String
    @Guide(description: "Inteiro de 0 a 5. Zero no polo inicial (presente/unido), mesmo com evidência", .range(0...5))
    var nivel: Int
}

@Generable
struct LeituraUnipolarDetalhada {
    @Guide(description: "Palavra ou trecho literal curto (até 4 palavras) que justifica a pontuação, ou exatamente: nenhuma")
    var evidencia: String
    @Guide(description: "Inteiro predominante de 0 a 5. Zero no polo inicial (presente/unido), mesmo com evidência", .range(0...5))
    var nivel: Int
    @Guide(description: "Opcional (máx. 3 itens): outros trechos literais da frase onde a mesma dimensão atua; deixe vazia [] se houver só um foco")
    var ancorasExtras: [AncoraFoco]
}

@Generable
struct NivelUnipolar {
    @Guide(description: "Inteiro de 0 a 5. Zero no polo inicial (presente/unido)", .range(0...5))
    var nivel: Int
}

extension LeituraGeral {
    init(_ l: Leitura) { self.init(evidencia: l.evidencia, nivel: l.nivel) }
    init(_ l: LeituraUnipolar) { self.init(evidencia: l.evidencia, nivel: l.nivel) }
    init(_ n: Nivel) { self.init(evidencia: nil, nivel: n.nivel) }
    init(_ n: NivelUnipolar) { self.init(evidencia: nil, nivel: n.nivel) }
}

protocol GrupoLeituras: Generable {
    var leituras: [String: LeituraGeral] { get }
    var ancorasAdicionais: [AncoraBruta] { get }
}

protocol GrupoNiveis: Generable {
    var niveis: [String: LeituraGeral] { get }
}

// Uma única chamada devolve os 15 parâmetros no mesmo schema + lista esparsa de âncoras extras quando um parâmetro ocorre em mais de uma palavra.
@Generable
struct TodosLeituras {
    var valencia: Leitura
    var ativacao: Leitura
    var dominio: Leitura
    var volume: Leitura
    var tom: Leitura
    var tensao: Leitura
    var distancia: LeituraUnipolar
    var andamento: Leitura
    var fragmentacao: LeituraUnipolar
    var regularidade: Leitura
    var calor: Leitura
    var luz: Leitura
    var abertura: Leitura
    var peso: Leitura
    var fluidez: Leitura
    @Guide(description: "Opcional (máx. 6 itens): apenas quando um parâmetro atuar em outra palavra com foco próprio ou polo oposto (ex: 'afunda' e 'flutua' em peso). Deixe vazia [] se a evidencia principal bastar.")
    var ancorasExtras: [AncoraExtra]
}

@Generable
struct TodosNiveis {
    var valencia: Nivel
    var ativacao: Nivel
    var dominio: Nivel
    var volume: Nivel
    var tom: Nivel
    var tensao: Nivel
    var distancia: NivelUnipolar
    var andamento: Nivel
    var fragmentacao: NivelUnipolar
    var regularidade: Nivel
    var calor: Nivel
    var luz: Nivel
    var abertura: Nivel
    var peso: Nivel
    var fluidez: Nivel
}

@Generable
struct GrupoAfetoVoz {
    var valencia: Leitura
    var ativacao: Leitura
    var dominio: Leitura
    var volume: Leitura
    var tom: Leitura
    @Guide(description: "Opcional (máx. 4 itens): outros focos/palavras do mesmo texto para parâmetros deste grupo; deixe vazia [] se não houver múltiplos focos.")
    var ancorasExtras: [AncoraExtra]
}

@Generable
struct GrupoNarrativaEstrutura {
    var tensao: Leitura
    var distancia: LeituraUnipolar
    var andamento: Leitura
    var fragmentacao: LeituraUnipolar
    var regularidade: Leitura
    @Guide(description: "Opcional (máx. 4 itens): outros focos/palavras do mesmo texto para parâmetros deste grupo; deixe vazia [] se não houver múltiplos focos.")
    var ancorasExtras: [AncoraExtra]
}

@Generable
struct GrupoSensorial {
    var calor: Leitura
    var luz: Leitura
    var abertura: Leitura
    var peso: Leitura
    var fluidez: Leitura
    @Guide(description: "Opcional (máx. 4 itens): outros focos/palavras do mesmo texto para parâmetros deste grupo; deixe vazia [] se não houver múltiplos focos.")
    var ancorasExtras: [AncoraExtra]
}

@Generable
struct GrupoAfetoVozN {
    var valencia: Nivel
    var ativacao: Nivel
    var dominio: Nivel
    var volume: Nivel
    var tom: Nivel
}

@Generable
struct GrupoNarrativaEstruturaN {
    var tensao: Nivel
    var distancia: NivelUnipolar
    var andamento: Nivel
    var fragmentacao: NivelUnipolar
    var regularidade: Nivel
}

@Generable
struct GrupoSensorialN {
    var calor: Nivel
    var luz: Nivel
    var abertura: Nivel
    var peso: Nivel
    var fluidez: Nivel
}

extension TodosLeituras: GrupoLeituras {
    var leituras: [String: LeituraGeral] {
        [
            "valencia": LeituraGeral(valencia), "ativacao": LeituraGeral(ativacao), "dominio": LeituraGeral(dominio),
            "volume": LeituraGeral(volume), "tom": LeituraGeral(tom), "tensao": LeituraGeral(tensao),
            "distancia": LeituraGeral(distancia), "andamento": LeituraGeral(andamento),
            "fragmentacao": LeituraGeral(fragmentacao), "regularidade": LeituraGeral(regularidade),
            "calor": LeituraGeral(calor), "luz": LeituraGeral(luz), "abertura": LeituraGeral(abertura),
            "peso": LeituraGeral(peso), "fluidez": LeituraGeral(fluidez)
        ]
    }
    var ancorasAdicionais: [AncoraBruta] {
        ancorasExtras.map { AncoraBruta(parametro: $0.parametro, trecho: $0.trecho, nivel: $0.nivel) }
    }
}

extension TodosNiveis: GrupoNiveis {
    var niveis: [String: LeituraGeral] {
        [
            "valencia": LeituraGeral(valencia), "ativacao": LeituraGeral(ativacao), "dominio": LeituraGeral(dominio),
            "volume": LeituraGeral(volume), "tom": LeituraGeral(tom), "tensao": LeituraGeral(tensao),
            "distancia": LeituraGeral(distancia), "andamento": LeituraGeral(andamento),
            "fragmentacao": LeituraGeral(fragmentacao), "regularidade": LeituraGeral(regularidade),
            "calor": LeituraGeral(calor), "luz": LeituraGeral(luz), "abertura": LeituraGeral(abertura),
            "peso": LeituraGeral(peso), "fluidez": LeituraGeral(fluidez)
        ]
    }
}

extension GrupoAfetoVoz: GrupoLeituras {
    var leituras: [String: LeituraGeral] {
        ["valencia": LeituraGeral(valencia), "ativacao": LeituraGeral(ativacao), "dominio": LeituraGeral(dominio),
         "volume": LeituraGeral(volume), "tom": LeituraGeral(tom)]
    }
    var ancorasAdicionais: [AncoraBruta] {
        ancorasExtras.map { AncoraBruta(parametro: $0.parametro, trecho: $0.trecho, nivel: $0.nivel) }
    }
}

extension GrupoNarrativaEstrutura: GrupoLeituras {
    var leituras: [String: LeituraGeral] {
        ["tensao": LeituraGeral(tensao), "distancia": LeituraGeral(distancia), "andamento": LeituraGeral(andamento),
         "fragmentacao": LeituraGeral(fragmentacao), "regularidade": LeituraGeral(regularidade)]
    }
    var ancorasAdicionais: [AncoraBruta] {
        ancorasExtras.map { AncoraBruta(parametro: $0.parametro, trecho: $0.trecho, nivel: $0.nivel) }
    }
}

extension GrupoSensorial: GrupoLeituras {
    var leituras: [String: LeituraGeral] {
        ["calor": LeituraGeral(calor), "luz": LeituraGeral(luz), "abertura": LeituraGeral(abertura),
         "peso": LeituraGeral(peso), "fluidez": LeituraGeral(fluidez)]
    }
    var ancorasAdicionais: [AncoraBruta] {
        ancorasExtras.map { AncoraBruta(parametro: $0.parametro, trecho: $0.trecho, nivel: $0.nivel) }
    }
}

extension GrupoAfetoVozN: GrupoNiveis {
    var niveis: [String: LeituraGeral] {
        ["valencia": LeituraGeral(valencia), "ativacao": LeituraGeral(ativacao), "dominio": LeituraGeral(dominio),
         "volume": LeituraGeral(volume), "tom": LeituraGeral(tom)]
    }
}

extension GrupoNarrativaEstruturaN: GrupoNiveis {
    var niveis: [String: LeituraGeral] {
        ["tensao": LeituraGeral(tensao), "distancia": LeituraGeral(distancia), "andamento": LeituraGeral(andamento),
         "fragmentacao": LeituraGeral(fragmentacao), "regularidade": LeituraGeral(regularidade)]
    }
}

extension GrupoSensorialN: GrupoNiveis {
    var niveis: [String: LeituraGeral] {
        ["calor": LeituraGeral(calor), "luz": LeituraGeral(luz), "abertura": LeituraGeral(abertura),
         "peso": LeituraGeral(peso), "fluidez": LeituraGeral(fluidez)]
    }
}
