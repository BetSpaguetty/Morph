//
//  MorphParameters.swift
//  teste_animacao
//
//  Definições dos 13 parâmetros semânticos ativos do Morph (ignorando Valência e Regularidade),
//  suas escalas discretas (-5..+5 ou 0..+5), âncoras semânticas e consequências visuais.
//

import SwiftUI

// MARK: - Escopo de Aplicação (Frase Inteira vs Palavra Específica)

enum ModificationScope: String, CaseIterable, Identifiable {
    case wholePhrase = "Frase Inteira"
    case specificWord = "Palavra Específica"

    var id: String { rawValue }
}

// MARK: - Os 13 Parâmetros Semânticos Ativos (PDF animacoes_parametros_Morph)

enum MorphParameter: String, CaseIterable, Identifiable, Hashable {
    case fragmentacao = "Fragmentação"
    case ativacao = "Ativação"
    case dominio = "Domínio"
    case tensao = "Tensão"
    case andamento = "Andamento"
    case calor = "Calor"
    case luz = "Luz"
    case abertura = "Abertura"
    case distancia = "Distância"
    case volume = "Volume"
    case tom = "Tom"
    case peso = "Peso"
    case fluidez = "Fluidez"

    var id: String { rawValue }

    /// Identificador correspondente no `Catalogo` do `Interpretador` (TesteParametros2)
    var catalogoId: String {
        switch self {
        case .fragmentacao: return "fragmentacao"
        case .ativacao: return "ativacao"
        case .dominio: return "dominio"
        case .tensao: return "tensao"
        case .andamento: return "andamento"
        case .calor: return "calor"
        case .luz: return "luz"
        case .abertura: return "abertura"
        case .distancia: return "distancia"
        case .volume: return "volume"
        case .tom: return "tom"
        case .peso: return "peso"
        case .fluidez: return "fluidez"
        }
    }

    var category: String {
        switch self {
        case .ativacao, .dominio:
            return "1. Afeto"
        case .volume, .tom, .peso, .fluidez:
            return "2. Movimento e Voz"
        case .tensao, .distancia, .andamento:
            return "3. Narrativa"
        case .fragmentacao:
            return "4. Estrutura"
        case .calor, .luz, .abertura:
            return "5. Sensorial"
        }
    }

    var icon: String {
        switch self {
        case .fragmentacao: return "square.grid.3x3.topleft.filled"
        case .ativacao: return "bolt.fill"
        case .dominio: return "crown.fill"
        case .tensao: return "waveform.path.ecg"
        case .andamento: return "timer"
        case .calor: return "thermometer.sun.fill"
        case .luz: return "sun.max.fill"
        case .abertura: return "arrow.left.and.right.Text.vertical"
        case .distancia: return "point.3.connected.trianglepath.dotted"
        case .volume: return "speaker.wave.3.fill"
        case .tom: return "textformat"
        case .peso: return "scalemass.fill"
        case .fluidez: return "water.waves"
        }
    }

    var safeIcon: String {
        switch self {
        case .abertura: return "arrow.left.and.right"
        default: return icon
        }
    }

    var accentColor: Color {
        switch self {
        case .fragmentacao: return .purple
        case .ativacao: return .yellow
        case .dominio: return .orange
        case .tensao: return .red
        case .andamento: return .teal
        case .calor: return Color(red: 0.96, green: 0.36, blue: 0.18)
        case .luz: return Color(red: 0.98, green: 0.82, blue: 0.22)
        case .abertura: return .cyan
        case .distancia: return .indigo
        case .volume: return .pink
        case .tom: return .mint
        case .peso: return .blue
        case .fluidez: return Color(red: 0.25, green: 0.72, blue: 0.96)
        }
    }

    /// Escala definida no PDF de parâmetros:
    /// Distância e Fragmentação são unipolares (0 a +5); os demais 11 são bipolares (-5 a +5).
    var isUnipolar: Bool {
        switch self {
        case .fragmentacao, .distancia:
            return true
        default:
            return false
        }
    }

    var minScore: Int {
        isUnipolar ? 0 : -5
    }

    var maxScore: Int {
        5
    }

    var discreteValues: [Int] {
        Array(minScore...maxScore)
    }

    var scaleDescription: String {
        isUnipolar ? "0 a +5 (Unipolar)" : "-5 a +5 (Bipolar)"
    }

