import Foundation
import FoundationModels

// MARK: - Grupos

/// Agrupamento usado só para exibir os resultados.
enum Grupo: String, CaseIterable, Identifiable {
    case afeto = "Afeto"
    case narrativa = "Narrativa"
    case estrutura = "Estrutura"
    case sensorial = "Sensorial"
    case movimentoVoz = "Movimento e voz"

    var id: String { rawValue }
}

/// Agrupamento usado para dividir a interpretação em chamadas ao modelo.
enum GrupoChamada: Int, CaseIterable {
    case afetoVoz = 0
    case narrativaEstrutura
    case sensorial

    var titulo: String {
        switch self {
        case .afetoVoz: return "Afeto e voz"
        case .narrativaEstrutura: return "Narrativa e estrutura"
        case .sensorial: return "Imagens sensoriais e movimento"
        }
    }
}

enum Escala: String {
    case bipolar
    case unipolar
}

enum VarianteCompacta: String, CaseIterable {
    case comExemplos
    case comExemplosMinimos
    case semExemplos

    var titulo: String {
        switch self {
        case .comExemplos: return "compacto com exemplos"
        case .comExemplosMinimos: return "compacto com exemplos mínimos"
        case .semExemplos: return "compacto sem exemplos"
        }
    }
}

enum ModoChamadas: String, CaseIterable, Identifiable {
    case umaChamada = "1 chamada (todos os parâmetros)"
    case porGrupo = "3 chamadas (por grupo)"
    case porParametro = "15 chamadas (por parâmetro)"

    var id: String { rawValue }

    var quantidadeDeChamadas: Int {
        switch self {
        case .umaChamada: return 1
        case .porGrupo: return GrupoChamada.allCases.count
        case .porParametro: return Catalogo.todos.count
        }
    }

    var tituloCurto: String {
        switch self {
        case .umaChamada: return "1 chamada"
        case .porGrupo: return "3 chamadas"
        case .porParametro: return "15 chamadas"
        }
    }
}

// MARK: - Catálogo (fonte única da verdade: gera o prompt e os rótulos da interface)

struct DefinicaoParametro: Identifiable {
    let id: String
    let nome: String
    let grupo: Grupo
    let chamada: GrupoChamada
    let candidata: Bool
    let poloNegativo: String
    let poloPositivo: String
    let mede: String             // o que a dimensão mede
    let quandoNegativo: String   // evidências do polo negativo/inicial
    let quandoPositivo: String   // evidências do polo positivo/final
    let cuidado: String          // armadilhas e confusões de sinal
    let ancoras: String          // exemplos de intensidade graduada
    var escala: Escala = .bipolar

    var compacta: String {
        switch id {
        case "valencia":
            return "sinal afetivo: - = negativo; + = positivo. -: dor, perda, medo, raiva; +: alegria, ternura, esperança. Não confundir com ativação."
        case "ativacao":
            return "energia: - = calmo/inerte; + = agitado/urgente. -: calma, torpor; +: pressa, pânico, fúria. SINAL: calma = -, agitação = +; não é valência."
        case "dominio":
            return "controle: - = vulnerável; + = dominante. -: impotência, fuga, submissão; +: mandar, vencer, impor-se. Raiva tende a +; medo, a -."
        case "volume":
            return "som/voz: - = silêncio/sussurro; + = grito/estrondo. Só pontue se há som; exclamação sozinha é +1 fraco."
        case "tom":
            return "atitude do narrador: - = grave/solene; + = lúdico/irônico. Não é valência; sem marca de atitude, 0."
        case "tensao":
            return "expectativa: - = alívio/resolução; + = suspense/ameaça. SINAL: suspense = +; alívio = -. Não é ativação."
        case "distancia":
            return "0 = presente; 5 = distante. 0: agora, aqui, detalhes imediatos. 1-5: memória, sonho, passado, irrealidade. Passado verbal comum não conta; exija marca."
        case "andamento":
            return "velocidade do tempo: - = dilatado/lento; + = comprimido/salto. Não é energia; câmera lenta = -, resumo de anos = +."
        case "fragmentacao":
            return "0 = unido; 5 = fragmentado. 0: juntar, abraçar, inteireza, harmonia. 1-5: quebrar, estilhaçar, dispersar, frases truncadas. Não é valência."
        case "regularidade":
            return "ordem: - = caótico; + = ordenado. -: imprevisível, desordem; +: rotina, padrão, simetria. Não confundir com fragmentação."
        case "calor":
            return "temperatura: - = frio; + = quente. Só com imagem térmica explícita; metáfora vale menos. Tristeza não implica frio."
        case "luz":
            return "claridade: - = escuro; + = luminoso. Só com referência explícita à luz/escuridão. Medo não implica escuridão."
        case "abertura":
            return "espaço: - = confinado; + = amplo. Só se o texto descreve/sente o espaço. Solidão não implica amplitude."
        case "peso":
            return "peso: - = leve/flutua; + = pesado/afunda. SINAL: leveza = -, peso = +. Tristeza não implica peso; exija imagem."
        case "fluidez":
            return "movimento/matéria: - = rígido/travado; + = fluido/líquido. Calma não implica fluidez; exija imagem."
        default:
            return mede
        }
    }
}

