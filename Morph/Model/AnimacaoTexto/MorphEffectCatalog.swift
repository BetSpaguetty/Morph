import Foundation

// MARK: - Hash Determinístico (Opção A: estável a 60fps, renovado via phraseSeed por interpretação)

enum MorphDeterministicHash {
    static func mix(_ a: Int, _ b: Int, _ c: Int = 0) -> UInt64 {
        var x = UInt64(bitPattern: Int64(a)) &* 0x9E37_79B9_7F4A_7C15
        x ^= UInt64(bitPattern: Int64(b)) &* 0xBF58_476D_1CE4_E5B9
        x ^= UInt64(bitPattern: Int64(c)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 30
        x &*= 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27
        x &*= 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return x
    }

    /// FNV-1a 64-bit estável entre processos (evita `String.hashValue`, que muda a cada execução).
    static func stableStringID(_ s: String) -> Int {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return Int(truncatingIfNeeded: hash)
    }

    static func pickIndex(count: Int, seed: Int, wordIndex: Int, salt: Int) -> Int {
        guard count > 1 else { return 0 }
        return Int(mix(seed, wordIndex, salt) % UInt64(count))
    }
}

// MARK: - Enums Estruturais do Catálogo

enum MorphEffectChannel: Int, CaseIterable, Hashable, Sendable {
    case typography = 1
    case surface = 2
    case entrance = 3
    case continuous = 4
    case overlay = 5
}

enum MorphEffectPolarity: String, Hashable, Sendable {
    case positive
    case negative
    case both

    func matches(score: Int) -> Bool {
        switch self {
        case .positive: return score > 0
        case .negative: return score < 0
        case .both: return score != 0
        }
    }
}

enum MorphRenderPrimitive: String, Hashable, Sendable {
    case typography
    case glyphTransform
    case wordLayer
    case surfaceStyle
    case gpuShader
}

// MARK: - IDs dos 97 Efeitos Oficiais do Morph (14 Parâmetros)

enum MorphEffectID: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Fragmentação (8)
    case fragDespedacar
    case fragDesabamento
    case fragCisao
    case fragDesintegracao
    case fragCorteAoMeio
    case fragRachado
    case fragCorroido
    case fragFadeGranulado

    // Ativação (9)
    case ativBounceInRight
    case ativBounce
    case ativFlipIn
    case ativShakeY
    case ativRicocheteLateral
    case ativCartasZigueZague
    case ativPulaPulaElastico
    case ativMicroOrbitas
    case ativPulsoRitmicoRegular

    // Domínio (3)
    case domTamanhoFonte
    case domEspessuraFonte
    case domLenteInflada

    // Tensão (9)
    case tensTada
    case tensGlitch
    case tensSqueezeExpand
    case tensTensaoContida
    case tensOndaSismica
    case tensDesalinhamentoMecanico
    case tensPressaoCrescente
    case tensAmeacaLatente
    case tensVibracaoPalavra

    // Andamento (3)
    case andSpeedDash
    case andRollIn
    case andLetargia

    // Calor (10: 6 quente +, 4 frio -)
    case calChamaAscendente
    case calLancamentoFoguete
    case calFogoVivo
    case calMiragemCalor
    case calNevoaAscendente
    case calSmokeOut
    case calArrepioGelado
    case calTremocaoFrio
    case calGelidoQuebradico
    case calNevascaCristalina

    // Luz (5: 4 claro +, 1 escuro -)
    case luzGlowIn
    case luzFlicker
    case luzFlickerIn
    case luzPulseNeon
    case luzEscurecimento

    // Abertura (5)
    case abertTrackingContract
    case abertUltraCondensado
    case abertUltraEstirado
    case abertEspacamentoLetras
    case abertPingentesVento

    // Distância (3)
    case distEngrenagemRelogio
    case distArrastoTemporal
    case distVisaoDupla

    // Volume (6: 1 silêncio -, 5 grito +)
    case volSolidToOutline
    case volGritoExplosivo
    case volPanoramica3D
    case volOndasEco
    case volEcoDirecional
    case volBerroDistorcido

    // Tom (1)
    case tomFonte

