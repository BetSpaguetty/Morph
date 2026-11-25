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