enum Catalogo {
    static let todos: [DefinicaoParametro] = [
        .init(id: "valencia", nome: "Valência", grupo: .afeto, chamada: .afetoVoz, candidata: false,
              poloNegativo: "negativo", poloPositivo: "positivo",
              mede: "Se o que o texto expressa é bom ou ruim para quem vive a cena. Mede só o sinal afetivo, não a energia.",
              quandoNegativo: "tristeza, triste, péssimo, desânimo, dor, perda, luto, medo, raiva, repulsa, mal-estar, decepção. Emoção atenuada também conta ('meio triste', 'um pouco chateado').",
              quandoPositivo: "alegria, ternura, esperança, prazer, alívio, carinho, orgulho, paz, serenidade, tranquilidade, bem-estar. Emoção atenuada também conta ('meio contente').",
               cuidado: "Não confunda com Ativação: terror e euforia são intensos, mas de valências opostas. Fúria, raiva e violência são valência NEGATIVA mesmo quando intensas; energia não torna a valência positiva. Paz, serenidade e tranquilidade são valência POSITIVA (não 0), mesmo sem alegria explícita. Não julgue a qualidade do texto.",
               ancoras: "-1 incômodo leve; -3 tristeza, medo; -5 desespero, horror, fúria; +1 contentamento leve; +3 alegria, carinho; +5 êxtase."),
        .init(id: "ativacao", nome: "Ativação", grupo: .afeto, chamada: .afetoVoz, candidata: false,
              poloNegativo: "inerte", poloPositivo: "agitado",
              mede: "Energia, agitação e urgência do que acontece ou é sentido.",
              quandoNegativo: "calma, serenidade, imobilidade, torpor, sossego, devagar, lentamente, quietude, cansaço profundo.",
              quandoPositivo: "pressa, agitação, corpo em alerta (coração disparado, correr, gritar), euforia, pânico, fúria, explosão.",
              cuidado: "ATENÇÃO AO SINAL: calma é NEGATIVA; agitação é POSITIVA. Não depende de ser bom ou ruim: tristeza serena é NEGATIVA; pânico e festa são POSITIVAS. Não confunda com Andamento (velocidade do tempo narrado) nem com Tensão (espera silenciosa tem ativação baixa).",
              ancoras: "-1 calmo; -3 sereno, parado; -5 torpor, imobilidade total; +1 inquieto; +3 animado, apressado; +5 frenesi, pânico, explosão."),
        .init(id: "dominio", nome: "Domínio", grupo: .afeto, chamada: .afetoVoz, candidata: true,
              poloNegativo: "vulnerável", poloPositivo: "dominante",
              mede: "Sensação de controle e poder de quem vive a cena.",
              quandoNegativo: "impotência, fuga, submissão, encolher-se, obedecer, ser dominado, não conseguir reagir.",
              quandoPositivo: "mandar, vencer, controlar, impor-se, autoridade, domínio da situação.",
              cuidado: "Emoção negativa não implica domínio baixo: raiva costuma ter domínio alto; medo, baixo. Sem agente ou controle visível, 0.",
              ancoras: "-1 hesitação; -3 medo, impotência; -5 submissão total; +1 firmeza; +3 confiança, imposição; +5 poder absoluto."),
        .init(id: "volume", nome: "Volume", grupo: .movimentoVoz, chamada: .afetoVoz, candidata: true,
              poloNegativo: "sussurro", poloPositivo: "grito",
              mede: "Intensidade sonora ou da voz presente no texto.",
              quandoNegativo: "silêncio, sussurro, murmúrio, voz baixa, ninguém falava, calar-se, quietude sonora.",
              quandoPositivo: "grito, berro, estrondo, trovão, barulho, voz alta, clamor, ecoar forte.",
              cuidado: "ATENÇÃO AO SINAL: silêncio e sussurro são NEGATIVOS; grito e estrondo são POSITIVOS. Uma cena tensa e silenciosa tem volume NEGATIVO. Só pontue se há som ou voz no texto; emoção intensa sem som é 0. Uma exclamação sozinha é indício fraco (+1).",
              ancoras: "-1 voz baixa; -3 sussurro; -5 silêncio absoluto; +1 voz firme; +3 grito; +5 estrondo ensurdecedor."),
        .init(id: "tom", nome: "Tom", grupo: .movimentoVoz, chamada: .afetoVoz, candidata: true,
              poloNegativo: "grave", poloPositivo: "lúdico",
              mede: "Atitude de quem narra ou fala diante do que conta: do solene e grave ao lúdico, irônico e bem-humorado.",
              quandoNegativo: "solenidade, severidade, ritual, gravidade, cerimônia, formalidade pesada.",
              quandoPositivo: "humor, ironia, brincadeira, leveza no jeito de contar, deboche, graça.",
              cuidado: "Não é valência: uma piada pode falar de algo triste; um evento alegre pode ser solene (casamento). Sem marca de atitude, 0.",
              ancoras: "-1 sério; -3 solene; -5 sombrio, litúrgico; +1 leve; +3 brincalhão; +5 farsa, deboche."),

        .init(id: "tensao", nome: "Tensão", grupo: .narrativa, chamada: .narrativaEstrutura, candidata: false,
              poloNegativo: "alívio", poloPositivo: "suspense",
              mede: "Expectativa não resolvida: a sensação de que algo vai acontecer.",
              quandoNegativo: "alívio, desfecho, resolução, segurança, relaxamento depois de um perigo.",
              quandoPositivo: "ameaça iminente, espera, segredo, perigo, algo fora do lugar, algo prestes a acontecer, sombras, sussurros, espreita, sem avisar.",
               cuidado: "ATENÇÃO AO SINAL: suspense é POSITIVO; alívio e resolução são NEGATIVOS. Uma descrição calma sem sinal de expectativa é 0, não negativa. Cena de terror/suspense (sombras, sussurros, espreita, algo prestes a acontecer) tem tensão POSITIVA, mesmo noturna ou solitária. Não é Ativação: espera silenciosa tem tensão alta e ativação baixa.",
              ancoras: "-1 alívio leve; -3 desfecho, segurança; -5 resolução plena; +1 inquietação; +3 suspense, ameaça; +5 prestes a explodir."),
        .init(id: "distancia", nome: "Distância", grupo: .narrativa, chamada: .narrativaEstrutura, candidata: false,
              poloNegativo: "presente", poloPositivo: "distante",
              mede: "Quão longe do presente imediato a cena parece estar.",
              quandoNegativo: "presente vivo, 'agora', 'neste momento', hoje, detalhes sensoriais imediatos, aqui e agora.",
              quandoPositivo: "memória, lembrança, lembro, lembrar, sonho, passado remoto, névoa, irrealidade, alucinação, 'como num sonho'.",
              cuidado: "Verbo no passado numa narrativa comum não é distância, é só tempo verbal. Exija marca de memória, sonho ou afastamento. Sem marca de tempo, 0.",
              ancoras: "0 presente; 1 ontem; 3 lembrança; 5 sonho, irrealidade.",
              escala: .unipolar),
        .init(id: "andamento", nome: "Andamento", grupo: .narrativa, chamada: .narrativaEstrutura, candidata: true,
              poloNegativo: "tempo dilatado", poloPositivo: "tempo comprimido",
              mede: "Velocidade com que o tempo da história passa no texto.",
              quandoNegativo: "duração e pausa: durante horas, cada detalhe, sem pressa, devagar, lentamente, um instante que não acaba, descrição minuciosa.",
              quandoPositivo: "resumo e salto: os anos passaram, de repente, logo, em seguida, enquanto isso, elipse, ação em rajada.",
              cuidado: "Não é energia: câmera lenta numa luta é tempo dilatado (NEGATIVO) com ativação alta. Sem marca de duração ou de salto no tempo, 0.",
              ancoras: "-1 sem pressa; -3 câmera lenta, descrição minuciosa; -5 instante congelado; +1 logo; +3 resumo de dias; +5 elipse de anos."),
        .init(id: "fragmentacao", nome: "Fragmentação", grupo: .estrutura, chamada: .narrativaEstrutura, candidata: false,
              poloNegativo: "unido", poloPositivo: "fragmentado",
              mede: "Grau de desintegração do que é descrito e da própria construção do trecho.",
              quandoNegativo: "juntar, abraçar, inteireza, harmonia, completude, tudo se encaixando, unidade.",
              quandoPositivo: "quebrar, estilhaçar, dispersar, desfazer, despedaçar, frases truncadas, desintegração.",
              cuidado: "Não é valência: um luto pode ser coeso. Frases curtas isoladas não bastam; é preciso indicar fragmentação.",
              ancoras: "0 unido; 1 rachado; 3 despedaçado; 5 desintegração total.",
              escala: .unipolar),
        .init(id: "regularidade", nome: "Regularidade", grupo: .estrutura, chamada: .narrativaEstrutura, candidata: true,
              poloNegativo: "caótico", poloPositivo: "ordenado",
              mede: "Ordem e repetição do que ocorre ou da forma do texto.",
              quandoNegativo: "imprevisibilidade, desordem, acaso, bagunça, irregularidade.",
              quandoPositivo: "padrões, rotina, simetria, repetição, 'todo dia', 'sempre o mesmo', ordem.",
              cuidado: "Se o texto não descreve ordem ou desordem de forma clara, 0. Não confunda com Fragmentação (unidade).",
              ancoras: "-1 irregular; -3 bagunçado; -5 caos total; +1 habitual; +3 rotina, simetria; +5 perfeitamente regular."),

        .init(id: "calor", nome: "Calor", grupo: .sensorial, chamada: .sensorial, candidata: false,
              poloNegativo: "frio", poloPositivo: "quente",
              mede: "Temperatura sensorial das imagens.",
              quandoNegativo: "gelo, frio, geada, vento gelado, inverno, metal gelado, tremer de frio.",
              quandoPositivo: "sol, fogo, brasa, suor, febre, calor, abafado, fervendo.",
              cuidado: "Emoção não é temperatura: tristeza não implica frio, nem raiva implica calor. Se o texto não menciona temperatura nem imagem térmica, o nível é 0. Metáfora térmica ('coração de gelo') vale, mas fraca (2).",
              ancoras: "-1 fresco; -3 frio; -5 gelo, congelar; +1 morno; +3 quente, sol; +5 fogo, abrasador."),
        .init(id: "luz", nome: "Luz", grupo: .sensorial, chamada: .sensorial, candidata: false,
              poloNegativo: "escuridão", poloPositivo: "luminoso",
              mede: "Claridade das imagens.",
              quandoNegativo: "escuro, noite, sombra, breu, penumbra, apagar a luz.",
              quandoPositivo: "sol, brilho, clarão, lâmpada, amanhecer, luz, luz acesa, reluzir.",
              cuidado: "Só pontue com referência explícita à claridade ou à escuridão. Tristeza ou medo não implicam escuridão. Se o texto não menciona claridade, o nível é 0.",
              ancoras: "-1 penumbra; -3 noite, sombra; -5 breu total; +1 claro; +3 luminoso; +5 clarão cegante."),
        .init(id: "abertura", nome: "Abertura", grupo: .sensorial, chamada: .sensorial, candidata: true,
              poloNegativo: "confinado", poloPositivo: "amplo",
              mede: "Sensação de espaço ao redor.",
              quandoNegativo: "quarto pequeno, cela, aperto, parede, porão, teto baixo, sufocar, corredor estreito.",
              quandoPositivo: "horizonte, mar, céu, campo, vastidão, planície, espaço aberto.",
              cuidado: "Só pontue se o texto descreve ou sente o espaço. Solidão não implica espaço amplo. Sem menção a espaço, 0.",
              ancoras: "-1 apertado; -3 quarto pequeno; -5 claustrofobia; +1 espaçoso; +3 campo aberto; +5 horizonte infinito."),
        .init(id: "peso", nome: "Peso", grupo: .movimentoVoz, chamada: .sensorial, candidata: false,
              poloNegativo: "leve", poloPositivo: "pesado",
              mede: "Leveza ou gravidade das imagens e da sensação.",
              quandoNegativo: "flutuar, flutuo, voar, subir, pluma, leve, pairar, balão.",
              quandoPositivo: "cair, afundar, arrastar, fardo, chumbo, peso no peito, esmagar, carregar.",
               cuidado: "ATENÇÃO AO SINAL: leveza (flutuar, subir) é NEGATIVA; peso (cair, afundar) é POSITIVO. Flutuar, pairar e voar são nível negativo explícito quando descrevem leveza física ou emocional. Tristeza não implica peso: exija imagem ou sensação de peso ou de leveza; sem isso, 0.",
              ancoras: "-1 leve; -3 flutuar; -5 ingravidez; +1 carregado; +3 pesado, afundar; +5 esmagador."),
        .init(id: "fluidez", nome: "Fluidez", grupo: .movimentoVoz, chamada: .sensorial, candidata: false,
              poloNegativo: "rígido", poloPositivo: "fluido",
              mede: "Qualidade do movimento ou da matéria: do rígido ao líquido e contínuo.",
              quandoNegativo: "travado, quebradiço, mecânico, seco, estático, duro, rígido, cortante.",
              quandoPositivo: "água, onda, ondas, escorrer, escorre, deslizar, ondular, suave, contínuo, líquido.",
              cuidado: "Calma não implica fluidez: exija imagem ou movimento fluido ou travado; sem isso, 0.",
              ancoras: "-1 duro; -3 travado, mecânico; -5 petrificado; +1 suave; +3 escorrer, ondular; +5 líquido, torrente.")
    ]