    // Peso (9: 4 leve -, 5 pesado +)
    case pesoFlutuacaoZeroG
    case pesoAntiGravity
    case pesoFlutuarTopo
    case pesoMovieCredits
    case pesoDropIn
    case pesoRastroVertical
    case pesoEsmagar
    case pesoAfundarComPeso
    case pesoFallingLeaves

    // Fluidez (13: 2 rígido -, 11 fluido +)
    case fluidRigidezMecanica
    case fluidBrilhoMetalico
    case fluidWaterDrop
    case fluidDerretido
    case fluidWave
    case fluidOndaInclinacao
    case fluidDancaTipografica
    case fluidOndulacaoVertical
    case fluidFluidoViscoso
    case fluidEspelhoLiquido
    case fluidSubmarino
    case fluidLuzPiscina
    case fluidRefracaoSubmersa

    // Valência (13: 7 positivo +, 6 negativo -)
    case valCaleidoscopioPrismatico
    case valCascataArcoIris
    case valFluxoArcoIris
    case valLampadaLava
    case valPulsoSaturacao
    case valRotacaoMatiz
    case valSombrasGemeas
    case valImpressaoCMYK
    case valCameraTermica
    case valMercurioLiquido
    case valAberracaoCromatica
    case valAnaglifo3D
    case valCartasCMYOrbita

    var id: String { rawValue }
}

// MARK: - Especificação de Cada Efeito

struct MorphEffectSpec: Identifiable, Equatable, Sendable {
    let id: MorphEffectID
    let name: String
    let sourceBadge: String
    let parameter: MorphParameter
    let polarity: MorphEffectPolarity
    let channel: MorphEffectChannel
    let primitive: MorphRenderPrimitive
    let minAbsScore: Int
    let isStatic: Bool
    let isHeavyGPU: Bool
    let blockedOnDecorativeFont: Bool
    /// Indica efeitos de movimento contínuo que trazem paleta própria quando o Canal Cor está livre
    /// (mas herdam a cor vencedora se outro parâmetro vencer o Canal Cor).
    let coupledSurfaceColor: Bool
    /// Palavras-chave/radicais normalizados (minúsculos sem acento) para afinidade lexical (Peça A).
    let lexicalKeywords: [String]

    init(
        id: MorphEffectID,
        name: String,
        sourceBadge: String,
        parameter: MorphParameter,
        polarity: MorphEffectPolarity,
        channel: MorphEffectChannel,
        primitive: MorphRenderPrimitive,
        minAbsScore: Int = 1,
        isStatic: Bool = false,
        isHeavyGPU: Bool = false,
        blockedOnDecorativeFont: Bool = false,
        coupledSurfaceColor: Bool = false,
        lexicalKeywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.sourceBadge = sourceBadge
        self.parameter = parameter
        self.polarity = polarity
        self.channel = channel
        self.primitive = primitive
        self.minAbsScore = minAbsScore
        self.isStatic = isStatic
        self.isHeavyGPU = isHeavyGPU
        self.blockedOnDecorativeFont = blockedOnDecorativeFont
        self.coupledSurfaceColor = coupledSurfaceColor
        self.lexicalKeywords = lexicalKeywords
    }

    var isAlwaysOnTypographyControl: Bool {
        id == .tomFonte || id == .domTamanhoFonte || id == .domEspessuraFonte
    }
}

// MARK: - Catálogo Completo dos 97 Efeitos