    var polarityDescription: String {
        switch self {
        case .fragmentacao: return "unido (0) ↔ fragmentado (+5)"
        case .ativacao: return "inerte (-5) ↔ agitado (+5)"
        case .dominio: return "vulnerável (-5) ↔ dominante (+5)"
        case .tensao: return "alívio (-5) ↔ suspense (+5)"
        case .andamento: return "tempo dilatado (-5) ↔ tempo comprimido (+5)"
        case .calor: return "frio (-5) ↔ quente (+5)"
        case .luz: return "escuridão (-5) ↔ luminoso (+5)"
        case .abertura: return "confinado (-5) ↔ amplo (+5)"
        case .distancia: return "presente (0) ↔ distante (+5)"
        case .volume: return "sussurro (-5) ↔ grito (+5)"
        case .tom: return "grave/sério (-5) ↔ lúdico/piada (+5)"
        case .peso: return "leve (-5) ↔ pesado (+5)"
        case .fluidez: return "rígido (-5) ↔ fluido (+5)"
        }
    }

    var semanticDefinition: String {
        switch self {
        case .fragmentacao:
            return "Grau de desintegração do que é descrito e da própria construção do trecho."
        case .ativacao:
            return "Energia, agitação e urgência do que acontece ou é sentido."
        case .dominio:
            return "Sensação de controle e poder de quem vive a cena."
        case .tensao:
            return "Expectativa não resolvida, a sensação de que algo vai acontecer."
        case .andamento:
            return "Velocidade (literal ou percebida) com que o tempo da história passa no texto."
        case .calor:
            return "Temperatura sensorial das imagens."
        case .luz:
            return "Claridade luminosa das imagens representadas."
        case .abertura:
            return "Sensação de amplitude ou confinamento do espaço ao redor."
        case .distancia:
            return "Quão longe do presente imediato a cena parece estar (sonho, memória, etc)."
        case .volume:
            return "Intensidade sonora ou da voz presente no texto."
        case .tom:
            return "Atitude de quem narra ou fala diante do que conta, indo do solene e grave ao lúdico, irônico e bem-humorado."
        case .peso:
            return "Tamanho ou peso das imagens e da sensação."
        case .fluidez:
            return "Qualidade do movimento ou da matéria, do rígido ao líquido e contínuo."
        }
    }

    var consequenceDescription: String {
        switch self {
        case .fragmentacao:
            return "Fade com efeito de granulação entrando e saindo."
        case .ativacao:
            return "Deixa a animação mais rápida (+) ou mais lenta (-)."
        case .dominio:
            return "Muda o tamanho da fonte (menor em -5, maior em +5)."
        case .tensao:
            return "Faz a palavra vibrar conforme o suspense aumenta."
        case .andamento:
            return "Duração da palavra surgindo e indo embora da tela (a partir de +1; 0 e negativos mantêm parada)."
        case .calor:
            return "Muda a cor: frio (azul escuro, azul, lilás) ↔ quente (laranja, vermelho)."
        case .luz:
            return "Luz (palavra brilhando em +) / criar sombra escura para a letra (-)."
        case .abertura:
            return "Muda o espaçamento entre as letras (comprimido ↔ aberto)."
        case .distancia:
            return "Muda o espaçamento entre as palavras."
        case .volume:
            return "Muda o peso/espessura da fonte (fino no sussurro ↔ grosso no grito)."
        case .tom:
            return "Altera a fonte: -5/-4 Times New Roman, -3/-2 Serif, -1..+3 SF Padrão, +4/+5 Comic Sans."
        case .peso:
            return "Leve (-): palavra flutua para o topo / Pesado (+): palavra afunda para a base."
        case .fluidez:
            return "Ondulação da letra horizontalmente e verticalmente (a partir de +1; 0 e negativos mantêm parada)."
        }
    }

    var samplePhrase: String {
        switch self {
        case .fragmentacao: return "Tudo se estilhaçou em pedaços soltos no ar"
        case .ativacao: return "Coração disparado correndo em pânico pela rua"
        case .dominio: return "Eu comando este lugar com poder absoluto"
        case .tensao: return "Um ruído na sombra avisava que algo ia explodir"
        case .andamento: return "Os anos passaram num piscar de olhos"
        case .calor: return "O fogo abrasador derreteu o vento de gelo"
        case .luz: return "Um clarão cegante rasgou o breu da noite"
        case .abertura: return "O horizonte infinito abriu o quarto estreito"
        case .distancia: return "Lembro vagamente como num sonho distante"
        case .volume: return "Um sussurro silencioso virou um grito ensurdecedor"
        case .tom: return "Essa cerimônia solene virou uma piada absurda"
        case .peso: return "A pluma leve flutuou enquanto o chumbo afundou"
        case .fluidez: return "A água desliza em ondas suaves pelo rio"
        }
    }