    static let porID: [String: DefinicaoParametro] = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })

    static func definicoes(para modo: ModoChamadas) -> [DefinicaoParametro] {
        switch modo {
        case .umaChamada:
            return todos
        case .porGrupo:
            return GrupoChamada.allCases.flatMap { g in
                todos.filter { $0.chamada == g }
            }
        case .porParametro:
            return todos
        }
    }

    static func definicoes(do grupo: GrupoChamada) -> [DefinicaoParametro] {
        todos.filter { $0.chamada == grupo }
    }
}

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

// MARK: - Exemplos de calibração (dentro do prompt)
// Nos bipolares, só os itens com nível diferente de zero são listados; o resto vale "nenhuma", 0.
// Nos unipolares, 0 também é um valor informativo e é listado.
// Atenção: são textos diferentes dos exemplos de teste do app, para não contaminar a avaliação.

struct ExemploCalibracao {
    let texto: String
    let itens: [String: (evidencia: String, nivel: Int)]

    static let todos: [ExemploCalibracao] = [
        .init(texto: "Ele ficou irritado com o atraso e falou mais alto.",
              itens: ["valencia": ("ficou irritado", -3), "ativacao": ("falou mais alto", 3),
                      "volume": ("falou mais alto", 2), "tensao": ("irritado", 2),
                      "tom": ("irritado", -2)]),
        .init(texto: "A tarde estava calma e silenciosa; nada se movia, e ele respirava devagar.",
              itens: ["ativacao": ("calma e silenciosa", -4), "tensao": ("nada se movia", -3),
                      "volume": ("silenciosa", -3), "andamento": ("devagar", -2)]),
        .init(texto: "Relembro a infância como uma névoa distante, tudo desbotado e sonhado.",
              itens: ["distancia": ("névoa distante", 4)]),
        .init(texto: "Fiquei um pouco chateado com a demora, nada grave.",
              itens: ["valencia": ("um pouco chateado", -1)]),
        .init(texto: "Respirei fundo e senti uma paz tranquila.",
              itens: ["valencia": ("senti uma paz tranquila", 2), "ativacao": ("Respirei fundo", -2),
                      "tensao": ("paz tranquila", -2)]),
        .init(texto: "O trovão estourou. Ela correu, o coração disparado, sem olhar para trás.",
              itens: ["valencia": ("o coração disparado", -2), "ativacao": ("o coração disparado", 4),
                      "tensao": ("sem olhar para trás", 4), "volume": ("O trovão estourou", 4),
                      "dominio": ("Ela correu", -2)]),
        .init(texto: "Naquela tarde de domingo, a vovó contou, sem pressa, cada detalhe do vestido que usou no casamento.",
              itens: ["andamento": ("sem pressa, cada detalhe", -3), "distancia": ("o vestido que usou no casamento", 2),
                      "ativacao": ("sem pressa", -2)]),
        .init(texto: "Ela riu alto da própria piada e o salão inteiro entrou na brincadeira.",
              itens: ["tom": ("riu alto da própria piada", 3), "volume": ("riu alto", 2),
                      "valencia": ("entrou na brincadeira", 3)]),
        .init(texto: "Ninguém falava. A maçaneta girou devagar, e ele esperou, sem respirar.",
              itens: ["tensao": ("A maçaneta girou devagar", 4), "volume": ("Ninguém falava", -3),
                      "andamento": ("girou devagar", -2)]),
        .init(texto: "Na cerimônia solene, o juiz leu a sentença com voz grave e pausada.",
              itens: ["tom": ("cerimônia solene", -4), "andamento": ("pausada", -1)]),
        .init(texto: "Ele ergueu a mão, a sala inteira calou, e ninguém ousou contrariar.",
              itens: ["dominio": ("ninguém ousou contrariar", 4), "volume": ("a sala inteira calou", -2)]),
        .init(texto: "Todo dia, às seis, o mesmo café, o mesmo caminho, o mesmo banco da praça.",
              itens: ["regularidade": ("o mesmo café, o mesmo caminho", 4)]),
        .init(texto: "Por fim, tudo se resolveu, e num piscar de olhos passaram-se três invernos.",
              itens: ["tensao": ("tudo se resolveu", -3), "andamento": ("passaram-se três invernos", 4)]),
        .init(texto: "Agora, neste exato instante, os papéis voam em desordem pela sala.",
              itens: ["distancia": ("neste exato instante", 0), "regularidade": ("em desordem", -4)]),
        .init(texto: "A família inteira se abraçou, e tudo pareceu inteiro de novo.",
              itens: ["fragmentacao": ("tudo pareceu inteiro de novo", 0), "valencia": ("se abraçou", 3)]),
        .init(texto: "O sol da tarde esquentava a varanda e o café fumegava.",
              itens: ["calor": ("esquentava a varanda", 3), "luz": ("sol da tarde", 2)]),
        .init(texto: "No inverno, o vento gelado cortava a rua escura e vazia.",
              itens: ["calor": ("vento gelado", -4), "luz": ("rua escura", -3)]),
        .init(texto: "No porão estreito, de teto baixo, o ar pesava sobre os ombros dele.",
              itens: ["abertura": ("porão estreito, de teto baixo", -4), "peso": ("o ar pesava sobre os ombros", 3)]),
        .init(texto: "Do alto da colina via-se o horizonte inteiro, e a pipa subiu leve, flutuando no vento.",
              itens: ["abertura": ("o horizonte inteiro", 4), "peso": ("subiu leve, flutuando", -3)]),
        .init(texto: "A água escorria pelas pedras, lisa e contínua, e o vidro do espelho se estilhaçou sem aviso.",
              itens: ["fluidez": ("escorria pelas pedras, lisa e contínua", 4), "fragmentacao": ("se estilhaçou", 3)]),
        .init(texto: "O braço do robô girava travado, mecânico, aos solavancos.",
              itens: ["fluidez": ("travado, mecânico", -4)]),
        .init(texto: "Perdi a paciência com o atendimento hoje.",
              itens: ["valencia": ("Perdi a paciência", -2)]),
        .init(texto: "Ele guardou as chaves no bolso e saiu pela porta da frente.",
              itens: [:])
    ]
}