enum MorphEffectCatalog {
    static let allSpecs: [MorphEffectSpec] = [
        // MARK: Fragmentação (8)
        .init(id: .fragDespedacar, name: "Despedaçar", sourceBadge: "C301", parameter: .fragmentacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["despedac", "estilhac", "explod", "quebr"]),
        .init(id: .fragDesabamento, name: "Desabamento", sourceBadge: "C324", parameter: .fragmentacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["desab", "desmoron", "dobr", "ruir"]),
        .init(id: .fragCisao, name: "Cisão", sourceBadge: "C369", parameter: .fragmentacao, polarity: .positive, channel: .continuous, primitive: .wordLayer,
              lexicalKeywords: ["cisao", "divid", "separ", "rasg"]),
        .init(id: .fragDesintegracao, name: "Desintegração", sourceBadge: "C340", parameter: .fragmentacao, polarity: .positive, channel: .continuous, primitive: .gpuShader,
              isHeavyGPU: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["desintegr", "poeira", "cinzas", "sumir", "desfaz"]),
        .init(id: .fragCorteAoMeio, name: "Corte ao Meio", sourceBadge: "C79", parameter: .fragmentacao, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              isStatic: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["cort", "meio", "metade", "fati", "partid"]),
        .init(id: .fragRachado, name: "Rachado", sourceBadge: "C372", parameter: .fragmentacao, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              isStatic: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["rach", "fissur", "trinc"]),
        .init(id: .fragCorroido, name: "Corroído", sourceBadge: "C377", parameter: .fragmentacao, polarity: .positive, channel: .overlay, primitive: .gpuShader,
              isStatic: true, isHeavyGPU: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["corro", "ferrug", "apodrec", "desgast"]),
        .init(id: .fragFadeGranulado, name: "Fade Granulado", sourceBadge: "P1", parameter: .fragmentacao, polarity: .positive, channel: .overlay, primitive: .gpuShader,
              isHeavyGPU: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["granul", "areia", "farel", "dispers"]),

        // MARK: Ativação (9)
        .init(id: .ativBounceInRight, name: "Bounce in Right", sourceBadge: "#42", parameter: .ativacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform),
        .init(id: .ativBounce, name: "Bounce", sourceBadge: "#8", parameter: .ativacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["pul", "salt", "quic"]),
        .init(id: .ativFlipIn, name: "Flip in", sourceBadge: "#9", parameter: .ativacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["vir", "gir", "cambalhot"]),
        .init(id: .ativShakeY, name: "Shake Y", sourceBadge: "#19", parameter: .ativacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["sacud", "chacoalh", "agit"]),
        .init(id: .ativRicocheteLateral, name: "Ricochete Lateral", sourceBadge: "C16", parameter: .ativacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["ricochet", "bat", "rebot"]),
        .init(id: .ativCartasZigueZague, name: "Cartas em Zigue-Zague", sourceBadge: "C133", parameter: .ativacao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["zigue", "cart", "baralh"]),
        .init(id: .ativPulaPulaElastico, name: "Pula-Pula Elástico", sourceBadge: "C154", parameter: .ativacao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["pul", "elast", "mola", "saltit"]),
        .init(id: .ativMicroOrbitas, name: "Micro-Órbitas", sourceBadge: "C257", parameter: .ativacao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["orbit", "gir", "rodop", "zonz"]),
        .init(id: .ativPulsoRitmicoRegular, name: "Pulso Rítmico Regular", sourceBadge: "P20", parameter: .ativacao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["puls", "bat", "corac", "ritm"]),

        // MARK: Domínio (3)
        .init(id: .domTamanhoFonte, name: "Tamanho da Fonte", sourceBadge: "P4", parameter: .dominio, polarity: .both, channel: .typography, primitive: .typography,
              isStatic: true),
        .init(id: .domEspessuraFonte, name: "Espessura da Fonte", sourceBadge: "P13", parameter: .dominio, polarity: .both, channel: .typography, primitive: .typography,
              isStatic: true),
        .init(id: .domLenteInflada, name: "Lente Inflada", sourceBadge: "C368", parameter: .dominio, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["infl", "gigant", "impon", "poder", "soberan", "mando"]),

        // MARK: Tensão (9 — polo negativo sem animação; Flicker movido só para Luz)
        .init(id: .tensTada, name: "Tada", sourceBadge: "#20", parameter: .tensao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["surpres", "susto", "revel"]),
        .init(id: .tensGlitch, name: "Glitch", sourceBadge: "#30", parameter: .tensao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["glitch", "erro", "bug", "falh", "pane"]),
        .init(id: .tensSqueezeExpand, name: "Squeeze Expand", sourceBadge: "#84", parameter: .tensao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["esprem", "apert", "encolh"]),
        .init(id: .tensTensaoContida, name: "Tensão Contida", sourceBadge: "C334", parameter: .tensao, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["prestes", "esper", "segur", "contid"]),
        .init(id: .tensOndaSismica, name: "Onda Sísmica", sourceBadge: "C146", parameter: .tensao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["terremot", "sism", "tremor", "abal"]),
        .init(id: .tensDesalinhamentoMecanico, name: "Desalinhamento Mecânico", sourceBadge: "C270", parameter: .tensao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["maquin", "mecan", "desalinh", "engasg"]),
        .init(id: .tensPressaoCrescente, name: "Pressão Crescente", sourceBadge: "C338", parameter: .tensao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["press", "estour", "explod", "sufoc"]),
        .init(id: .tensAmeacaLatente, name: "Ameaça Latente", sourceBadge: "C339", parameter: .tensao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["ameac", "espreit", "perig", "sombr"]),
        .init(id: .tensVibracaoPalavra, name: "Vibração da Palavra", sourceBadge: "P5", parameter: .tensao, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["vibr", "trem", "nervos", "arrep"]),

        // MARK: Andamento (3)
        .init(id: .andSpeedDash, name: "Speed Dash", sourceBadge: "#78", parameter: .andamento, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["corr", "rapid", "dispar", "veloc", "flash", "piscar"]),
        .init(id: .andRollIn, name: "Roll In", sourceBadge: "#29", parameter: .andamento, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["rol", "gir", "passar", "anos", "dias"]),
        .init(id: .andLetargia, name: "Letargia", sourceBadge: "C345", parameter: .andamento, polarity: .negative, channel: .continuous, primitive: .wordLayer,
              lexicalKeywords: ["lent", "devagar", "horas", "eterno", "paus", "camera"]),

        // MARK: Calor (10: 6 quente +, 4 frio -)
        .init(id: .calChamaAscendente, name: "Chama Ascendente", sourceBadge: "C29", parameter: .calor, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              coupledSurfaceColor: true,
              lexicalKeywords: ["cham", "acend", "fogueir", "incend"]),
        .init(id: .calLancamentoFoguete, name: "Lançamento de Foguete", sourceBadge: "C104", parameter: .calor, polarity: .positive, channel: .entrance, primitive: .gpuShader,
              isHeavyGPU: true,
              lexicalKeywords: ["foguet", "decol", "lanc", "jato", "propuls"]),
        .init(id: .calFogoVivo, name: "Fogo Vivo", sourceBadge: "C47", parameter: .calor, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              coupledSurfaceColor: true,
              lexicalKeywords: ["fogo", "bras", "queim", "ard", "lava", "chamas"]),
        .init(id: .calMiragemCalor, name: "Miragem de Calor", sourceBadge: "C336", parameter: .calor, polarity: .positive, channel: .continuous, primitive: .wordLayer,
              coupledSurfaceColor: true,
              lexicalKeywords: ["mirag", "desert", "sol", "abaf", "ferv", "escald", "calor"]),
        .init(id: .calNevoaAscendente, name: "Névoa Ascendente", sourceBadge: "C161", parameter: .calor, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              isHeavyGPU: true,
              lexicalKeywords: ["vapor", "nevo", "fumeg", "cafe", "cha"]),
        .init(id: .calSmokeOut, name: "Smoke Out", sourceBadge: "#65", parameter: .calor, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              lexicalKeywords: ["fumac", "fuma", "cinz", "evapor"]),
        .init(id: .calArrepioGelado, name: "Arrepio Gelado", sourceBadge: "C327", parameter: .calor, polarity: .negative, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["arrep", "calafri", "vento", "gelad"]),
        .init(id: .calTremocaoFrio, name: "Tremoção de Frio", sourceBadge: "C337", parameter: .calor, polarity: .negative, channel: .continuous, primitive: .glyphTransform,
              coupledSurfaceColor: true,
              lexicalKeywords: ["trem", "frio", "congel", "inverno"]),
        .init(id: .calGelidoQuebradico, name: "Gélido e Quebradiço", sourceBadge: "C394", parameter: .calor, polarity: .negative, channel: .overlay, primitive: .wordLayer,
              isStatic: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["gelo", "gelid", "gead", "cristal", "glac"]),
        .init(id: .calNevascaCristalina, name: "Nevasca Cristalina", sourceBadge: "C157", parameter: .calor, polarity: .negative, channel: .overlay, primitive: .gpuShader,
              isHeavyGPU: true,
              lexicalKeywords: ["nev", "nevasc", "floc", "tempest"]),

        // MARK: Luz (5: 4 claro +, 1 escuro -)
        .init(id: .luzGlowIn, name: "Glow In", sourceBadge: "#7", parameter: .luz, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["brilh", "clar", "sol", "amanhec", "reluz"]),
        .init(id: .luzFlicker, name: "Flicker", sourceBadge: "#45", parameter: .luz, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["pisc", "lampad", "faisc", "curto"]),
        .init(id: .luzFlickerIn, name: "Flicker In", sourceBadge: "#100", parameter: .luz, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["acend", "interrupt", "farol"]),
        .init(id: .luzPulseNeon, name: "Pulse Neon", sourceBadge: "#91", parameter: .luz, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              lexicalKeywords: ["neon", "letreir", "luz", "lumin", "laser"]),
        .init(id: .luzEscurecimento, name: "Escurecimento", sourceBadge: "C355", parameter: .luz, polarity: .negative, channel: .overlay, primitive: .wordLayer,
              lexicalKeywords: ["escur", "noit", "breu", "sombr", "penumbr", "apag"]),

        // MARK: Abertura (5)
        .init(id: .abertTrackingContract, name: "Tracking Contract", sourceBadge: "#53", parameter: .abertura, polarity: .negative, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["fech", "encolh", "contrai", "esmag"]),
        .init(id: .abertUltraCondensado, name: "Ultra Condensado", sourceBadge: "C85", parameter: .abertura, polarity: .negative, channel: .typography, primitive: .glyphTransform,
              isStatic: true,
              lexicalKeywords: ["apert", "estreit", "cela", "porao", "claustrof", "sufoc"]),
        .init(id: .abertUltraEstirado, name: "Ultra Estirado", sourceBadge: "C86", parameter: .abertura, polarity: .positive, channel: .typography, primitive: .glyphTransform,
              isStatic: true,
              lexicalKeywords: ["horizont", "infinit", "vast", "planic", "imensi"]),
        .init(id: .abertEspacamentoLetras, name: "Espaçamento entre Letras", sourceBadge: "P11", parameter: .abertura, polarity: .both, channel: .typography, primitive: .typography,
              isStatic: true,
              lexicalKeywords: ["espac", "amplo", "abert", "camp", "quarto"]),
        .init(id: .abertPingentesVento, name: "Pingentes no Vento", sourceBadge: "C49", parameter: .abertura, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["vent", "bris", "ceu", "ar", "livre", "arejad"]),

        // MARK: Distância (3)
        .init(id: .distEngrenagemRelogio, name: "Engrenagem de Relógio", sourceBadge: "C28", parameter: .distancia, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["relog", "hora", "tique", "passad", "anos", "ontem"]),
        .init(id: .distArrastoTemporal, name: "Arrasto Temporal", sourceBadge: "C333", parameter: .distancia, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["lembr", "memor", "infanc", "saudad", "antig"]),
        .init(id: .distVisaoDupla, name: "Visão Dupla", sourceBadge: "C353", parameter: .distancia, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              lexicalKeywords: ["sonh", "devanei", "alucin", "irreal", "nevo", "dist"]),

        // MARK: Volume (6: 1 silêncio -, 5 grito +)
        .init(id: .volSolidToOutline, name: "Solid To Outline", sourceBadge: "#63", parameter: .volume, polarity: .negative, channel: .overlay, primitive: .gpuShader,
              isStatic: true, blockedOnDecorativeFont: true,
              lexicalKeywords: ["silenc", "sussurr", "calad", "mudo", "murmur", "baix"]),
        .init(id: .volGritoExplosivo, name: "Grito Explosivo", sourceBadge: "C307", parameter: .volume, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["grit", "berr", "estrond", "trovao", "estour"]),
        .init(id: .volPanoramica3D, name: "Panorâmica 3D", sourceBadge: "C264", parameter: .volume, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["salao", "palc", "alto", "vozes", "coro"]),
        .init(id: .volOndasEco, name: "Ondas de Eco", sourceBadge: "C67", parameter: .volume, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              isHeavyGPU: true,
              lexicalKeywords: ["eco", "resso", "reverb", "clamor"]),
        .init(id: .volEcoDirecional, name: "Eco Direcional", sourceBadge: "C268", parameter: .volume, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              lexicalKeywords: ["barulh", "ruid", "som", "zumb"]),
        .init(id: .volBerroDistorcido, name: "Berro Distorcido", sourceBadge: "C385", parameter: .volume, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              isStatic: true,
              lexicalKeywords: ["berr", "ensurdec", "urrar", "rugid", "escandal"]),

        // MARK: Tom (1)
        .init(id: .tomFonte, name: "Alterar as 4 Fontes", sourceBadge: "P14", parameter: .tom, polarity: .both, channel: .typography, primitive: .typography,
              isStatic: true),

        // MARK: Peso (9: 4 leve -, 5 pesado +)
        .init(id: .pesoFlutuacaoZeroG, name: "Flutuação Zero-G", sourceBadge: "C38", parameter: .peso, polarity: .negative, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["flutu", "espac", "gravidad", "pair", "etere"]),
        .init(id: .pesoAntiGravity, name: "Anti Gravity", sourceBadge: "#70", parameter: .peso, polarity: .negative, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["voar", "voand", "subi", "balao", "pipa"]),
        .init(id: .pesoFlutuarTopo, name: "Flutuar para o Topo", sourceBadge: "P15", parameter: .peso, polarity: .negative, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["leve", "pluma", "pena", "nuvem", "topo"]),
        .init(id: .pesoMovieCredits, name: "Movie Credits", sourceBadge: "#80", parameter: .peso, polarity: .negative, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["sobe", "elev", "credit", "ascend"]),
        .init(id: .pesoDropIn, name: "Drop In", sourceBadge: "#14", parameter: .peso, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["cai", "qued", "despenc", "tomb"]),
        .init(id: .pesoRastroVertical, name: "Rastro Vertical", sourceBadge: "C202", parameter: .peso, polarity: .positive, channel: .entrance, primitive: .wordLayer,
              isHeavyGPU: true,
              lexicalKeywords: ["mergulh", "abism", "precipic", "chumbo"]),
        .init(id: .pesoEsmagar, name: "Esmagar", sourceBadge: "C302", parameter: .peso, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["esmag", "achatar", "martel", "pedr", "bigorn"]),
        .init(id: .pesoAfundarComPeso, name: "Afundar com Peso", sourceBadge: "P16", parameter: .peso, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["afund", "fard", "pesad", "carreg", "arrast"]),
        .init(id: .pesoFallingLeaves, name: "Falling Leaves", sourceBadge: "#71", parameter: .peso, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["folh", "outon", "caindo", "desce"]),

        // MARK: Fluidez (13: 2 rígido -, 11 fluido +)
        .init(id: .fluidRigidezMecanica, name: "Rigidez Mecânica", sourceBadge: "C358", parameter: .fluidez, polarity: .negative, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["trav", "mecan", "robo", "rigid", "duro", "engess", "petrif"]),
        .init(id: .fluidBrilhoMetalico, name: "Brilho Metálico", sourceBadge: "C60", parameter: .fluidez, polarity: .negative, channel: .surface, primitive: .surfaceStyle,
              lexicalKeywords: ["metal", "aco", "ferro", "cromo", "cortant", "lamin"]),
        .init(id: .fluidWaterDrop, name: "Water Drop", sourceBadge: "#69", parameter: .fluidez, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              lexicalKeywords: ["got", "ping", "chuv", "resping", "lagrim"]),
        .init(id: .fluidDerretido, name: "Derretido", sourceBadge: "C371", parameter: .fluidez, polarity: .positive, channel: .typography, primitive: .glyphTransform,
              isStatic: true, coupledSurfaceColor: false,
              lexicalKeywords: ["derret", "amolec", "fundid", "cera"]),
        .init(id: .fluidWave, name: "Wave", sourceBadge: "#23", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["ond", "mare", "ocean", "mar"]),
        .init(id: .fluidOndaInclinacao, name: "Onda de Inclinação", sourceBadge: "C58", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["desliz", "suav", "embal", "balanc"]),
        .init(id: .fluidDancaTipografica, name: "Dança Tipográfica", sourceBadge: "C62", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["danc", "ging", "ritm", "flui"]),
        .init(id: .fluidOndulacaoVertical, name: "Ondulação Vertical", sourceBadge: "P17", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["ondul", "corrent", "rio", "flux"]),
        .init(id: .fluidFluidoViscoso, name: "Fluido Viscoso", sourceBadge: "C356", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              lexicalKeywords: ["escorr", "viscos", "mel", "gotej", "tinta", "lama"]),
        .init(id: .fluidEspelhoLiquido, name: "Espelho Líquido", sourceBadge: "C44", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              coupledSurfaceColor: true,
              lexicalKeywords: ["espelh", "lago", "liquid", "agu"]),
        .init(id: .fluidSubmarino, name: "Submarino", sourceBadge: "C61", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .glyphTransform,
              coupledSurfaceColor: true,
              lexicalKeywords: ["submar", "fundo", "mergulh", "profund"]),
        .init(id: .fluidLuzPiscina, name: "Luz de Piscina", sourceBadge: "C140", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .surfaceStyle,
              coupledSurfaceColor: true,
              lexicalKeywords: ["piscin", "cristal", "banho", "claro"]),
        .init(id: .fluidRefracaoSubmersa, name: "Refração Submersa", sourceBadge: "C357", parameter: .fluidez, polarity: .positive, channel: .continuous, primitive: .wordLayer,
              coupledSurfaceColor: true,
              lexicalKeywords: ["ocean", "mar", "submers", "ondas", "torrente"]),

        // MARK: Valência (13: 7 positivo +, 6 negativo — efeitos fortes exigem |valencia| >= 2)
        .init(id: .valCaleidoscopioPrismatico, name: "Caleidoscópio Prismático", sourceBadge: "C12", parameter: .valencia, polarity: .positive, channel: .entrance, primitive: .wordLayer,
              minAbsScore: 2,
              lexicalKeywords: ["magi", "encant", "prism", "maravilh"]),
        .init(id: .valCascataArcoIris, name: "Cascata Arco-Íris", sourceBadge: "C18", parameter: .valencia, polarity: .positive, channel: .entrance, primitive: .glyphTransform,
              minAbsScore: 2,
              lexicalKeywords: ["alegri", "feliz", "festa", "comemor"]),
        .init(id: .valFluxoArcoIris, name: "Fluxo Arco-Íris", sourceBadge: "C36", parameter: .valencia, polarity: .positive, channel: .surface, primitive: .surfaceStyle,
              minAbsScore: 2,
              lexicalKeywords: ["arco", "color", "eufor", "extas", "paraiso"]),
        .init(id: .valLampadaLava, name: "Lâmpada de Lava", sourceBadge: "C137", parameter: .valencia, polarity: .positive, channel: .surface, primitive: .surfaceStyle,
              minAbsScore: 2, isHeavyGPU: true,
              lexicalKeywords: ["amor", "paix", "carinh", "prazer"]),
        .init(id: .valPulsoSaturacao, name: "Pulso de Saturação", sourceBadge: "C242", parameter: .valencia, polarity: .positive, channel: .surface, primitive: .surfaceStyle,
              minAbsScore: 1,
              lexicalKeywords: ["paz", "seren", "tranquil", "alivi", "esperanc"]),
        .init(id: .valRotacaoMatiz, name: "Rotação de Matiz", sourceBadge: "C243", parameter: .valencia, polarity: .positive, channel: .surface, primitive: .surfaceStyle,
              minAbsScore: 2,
              lexicalKeywords: ["vibr", "radiant", "sonh", "felicidad"]),
        .init(id: .valSombrasGemeas, name: "Sombras Gêmeas", sourceBadge: "C170", parameter: .valencia, polarity: .positive, channel: .overlay, primitive: .wordLayer,
              minAbsScore: 1,
              lexicalKeywords: ["abrac", "junt", "ternur", "orgulh", "content"]),
        .init(id: .valImpressaoCMYK, name: "Impressão CMYK", sourceBadge: "C109", parameter: .valencia, polarity: .negative, channel: .entrance, primitive: .wordLayer,
              minAbsScore: 2,
              lexicalKeywords: ["choqu", "sust", "decepc", "frustr"]),
        .init(id: .valCameraTermica, name: "Câmera Térmica", sourceBadge: "C66", parameter: .valencia, polarity: .negative, channel: .surface, primitive: .surfaceStyle,
              minAbsScore: 2,
              lexicalKeywords: ["raiv", "furi", "odio", "irrit", "violenc"]),
        .init(id: .valMercurioLiquido, name: "Mercúrio Líquido", sourceBadge: "C244", parameter: .valencia, polarity: .negative, channel: .surface, primitive: .surfaceStyle,
              minAbsScore: 1,
              lexicalKeywords: ["trist", "luto", "desanim", "chate", "incomod", "melancol"]),
        .init(id: .valAberracaoCromatica, name: "Aberração Cromática", sourceBadge: "C41", parameter: .valencia, polarity: .negative, channel: .overlay, primitive: .wordLayer,
              minAbsScore: 2,
              lexicalKeywords: ["panic", "horror", "desesper", "terror", "surt"]),
        .init(id: .valAnaglifo3D, name: "Anáglifo 3D", sourceBadge: "C97", parameter: .valencia, polarity: .negative, channel: .overlay, primitive: .wordLayer,
              minAbsScore: 2, isStatic: true,
              lexicalKeywords: ["medo", "angust", "dor", "perda"]),
        .init(id: .valCartasCMYOrbita, name: "Cartas CMY em Órbita", sourceBadge: "C167", parameter: .valencia, polarity: .negative, channel: .overlay, primitive: .wordLayer,
              minAbsScore: 2,
              lexicalKeywords: ["repuls", "noj", "pessim", "mal"])
    ]