    func anchorLabel(for score: Int) -> String {
        let clamped = max(minScore, min(maxScore, score))
        switch self {
        case .fragmentacao:
            switch clamped {
            case 0: return "0: Unido / Íntegro"
            case 1: return "+1: Rachado"
            case 2: return "+2: Fissurado"
            case 3: return "+3: Despedaçado"
            case 4: return "+4: Estilhaçado"
            case 5: return "+5: Desintegração total"
            default: return "\(clamped)"
            }
        case .ativacao:
            switch clamped {
            case -5: return "-5: Torpor, imobilidade total"
            case -4: return "-4: Letargia profunda"
            case -3: return "-3: Sereno, parado"
            case -2: return "-2: Lento, sossegado"
            case -1: return "-1: Calmo"
            case 0: return "0: Neutro"
            case 1: return "+1: Inquieto"
            case 2: return "+2: Ágil, alerta"
            case 3: return "+3: Animado, apressado"
            case 4: return "+4: Urgente, elétrico"
            case 5: return "+5: Frenesi, pânico, explosão"
            default: return "\(clamped)"
            }
        case .dominio:
            switch clamped {
            case -5: return "-5: Submissão total"
            case -4: return "-4: Acuado, dominado"
            case -3: return "-3: Medo, impotência"
            case -2: return "-2: Inseguro, frágil"
            case -1: return "-1: Hesitação"
            case 0: return "0: Neutro"
            case 1: return "+1: Firmeza"
            case 2: return "+2: Seguro, no controle"
            case 3: return "+3: Confiança, imposição"
            case 4: return "+4: Soberano, imponente"
            case 5: return "+5: Poder absoluto"
            default: return "\(clamped)"
            }
        case .tensao:
            switch clamped {
            case -5: return "-5: Resolução plena"
            case -4: return "-4: Paz segura"
            case -3: return "-3: Desfecho, segurança"
            case -2: return "-2: Descontração"
            case -1: return "-1: Alívio leve"
            case 0: return "0: Neutro (estável)"
            case 1: return "+1: Inquietação"
            case 2: return "+2: Presságio"
            case 3: return "+3: Suspense, ameaça"
            case 4: return "+4: Perigo iminente"
            case 5: return "+5: Prestes a explodir"
            default: return "\(clamped)"
            }
        case .andamento:
            switch clamped {
            case -5: return "-5: Instante congelado (Parado — escala negativa a definir)"
            case -4: return "-4: Pausa profundíssima (Parado — escala negativa a definir)"
            case -3: return "-3: Câmera lenta, minucioso (Parado — escala negativa a definir)"
            case -2: return "-2: Tempo arrastado (Parado — escala negativa a definir)"
            case -1: return "-1: Sem pressa (Parado — escala negativa a definir)"
            case 0: return "0: Neutro (Frase completamente parada)"
            case 1: return "+1: Logo, sem demora"
            case 2: return "+2: Passagem rápida"
            case 3: return "+3: Resumo de dias"
            case 4: return "+4: Salto acelerado"
            case 5: return "+5: Elipse de anos (rajada)"
            default: return "\(clamped)"
            }
        case .calor:
            switch clamped {
            case -5: return "-5: Gelo, congelar (Azul escuro)"
            case -4: return "-4: Geada glacial (Azul profundo)"
            case -3: return "-3: Frio (Azul)"
            case -2: return "-2: Vento frio (Azul-lilás)"
            case -1: return "-1: Fresco (Lilás)"
            case 0: return "0: Neutro"
            case 1: return "+1: Morno (Âmbar suave)"
            case 2: return "+2: Acolhedor (Laranja claro)"
            case 3: return "+3: Quente, sol (Laranja)"
            case 4: return "+4: Brasa (Vermelho-laranja)"
            case 5: return "+5: Fogo, abrasador (Vermelho)"
            default: return "\(clamped)"
            }
        case .luz:
            switch clamped {
            case -5: return "-5: Breu total (Sombra densa)"
            case -4: return "-4: Escuridão pesada"
            case -3: return "-3: Noite, sombra"
            case -2: return "-2: Meia-luz escura"
            case -1: return "-1: Penumbra"
            case 0: return "0: Neutro"
            case 1: return "+1: Claro (Brilho suave)"
            case 2: return "+2: Iluminado"
            case 3: return "+3: Luminoso (Palavra brilhando)"
            case 4: return "+4: Reluzente"
            case 5: return "+5: Clarão cegante"
            default: return "\(clamped)"
            }
        case .abertura:
            switch clamped {
            case -5: return "-5: Claustrofobia (Letras coladas)"
            case -4: return "-4: Sufocante, estreito"
            case -3: return "-3: Quarto pequeno"
            case -2: return "-2: Fechado"
            case -1: return "-1: Apertado"
            case 0: return "0: Neutro"
            case 1: return "+1: Espaçoso"
            case 2: return "+2: Arejado"
            case 3: return "+3: Campo aberto"
            case 4: return "+4: Vastidão"
            case 5: return "+5: Horizonte infinito"
            default: return "\(clamped)"
            }
        case .distancia:
            switch clamped {
            case 0: return "0: Presente imediato"
            case 1: return "+1: Ontem"
            case 2: return "+2: Passado recente"
            case 3: return "+3: Lembrança"
            case 4: return "+4: Memória remota"
            case 5: return "+5: Sonho, irrealidade"
            default: return "\(clamped)"
            }
        case .volume:
            switch clamped {
            case -5: return "-5: Silêncio absoluto (Ultra fino)"
            case -4: return "-4: Quase inaudível"
            case -3: return "-3: Sussurro (Fino)"
            case -2: return "-2: Murmúrio"
            case -1: return "-1: Voz baixa"
            case 0: return "0: Neutro (Regular)"
            case 1: return "+1: Voz firme (Medium)"
            case 2: return "+2: Voz alta (Semibold)"
            case 3: return "+3: Grito (Bold)"
            case 4: return "+4: Berro (Heavy)"
            case 5: return "+5: Estrondo ensurdecedor (Black)"
            default: return "\(clamped)"
            }
        case .tom:
            switch clamped {
            case -5: return "-5: Sombrio, litúrgico (Times New Roman)"
            case -4: return "-4: Severo, formal (Times New Roman)"
            case -3: return "-3: Solene (Serif)"
            case -2: return "-2: Grave, clássico (Serif)"
            case -1: return "-1: Sério (SF Padrão)"
            case 0: return "0: Neutro (SF Padrão)"
            case 1: return "+1: Leve (SF Padrão)"
            case 2: return "+2: Descontraído (SF Padrão)"
            case 3: return "+3: Brincalhão (SF Padrão)"
            case 4: return "+4: Irônico, piada (Comic Sans)"
            case 5: return "+5: Farsa, deboche (Comic Sans)"
            default: return "\(clamped)"
            }
        case .peso:
            switch clamped {
            case -5: return "-5: Ingravidez (Flutua no topo)"
            case -4: return "-4: Pairando alto"
            case -3: return "-3: Flutuar"
            case -2: return "-2: Pluma no ar"
            case -1: return "-1: Leve"
            case 0: return "0: Neutro (Centro)"
            case 1: return "+1: Carregado"
            case 2: return "+2: Denso"
            case 3: return "+3: Pesado, afundar"
            case 4: return "+4: Chumbo afundando"
            case 5: return "+5: Esmagador (Fundo da tela)"
            default: return "\(clamped)"
            }
        case .fluidez:
            switch clamped {
            case -5: return "-5: Petrificado (Parado — escala negativa a definir)"
            case -4: return "-4: Cortante, engessado (Parado — escala negativa a definir)"
            case -3: return "-3: Travado, mecânico (Parado — escala negativa a definir)"
            case -2: return "-2: Seco (Parado — escala negativa a definir)"
            case -1: return "-1: Duro (Parado — escala negativa a definir)"
            case 0: return "0: Neutro (Frase completamente parada)"
            case 1: return "+1: Suave"
            case 2: return "+2: Maleável"
            case 3: return "+3: Escorrer, ondular"
            case 4: return "+4: Correnteza"
            case 5: return "+5: Líquido, torrente"
            default: return "\(clamped)"
            }
        }
    }

    func formattedScore(_ score: Int) -> String {
        if score > 0 {
            return "+\(score)"
        }
        return "\(score)"
    }
}

// MARK: - Armazenamento de Notas dos 13 Parâmetros

struct ParameterScores: Equatable {
    private var values: [MorphParameter: Int] = [:]

    init() {
        for param in MorphParameter.allCases {
            values[param] = 0
        }
    }

    subscript(parameter: MorphParameter) -> Int {
        get {
            values[parameter] ?? 0
        }
        set {
            let clamped = max(parameter.minScore, min(parameter.maxScore, newValue))
            values[parameter] = clamped
        }
    }

    var activeParameters: [(MorphParameter, Int)] {
        MorphParameter.allCases.compactMap { param in
            let val = self[param]
            return val != 0 ? (param, val) : nil
        }
    }

    var hasAnyNonZero: Bool {
        MorphParameter.allCases.contains { self[$0] != 0 }
    }

    mutating func resetAll() {
        for param in MorphParameter.allCases {
            values[param] = 0
        }
    }

    static func single(_ parameter: MorphParameter, score: Int) -> ParameterScores {
        var scores = ParameterScores()
        scores[parameter] = score
        return scores
    }
}