// MARK: - Prompt

enum Instrucoes {
    private static func regras(defs: [DefinicaoParametro], comEvidencia: Bool) -> String {
        let temUnipolar = defs.contains { $0.escala == .unipolar }
        var s = "Você analisa textos de escrita criativa (narrativa, poesia, prosa fragmentada) e mede dimensões expressivas deles. Os valores vão controlar a aparência visual do texto, então precisão e honestidade valem mais que criatividade.\n\n"

        if comEvidencia {
            s += """
            PARA CADA DIMENSÃO SOLICITADA, FAÇA DOIS PASSOS, NESTA ORDEM
            1. evidencia: copie literalmente do texto a palavra ou o trecho mais curto e exato (até 4 palavras) que indica esta dimensão específica — pois cada animação será aplicada diretamente sobre as palavras citadas (ex: em 'cai a chuva fluida', cite 'cai' para peso e 'fluida' para fluidez). Nunca copie o texto inteiro se apenas parte dele gera o efeito; se não houver pista, escreva exatamente: nenhuma
            2. nivel: um número inteiro, respeitando a escala da dimensão.
            3. ancorasExtras: se um mesmo parâmetro atuar em duas ou mais palavras distintas da frase (especialmente com intensidades diferentes ou polos opostos, ex: 'afunda' com +4 e 'flutua' com -3 em peso), coloque o foco principal nos passos 1-2 e adicione os outros focos em ancorasExtras. Caso haja apenas um foco por parâmetro, deixe ancorasExtras vazio ([]).
            """
        } else {
            s += """
            PARA CADA DIMENSÃO SOLICITADA, DÊ O NIVEL
            nivel: um número inteiro, respeitando a escala da dimensão.
            """
        }

        s += """


        COMO ESCOLHER O NÍVEL
        - Dimensões bipolares usam inteiros de -5 a +5. O sinal indica o polo; o módulo indica a intensidade: 1 traço mínimo ou indireto; 2 leve; 3 moderado, claramente presente; 4 forte; 5 extremo, domina o texto.
        - Dimensões unipolares usam inteiros de 0 a 5. 0 é o polo inicial (presente ou unido); 5 é o polo final (distante ou fragmentado). Não use números negativos nessas dimensões.
        - Confira o polo antes de responder: veja se a evidência corresponde ao polo inicial/negativo ou final/positivo descrito na dimensão. Dimensões marcadas com 'ATENÇÃO AO SINAL' costumam ser invertidas por engano.
        - Atenuadores reduzem a intensidade: 'meio triste', 'um pouco', 'certa' valem 1 ou 2 em módulo; 'muito', 'extremamente' valem 4 ou 5.
        - Use toda a escala. Evite responder apenas 0, 3 ou 5.
        - O nível 0 significa "não há evidência própria desta dimensão", não "intensidade baixa". Uma emoção forte no texto não é evidência para dimensões que ela não descreve. Sinais indiretos e metafóricos contam como evidência.
        - Teste da especificidade: pergunte "que palavra ou expressão do texto pertence ao campo desta dimensão?" (som para volume, temperatura para calor, tempo para andamento, espaço para abertura etc.). Se a única resposta for uma emoção genérica, o texto inteiro ou uma palavra de outra dimensão sem associação clara, inclusive metafórica, use evidência "nenhuma" e nível 0.
        - Para calor, luz, abertura, peso e fluidez, a evidência precisa conter uma palavra ou imagem do campo sensorial correspondente (frio/calor; escuro/luz; apertado/amplo; leve/pesado; rígido/fluido), inclusive quando a imagem é metafórica. Sem essa pista, use "nenhuma" e 0.

        """

        if comEvidencia {
            s += "- Nas dimensões bipolares, o nível é 0 quando a evidência é 'nenhuma'. Se a evidência for específica da dimensão, o nível não pode ser 0; se for genérica ou o texto inteiro, troque por 'nenhuma' e 0.\n"
            if temUnipolar {
                s += "- Nas dimensões unipolares, 0 é um valor válido mesmo quando há evidência específica do polo inicial: cite o trecho que mostra o polo inicial. Use 'nenhuma' e 0 apenas quando não houver evidência específica da dimensão.\n"
            }
        } else {
            s += "- Nas dimensões bipolares, o nível é 0 quando o texto não traz nenhuma evidência própria daquela dimensão.\n"
            if temUnipolar {
                s += "- Nas dimensões unipolares, 0 indica o polo inicial ou ausência de evidência; não invente afastamento ou fragmentação sem sinal no texto.\n"
            }
        }

        s += """

        ATALHOS DE SINAL (confira antes de responder)
        - Fúria, raiva, grito, explosão: valência NEGATIVA; ativação e volume POSITIVOS. Intensidade não é valência positiva.
        - Suspense, ameaça, espera, segredo, sombras, sussurros, espreita: tensão POSITIVA; alívio, desfecho, resolução: NEGATIVA.
        - Flutuar, subir, pairar, leve: peso NEGATIVO; cair, afundar, fardo: POSITIVO.
        - Calma, devagar, paz, quietude: ativação NEGATIVA (não 0), quando a calma é explícita.
        - Lembro, lembrança, sonho, memória, passado remoto: distância no mínimo 3; 'hoje', 'agora', 'aqui', 'neste instante': distância 0.

        REGRAS DE HONESTIDADE (evitam duas falhas opostas)
        - Não force: não deduza uma dimensão por associação de senso comum nem pelo clima geral. Só pontue com evidência própria dela no texto. Exemplo: tristeza não implica frio, escuridão nem peso; raiva não implica calor. Associações metafóricas claras contam.
        - Dimensões sensoriais (calor, luz, abertura, peso, fluidez) só valem com imagem sensorial no texto, literal ou metafórica. Sem imagem de temperatura, claridade, espaço, peso ou movimento, o nível é 0, mesmo que o texto seja emotivo.
        - Emoção forte não se espalha: fúria pode ter valência negativa, ativação e volume altos, mas calor, luz, abertura, peso e fluidez continuam 0 sem imagem própria.
        - Não omita: se há um trecho claro que indica a dimensão, pontue, mesmo que seja discreto. Metáforas valem, com intensidade menor que a imagem literal.
        - Figuras de linguagem contam pelo efeito expressivo, não pelo literal: "morrendo de saudade" expressa saudade, não morte; "explodi de alegria" expressa alegria intensa, não fragmentação.
        - Cada dimensão é independente das outras. Um mesmo trecho pode servir de evidência a mais de uma dimensão, mas cada uma precisa da sua leitura própria.
        - Julgue o que o texto expressa, não o assunto em abstrato nem a qualidade da escrita. Havendo sinais distintos ou opostos em palavras separadas do texto, registre o foco principal no parâmetro e os demais em ancorasExtras com seu nível próprio.
        """
        return s
    }