    static let byID: [MorphEffectID: MorphEffectSpec] = Dictionary(
        uniqueKeysWithValues: allSpecs.map { ($0.id, $0) }
    )

    static let byParameter: [MorphParameter: [MorphEffectSpec]] = Dictionary(
        grouping: allSpecs,
        by: \.parameter
    )

    static func spec(for id: MorphEffectID) -> MorphEffectSpec {
        byID[id]!
    }

    static func eligibleSpecs(
        for parameter: MorphParameter,
        score: Int,
        isDecorativeFont: Bool
    ) -> [MorphEffectSpec] {
        guard score != 0 else { return [] }
        let absScore = abs(score)
        return (byParameter[parameter] ?? []).filter { spec in
            guard spec.polarity.matches(score: score) else { return false }
            guard absScore >= spec.minAbsScore else { return false }
            if isDecorativeFont {
                if spec.blockedOnDecorativeFont || spec.channel == .surface {
                    return false
                }
            }
            return true
        }
    }

    static func runSelfCheck() {
        assert(MorphEffectID.allCases.count == 97, "Esperados 97 IDs no catálogo, encontrados \(MorphEffectID.allCases.count)")
        assert(allSpecs.count == 97, "Esperadas 97 specs no catálogo, encontradas \(allSpecs.count)")
        assert(byID.count == allSpecs.count, "IDs duplicados no MorphEffectCatalog")

        for param in MorphParameter.allCases {
            let specs = byParameter[param] ?? []
            assert(!specs.isEmpty, "Parâmetro \(param.rawValue) sem specs no catálogo")
            if param.isUnipolar {
                assert(specs.allSatisfy { $0.polarity != .negative }, "Parâmetro unipolar \(param.rawValue) não pode ter spec negativa")
            }
        }

        // Invariantes das ressalvas aprovadas
        assert(spec(for: .tensAmeacaLatente).parameter == .tensao)
        assert((byParameter[.tensao] ?? []).allSatisfy { $0.polarity == .positive }, "Tensão (-) não deve ter animações próprias")
        assert(spec(for: .luzEscurecimento).parameter == .luz && spec(for: .luzEscurecimento).polarity == .negative)
        assert(spec(for: .distVisaoDupla).parameter == .distancia && spec(for: .distVisaoDupla).polarity == .positive)
        assert(spec(for: .luzFlicker).parameter == .luz)
        assert(spec(for: .domEspessuraFonte).parameter == .dominio)
        assert(spec(for: .pesoFallingLeaves).parameter == .peso && spec(for: .pesoFallingLeaves).polarity == .positive)
        assert(spec(for: .fluidDerretido).coupledSurfaceColor == false)
        assert(spec(for: .andLetargia).parameter == .andamento && spec(for: .andLetargia).polarity == .negative)
        assert(spec(for: .valFluxoArcoIris).minAbsScore >= 2 && spec(for: .valAberracaoCromatica).minAbsScore >= 2)
    }
}
