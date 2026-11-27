import Foundation
import FoundationModels

// MARK: - Esquemas gerados pelo modelo
// Modo com evidência: para cada dimensão, primeiro a citação e depois o nível (inteiro).
// Modo só números: apenas o nível (menos tokens de saída, portanto mais rápido).

struct LeituraGeral {
    let evidencia: String?
    let nivel: Int
}

@Generable
struct Leitura {
    @Guide(description: "Trecho literal do texto (até 5 palavras) que justifica a pontuação, ou exatamente: nenhuma")
    var evidencia: String
    @Guide(description: "Inteiro de -5 a +5. Zero sem evidência própria da dimensão; 1 ou 2 para sinais indiretos ou metafóricos", .range(-5...5))
    var nivel: Int
}

@Generable
struct Nivel {
    @Guide(description: "Inteiro de -5 a +5. Zero sem evidência própria da dimensão; 1 ou 2 para sinais indiretos ou metafóricos", .range(-5...5))
    var nivel: Int
}

@Generable
struct LeituraUnipolar {
    @Guide(description: "Trecho literal do texto (até 5 palavras) que justifica a pontuação, ou exatamente: nenhuma")
    var evidencia: String
    @Guide(description: "Inteiro de 0 a 5. Zero no polo inicial (presente/unido), mesmo com evidência", .range(0...5))
    var nivel: Int
}

@Generable
struct NivelUnipolar {
    @Guide(description: "Inteiro de 0 a 5. Zero no polo inicial (presente/unido)", .range(0...5))
    var nivel: Int
}

// MARK: - Estrutura por partes
// Cada parâmetro pode aparecer em uma ou mais partes do texto. O nível pertence
// à parte, não ao texto inteiro; os núcleos marcam onde o efeito é mais forte.

@Generable
struct ParteParametro {
    @Guide(description: "ID exato do parâmetro (valencia, ativacao, dominio, volume, tom, tensao, distancia, andamento, fragmentacao, regularidade, calor, luz, abertura, peso, fluidez)")
    var parametro: String
    @Guide(description: "Palavra ou expressão literal onde a parte começa")
    var inicio: String
    @Guide(description: "Palavra ou expressão literal onde a parte termina; igual a inicio se a parte for uma só palavra")
    var fim: String
    @Guide(description: "Inteiro de -5 a +5. Intensidade do parâmetro nesta parte; unipolares usam 0 a +5", .range(-5...5))
    var nivel: Int
    @Guide(description: "0 a 3 palavras ou expressões literais, dentro da parte, onde o efeito é mais forte")
    var nucleos: [String]
}

@Generable
struct RespostaPartes {
    @Guide(description: "Até 6 partes por parâmetro. Só inclua parâmetros com evidência própria no texto.")
    var partes: [ParteParametro]
}

@Generable
struct ParteLocal {
    @Guide(description: "Palavra ou expressão literal onde a parte começa")
    var inicio: String
    @Guide(description: "Palavra ou expressão literal onde a parte termina; igual a inicio se a parte for uma só palavra")
    var fim: String
    @Guide(description: "Inteiro de -5 a +5. Intensidade do parâmetro nesta parte; unipolares usam 0 a +5", .range(-5...5))
    var nivel: Int
    @Guide(description: "0 a 3 palavras ou expressões literais, dentro da parte, onde o efeito é mais forte")
    var nucleos: [String]
}

@Generable
struct RespostaPartesParametro {
    @Guide(description: "Até 6 partes do parâmetro no texto. Deixe vazio se não houver evidência própria.")
    var partes: [ParteLocal]
}

extension LeituraGeral {
    init(_ l: Leitura) { self.init(evidencia: l.evidencia, nivel: l.nivel) }
    init(_ l: LeituraUnipolar) { self.init(evidencia: l.evidencia, nivel: l.nivel) }
    init(_ n: Nivel) { self.init(evidencia: nil, nivel: n.nivel) }
    init(_ n: NivelUnipolar) { self.init(evidencia: nil, nivel: n.nivel) }
}

protocol GrupoLeituras: Generable {
    var leituras: [String: LeituraGeral] { get }
}

protocol GrupoNiveis: Generable {
    var niveis: [String: LeituraGeral] { get }
}

// Uma única chamada devolve os 15 parâmetros no mesmo schema.
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
}

@Generable
struct GrupoNarrativaEstrutura {
    var tensao: Leitura
    var distancia: LeituraUnipolar
    var andamento: Leitura
    var fragmentacao: LeituraUnipolar
    var regularidade: Leitura
}

@Generable
struct GrupoSensorial {
    var calor: Leitura
    var luz: Leitura
    var abertura: Leitura
    var peso: Leitura
    var fluidez: Leitura
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
}

extension GrupoNarrativaEstrutura: GrupoLeituras {
    var leituras: [String: LeituraGeral] {
        ["tensao": LeituraGeral(tensao), "distancia": LeituraGeral(distancia), "andamento": LeituraGeral(andamento),
         "fragmentacao": LeituraGeral(fragmentacao), "regularidade": LeituraGeral(regularidade)]
    }
}

extension GrupoSensorial: GrupoLeituras {
    var leituras: [String: LeituraGeral] {
        ["calor": LeituraGeral(calor), "luz": LeituraGeral(luz), "abertura": LeituraGeral(abertura),
         "peso": LeituraGeral(peso), "fluidez": LeituraGeral(fluidez)]
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