    static func sistema(defs: [DefinicaoParametro], comEvidencia: Bool) -> String {
        var s = regras(defs: defs, comEvidencia: comEvidencia)
        if defs.count == 1 {
            let d = defs[0]
            s += "\n\nATENÇÃO: esta chamada mede APENAS \(d.id) (\(d.nome)). Não pontue outras dimensões. Emoção forte no texto não é evidência para \(d.nome) sem uma pista específica, inclusive indireta ou metafórica."
            if d.id == "valencia" {
                s += "\nATENÇÃO À VALÊNCIA: fúria, raiva, ódio, medo, tristeza, dor e perda são NEGATIVOS, mesmo com fogo, grito ou energia. Alegria, paz, amor e alívio são POSITIVOS. Fogo e grito não tornam a valência positiva."
            }
        }
        s += "\n\nDIMENSÕES A MEDIR\n"
        for (i, d) in defs.enumerated() {
            if d.escala == .unipolar {
                s += "\n\(i + 1). \(d.id) (\(d.nome)): 0 = \(d.poloNegativo); 5 = \(d.poloPositivo)."
                s += "\n   Mede: \(d.mede)"
                s += "\n   Evidência de 0 (polo inicial): \(d.quandoNegativo)"
                s += "\n   Evidência de 1 a 5 (afastamento): \(d.quandoPositivo)"
                s += "\n   Cuidado: \(d.cuidado)"
                s += "\n   Âncoras: \(d.ancoras)"
            } else {
                s += "\n\(i + 1). \(d.id) (\(d.nome)): negativo (-) = \(d.poloNegativo); positivo (+) = \(d.poloPositivo)."
                s += "\n   Mede: \(d.mede)"
                s += "\n   Evidência de nível NEGATIVO (-1 a -5): \(d.quandoNegativo)"
                s += "\n   Evidência de nível POSITIVO (+1 a +5): \(d.quandoPositivo)"
                s += "\n   Cuidado: \(d.cuidado)"
                s += "\n   Âncoras: \(d.ancoras)"
            }
        }
        s += "\n\nEXEMPLOS DE CALIBRAÇÃO"
        for ex in exemplosPara(defs) {
            s += "\n\nTexto: \"\(ex.texto)\""
            s += linhas(de: ex, defs: defs, comEvidencia: comEvidencia)
        }
        return s
    }

