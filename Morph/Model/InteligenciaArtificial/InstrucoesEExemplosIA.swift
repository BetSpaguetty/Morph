import Foundation

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