    static func sistemaCompacto(defs: [DefinicaoParametro], comEvidencia: Bool,
                                variante: VarianteCompacta) -> String {
        let temUnipolar = defs.contains { $0.escala == .unipolar }
        var s = "Você mede dimensões expressivas de textos criativos. Seja preciso e honesto; não invente.\n"
        if comEvidencia {
            s += "Para cada dimensão, cite em evidencia a palavra ou trecho curto exato (até 4 palavras) que gera o efeito (ex: 'cai' para peso, 'fluida' para fluidez; não copie a frase inteira) ou escreva exatamente: nenhuma. Depois dê o nível.\n"
            s += "Se um parâmetro atuar em outra palavra distinta da frase (ou em polo oposto), adicione esse foco em ancorasExtras; se não, deixe ancorasExtras vazio ([]).\n"
        } else {
            s += "Para cada dimensão, dê apenas o nível.\n"
        }
        if defs.count == 1 {
            let d = defs[0]
            s += "Esta chamada mede apenas \(d.id) (\(d.nome)): não invente pistas nem pontue o clima geral.\n"
        }
        s += "\nESCALA\n"
        s += "- Bipolares: inteiro -5...+5; 0 = sem evidência (com evidência) ou sem sinal (sem evidência).\n"
        if temUnipolar {
            s += "- Unipolares: inteiro 0...5; 0 = polo inicial (presente/unido), 5 = polo final; 0 pode ter evidência.\n"
        }
        s += "\nDIMENSÕES\n"
        for d in defs {
            s += "\n- \(d.id) (\(d.nome)): \(d.compacta)"
        }
        if variante != .semExemplos {
            let limite = variante == .comExemplos ? 5 : 3
            s += "\n\nEXEMPLOS"
            for ex in exemplosPara(defs, limite: limite) {
                s += "\n\nTexto: \"\(ex.texto)\""
                s += linhas(de: ex, defs: defs, comEvidencia: comEvidencia)
            }
        }
        return s
    }

    static func pedido(_ texto: String) -> String {
        "Leia o texto abaixo e meça as dimensões solicitadas.\n\nTEXTO:\n\"\"\"\n\(texto)\n\"\"\""
    }

    // MARK: Seleção e formatação dos exemplos

    private static func sinal(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }

    private static func linhas(de ex: ExemploCalibracao, defs: [DefinicaoParametro], comEvidencia: Bool) -> String {
        let presentes = defs.compactMap { d in ex.itens[d.id].map { (d, $0) } }
        var s = ""
        if presentes.isEmpty {
            if defs.count == 1 {
                let d = defs[0]
                s += comEvidencia ? "\n\(d.id): evidencia \"nenhuma\", nivel 0" : "\n\(d.id): nivel 0"
            } else {
                s += comEvidencia
                    ? "\nTodas as dimensões acima: evidencia \"nenhuma\", nivel 0"
                    : "\nTodas as dimensões acima: nivel 0"
            }
            return s
        }
        for (d, item) in presentes {
            let nivel = d.escala == .unipolar ? "\(item.nivel)" : sinal(item.nivel)
            s += comEvidencia
                ? "\n\(d.id): evidencia \"\(item.evidencia)\", nivel \(nivel)"
                : "\n\(d.id): nivel \(nivel)"
        }
        if presentes.count < defs.count {
            s += comEvidencia
                ? "\nDemais dimensões: evidencia \"nenhuma\", nivel 0"
                : "\nDemais dimensões: nivel 0"
        }
        return s
    }

    /// Escolhe exemplos positivos que cobrem os dois polos de cada dimensão, mais exemplos
    /// "negativos" (há conteúdo, mas nenhuma das dimensões pedidas) e um controle neutro.
    private static func exemplosPara(_ defs: [DefinicaoParametro], limite: Int? = nil) -> [ExemploCalibracao] {
        let ids = Set(defs.map(\.id))
        let limite = limite ?? (defs.count == 1 ? 3 : 7)

        var cobertos = Set<String>()
        var positivos: [ExemploCalibracao] = []
        for ex in ExemploCalibracao.todos where positivos.count < limite {
            let pares: [String] = ex.itens.compactMap { id, item in
                guard ids.contains(id) else { return nil }
                if defs.count == 1 {
                    return "\(id):\(item.nivel)"
                }
                if Catalogo.porID[id]?.escala == .unipolar {
                    return "\(id):\(item.nivel)"
                }
                return item.nivel != 0 ? "\(id):\(item.nivel > 0 ? "+" : "-")" : nil
            }
            if pares.contains(where: { !cobertos.contains($0) }) {
                positivos.append(ex)
                pares.forEach { cobertos.insert($0) }
            }
        }

        let negativos = ExemploCalibracao.todos.filter { ex in
            !ex.itens.isEmpty && !ex.itens.keys.contains(where: { ids.contains($0) })
        }
        let neutro = ExemploCalibracao.todos.first(where: { $0.itens.isEmpty })

        // Intercala: negativos entre os positivos, para não ensinar que "sempre há valor".
        var resultado: [ExemploCalibracao] = []
        for (i, p) in positivos.enumerated() {
            resultado.append(p)
            if i == 1, negativos.count > 0 { resultado.append(negativos[0]) }
            if i == 4, negativos.count > 1 { resultado.append(negativos[1]) }
        }
        if positivos.count < 2, negativos.count > 0 { resultado.append(negativos[0]) }
        if let n = neutro { resultado.append(n) }
        return resultado
    }
}

// MARK: - Exemplos de teste na interface

struct Exemplo: Identifiable {
    let id = UUID()
    let titulo: String
    let texto: String
    let esperado: String

    static let todos: [Exemplo] = [
        .init(titulo: "Meio triste (atenuado)",
              texto: "Estou meio triste hoje.",
              esperado: "Valência levemente negativa (cerca de -0.4). Nenhuma outra dimensão deve ser pontuada."),
        .init(titulo: "Armadilha: tristeza sem imagens",
              texto: "Perdi meu emprego e me sinto péssimo.",
              esperado: "Valência negativa. Calor, luz, peso e abertura devem ficar em 0 (não há imagem)."),
        .init(titulo: "Armadilha de sinal: silêncio",
              texto: "A sala ficou em silêncio, e só se ouvia o tique-taque do relógio.",
              esperado: "Volume NEGATIVO (silêncio). Sensoriais em 0."),
        .init(titulo: "Armadilha de sinal: peso",
              texto: "Sentia o peito apertado, um fardo que não saía do lugar.",
              esperado: "Peso POSITIVO, valência negativa. Calor, luz e abertura em 0."),
        .init(titulo: "Metáfora térmica",
              texto: "Seu coração virou gelo depois daquela mensagem.",
              esperado: "Calor negativo fraco ou moderado (metáfora), valência negativa."),
        .init(titulo: "Mar calmo",
              texto: "O mar respira devagar. A onda volta, azul e calma, e eu flutuo em paz.",
              esperado: "Valência +, ativação −, fluidez +, peso −, abertura +, tensão ≤ 0."),
        .init(titulo: "Terror silencioso",
              texto: "A noite chegou sem avisar. Sussurros atrás da porta, sombras, e eu sozinho no escuro.",
              esperado: "Valência −, tensão +, luz −, volume −, domínio −."),
        .init(titulo: "Fúria",
              texto: "Fogo! Eu grito, a fúria explode.",
              esperado: "Valência −, ativação +, calor +, volume +, fragmentação +, domínio +."),
        .init(titulo: "Memória",
              texto: "Lembro da casa da avó como quem lembra de um sonho: a luz amarela, o cheiro de café, tudo desbotado pelos anos.",
              esperado: "Distância +, calor +, luz +, valência levemente +."),
        .init(titulo: "Par: tempo comprimido",
              texto: "Os anos passaram, e a casa envelheceu com eles.",
              esperado: "Andamento +."),
        .init(titulo: "Par: tempo dilatado",
              texto: "Durante horas, ele observou cada gota escorrer lentamente pelo vidro da janela.",
              esperado: "Andamento −, fluidez +, ativação baixa."),
        .init(titulo: "Controle sem pistas",
              texto: "A reunião foi marcada para terça-feira às três da tarde na sala dois.",
              esperado: "Tudo em 0 ou muito perto disso (testa se o modelo evita inventar).")
    ]
}
