import Foundation
import CoreGraphics

// MARK: - Plano Imutável de Animação por Palavra (Resolvido 1x Fora do Loop de 60fps)

struct ResolvedEffectSlot: Equatable, Sendable {
    let effectID: MorphEffectID
    let parameter: MorphParameter
    let score: Int
    /// Fator contínuo de amplitude baseado em |nota|: 0.60 (nota 1) até 1.15 (nota 5).
    let intensity: Double

    var spec: MorphEffectSpec {
        MorphEffectCatalog.spec(for: effectID)
    }

    init(spec: MorphEffectSpec, score: Int) {
        self.effectID = spec.id
        self.parameter = spec.parameter
        self.score = score
        let clampedMag = max(1, min(5, abs(score)))
        self.intensity = 0.60 + Double(clampedMag - 1) * 0.1375
    }
}

struct WordAnimationPlan: Equatable, Sendable {
    let wordIndex: Int
    let word: String
    let scores: ParameterScores
    let typography: ResolvedTypography

    /// Canal 1 (complementar à fonte): `Ultra Condensado`, `Ultra Estirado`, `Espaçamento entre Letras` ou `Derretido`.
    let staticStructure: ResolvedEffectSlot?
    /// Canal 2: Cor / Preenchimento (máx. 1; sempre `nil` em `CatsFont` e `SnowtopCaps`).
    let surface: ResolvedEffectSlot?
    /// Canal 3: Entrada 1x na revelação da frase (máx. 1).
    let entrance: ResolvedEffectSlot?
    /// Canal 4: Movimento Contínuo (máx. 1).
    let continuous: ResolvedEffectSlot?
    /// Canal 5: Overlay / Filtro / Eco (máx. 1).
    let overlay: ResolvedEffectSlot?

    /// Multiplicador de velocidade herdado de `Ativação` (quando `-` ou quando outro parâmetro venceu o Canal 4).
    let speedMultiplier: Double
    /// Freio de GPU ativado na View quando >= 80% de uma frase longa recebe o mesmo efeito pesado.
    let isEcoMode: Bool

    /// Verdadeiro quando o efeito do Canal 4 traz paleta acoplada (ex.: Fogo Vivo, Espelho Líquido)
    /// e o Canal 2 está livre sem fonte decorativa protegida.
    var usesCoupledMotionSurfaceColor: Bool {
        surface == nil && !typography.isDecorativeSingleWeight && (continuous?.spec.coupledSurfaceColor == true)
    }

    var allActiveSlots: [ResolvedEffectSlot] {
        [staticStructure, surface, entrance, continuous, overlay].compactMap { $0 }
    }

    // MARK: - Flags de Capacidade p/ Fast-Path e Isolamento de Timeline (60fps)

    /// Verdadeiro apenas quando a palavra precisa de relógio contínuo a 60fps.
    /// Palavras estáticas ou só com Entrada 1x (após concluir) consomem 0% de CPU por frame.
    var hasContinuousTimeAnimation: Bool {
        if continuous != nil { return true }
        if surface != nil { return true }
        if let overlay, !overlay.spec.isStatic { return true }
        return false
    }

    /// Duração total da Entrada 1x (incluindo stagger por caractere) antes de pausar o relógio.
    var entranceTotalDuration: Double {
        guard let entrance else { return 0 }
        let baseDur: Double = {
            switch entrance.effectID {
            case .andSpeedDash, .ativBounce, .ativBounceInRight, .ativFlipIn, .pesoDropIn, .fluidWaterDrop:
                return 0.60
            case .tensGlitch:
                return 0.48
            case .andRollIn, .ativShakeY, .tensTada, .tensSqueezeExpand, .volGritoExplosivo, .ativRicocheteLateral, .kwHeartbeatBurst:
                return 0.80
            case .kwBolhasSabao:
                return 0.95
            case .kwRoloCassino, .kwTracoParaTinta:
                return 1.10
            case .luzGlowIn, .luzFlicker, .luzFlickerIn, .abertTrackingContract, .distArrastoTemporal, .pesoAfundarComPeso, .kwPenduloNewton:
                return 1.15
            case .valImpressaoCMYK:
                return 1.30
            default:
                return 0.92
            }
        }()
        let stagger = entranceNeedsPerChar ? Double(max(1, word.count)) * 0.06 : 0.0
        return baseDur + stagger + 0.08
    }

    var entranceNeedsPerChar: Bool {
        guard let id = entrance?.effectID else { return false }
        switch id {
        case .tensTensaoContida, .volGritoExplosivo, .pesoEsmagar, .pesoAfundarComPeso,
             .valCaleidoscopioPrismatico, .valImpressaoCMYK, .pesoRastroVertical, .kwTracoParaTinta:
            return false
        default:
            return true
        }
    }

    /// Verdadeiro quando o estado estacionário (sem contar a Entrada 1x) exige renderização caractere a caractere.
    var steadyNeedsPerChar: Bool {
        if let sid = staticStructure?.effectID {
            switch sid {
            case .fluidDerretido, .kwArcoCurvado, .kwEscadaDiagonal, .kwLinhaDesconstruida:
                return true
            default:
                break
            }
        }
        if surface?.effectID == .valFluxoArcoIris { return true }
        if usesCoupledMotionSurfaceColor && continuous?.effectID == .fluidEspelhoLiquido { return true }
        if let cid = continuous?.effectID {
            switch cid {
            case .fragCisao, .calMiragemCalor, .fluidRefracaoSubmersa, .andLetargia,
                 .tensPressaoCrescente, .volPanoramica3D, .fluidRigidezMecanica, .pesoFlutuarTopo,
                 .kwRespiracaoOrganica, .kwTontura:
                return false
            default:
                return true
            }
        }
        return false
    }

    func needsPerCharLayout(entranceActive: Bool) -> Bool {
        steadyNeedsPerChar || (entranceActive && entranceNeedsPerChar)
    }

    var usesBlurModifier: Bool {
        continuous?.effectID == .andLetargia
            || continuous?.effectID == .fluidSubmarino
            || entrance?.effectID == .distArrastoTemporal
            || entrance?.effectID == .kwRoloCassino
    }

    var uses3DRotationModifier: Bool {
        entrance?.effectID == .ativFlipIn
            || entrance?.effectID == .ativCartasZigueZague
            || continuous?.effectID == .volPanoramica3D
    }

    var usesSkewModifier: Bool {
        entrance?.effectID == .fragDespedacar
            || entrance?.effectID == .andSpeedDash
            || continuous?.effectID == .andLetargia
            || continuous?.effectID == .calFogoVivo
            || continuous?.effectID == .tensAmeacaLatente
            || continuous?.effectID == .fluidRigidezMecanica
            || continuous?.effectID == .fluidOndaInclinacao
            || continuous?.effectID == .kwCaosImprevisivel
            || continuous?.effectID == .kwTontura
    }

    var usesGlowModifier: Bool {
        entrance?.effectID == .calChamaAscendente
            || entrance?.effectID == .luzGlowIn
            || entrance?.effectID == .luzFlicker
            || entrance?.effectID == .luzFlickerIn
            || continuous?.effectID == .calFogoVivo
            || continuous?.effectID == .kwLetreiroNeon
    }

    /// Folga horizontal por lado (pt) reservada para efeitos que escalam, inclinam ou deslocam
    /// visualmente para fora da caixa de `sizeThatFits`, evitando palavras aglutinadas.
    var horizontalVisualOverhang: CGFloat {
        let estW = CGFloat(max(1, word.count)) * typography.fontSize * 0.62
        var maxExtraScaleX: Double = 0
        var shiftX: Double = 0

        if let s = staticStructure {
            switch s.effectID {
            case .abertUltraEstirado:
                let k = min(1.0, max(0.45, s.intensity * 0.85))
                maxExtraScaleX = max(maxExtraScaleX, 0.26 * k)
            default:
                break
            }
        }

        if let c = continuous {
            switch c.effectID {
            case .domLenteInflada:
                let k = min(1.0, c.intensity)
                maxExtraScaleX = max(maxExtraScaleX, 0.22 * k)
                shiftX += 8.0 * k
            case .kwCaosImprevisivel:
                maxExtraScaleX = max(maxExtraScaleX, 0.26)
                shiftX += 7.0
            case .kwRespiracaoOrganica:
                maxExtraScaleX = max(maxExtraScaleX, 0.09)
            case .tensPressaoCrescente:
                maxExtraScaleX = max(maxExtraScaleX, 0.20 * c.intensity)
                shiftX += 3.5
            case .ativPulaPulaElastico:
                maxExtraScaleX = max(maxExtraScaleX, 0.22 * c.intensity)
            case .ativPulsoRitmicoRegular:
                maxExtraScaleX = max(maxExtraScaleX, 0.20 * c.intensity)
            case .fragCisao:
                shiftX += 12.0 * c.intensity
            case .calMiragemCalor:
                shiftX += 7.5 * c.intensity
            case .fluidRefracaoSubmersa:
                shiftX += 6.5 * c.intensity
            case .fluidOndaInclinacao, .calFogoVivo, .andLetargia, .kwTontura:
                shiftX += 8.0
            case .tensOndaSismica, .tensVibracaoPalavra, .ativMicroOrbitas, .pesoFlutuacaoZeroG, .pesoFallingLeaves, .kwStopMotion6fps:
                shiftX += 5.0
            default:
                break
            }
        }

        if let o = overlay {
            switch o.effectID {
            case .volBerroDistorcido:
                maxExtraScaleX = max(maxExtraScaleX, 0.20 * o.intensity)
                shiftX += 3.0
            case .volOndasEco:
                maxExtraScaleX = max(maxExtraScaleX, 0.24 * o.intensity)
            case .fragCorteAoMeio:
                shiftX += 7.0 * o.intensity
            case .fragRachado:
                shiftX += 6.0 * o.intensity
            case .luzEscurecimento:
                shiftX += 9.0 * min(1.0, o.intensity)
            case .distVisaoDupla:
                shiftX += 8.5 * o.intensity
            case .volEcoDirecional:
                shiftX += 11.0 * o.intensity
            case .valSombrasGemeas:
                shiftX += 8.0 * o.intensity
            case .valAberracaoCromatica, .valCartasCMYOrbita:
                shiftX += 5.5 * o.intensity
            case .valAnaglifo3D:
                shiftX += 4.0 * o.intensity
            case .kwSombraOrbitante:
                shiftX += 10.0
            case .calGelidoQuebradico:
                shiftX += 6.0
            case .kwTarjaCensurada:
                shiftX += 4.0
            case .kwEstouroPopArt:
                shiftX += 6.0
            default:
                break
            }
        }

        let total = Double(estW) * maxExtraScaleX * 0.5 + shiftX
        guard total > 0.1 else { return 0 }
        return min(34.0, CGFloat(ceil(total)))
    }

    /// Folga vertical (topo/base em pt) reservada para efeitos que esticam ou deslocam entre linhas.
    var verticalVisualOverhang: (top: CGFloat, bottom: CGFloat) {
        var top: CGFloat = 0
        var bottom: CGFloat = 0

        if let s = staticStructure {
            switch s.effectID {
            case .fluidDerretido:
                bottom = max(bottom, typography.fontSize * 0.42)
            case .kwArcoCurvado:
                top = max(top, 12)
                bottom = max(bottom, 12)
            case .kwEscadaDiagonal:
                top = max(top, 18)
                bottom = max(bottom, 18)
            case .kwLinhaDesconstruida:
                top = max(top, 8)
                bottom = max(bottom, 8)
            case .abertUltraCondensado:
                top = max(top, typography.fontSize * 0.18)
                bottom = max(bottom, typography.fontSize * 0.18)
            default:
                break
            }
        }

        if let c = continuous {
            switch c.effectID {
            case .fluidFluidoViscoso:
                bottom = max(bottom, typography.fontSize * 0.44)
            case .pesoFlutuarTopo, .ativPulaPulaElastico, .fluidDancaTipografica:
                top = max(top, 16)
            case .fluidWave:
                top = max(top, 13)
            case .kwArcoFlexivel:
                top = max(top, 14)
                bottom = max(bottom, 14)
            case .fluidOndulacaoVertical, .fluidEspelhoLiquido, .fluidSubmarino,
                 .pesoFlutuacaoZeroG, .pesoAntiGravity, .pesoFallingLeaves, .pesoMovieCredits,
                 .domLenteInflada, .kwCaosImprevisivel:
                top = max(top, 10)
                bottom = max(bottom, 10)
            case .kwTontura:
                top = max(top, 6)
                bottom = max(bottom, 6)
            default:
                break
            }
        }

        if let e = entrance, e.effectID == .pesoAfundarComPeso {
            bottom = max(bottom, CGFloat(min(20.0, 14.0 * e.intensity)))
        }

        if let o = overlay {
            switch o.effectID {
            case .kwSombraOrbitante:
                top = max(top, 8)
                bottom = max(bottom, 8)
            case .calNevoaAscendente, .calSmokeOut:
                top = max(top, 12)
            case .kwEstouroPopArt:
                top = max(top, 6)
                bottom = max(bottom, 6)
            default:
                break
            }
        }

        return (min(24.0, ceil(top)), min(24.0, ceil(bottom)))
    }
}

// MARK: - Motor de Resolução (Peça A: Polo + Afinidade Lexical + Hash; Peça B: 5 Canais)

enum WordEffectResolver {
    private static let sensorialSurfacePriority: Set<MorphParameter> = [.calor, .fluidez, .luz]

    static func resolvePhrase(
        tokens: [String],
        scoresPerWord: [ParameterScores],
        phraseSeed: Int,
        baseFontSize: CGFloat = 34.0
    ) -> [WordAnimationPlan] {
        guard !tokens.isEmpty else { return [] }

        let wordTriggers = MorphWordTriggerCatalog.matchPhrase(tokens: tokens)
        var plans: [WordAnimationPlan] = tokens.enumerated().map { index, word in
            let scores = index < scoresPerWord.count ? scoresPerWord[index] : ParameterScores()
            return resolveWord(
                word: word,
                wordIndex: index,
                scores: scores,
                phraseSeed: phraseSeed,
                baseFontSize: baseFontSize,
                forcedEffectID: wordTriggers[index]
            )
        }

        // Freio de FPS na View (Peça C adiada): se >= 80% das palavras de uma frase longa (> 4 tokens)
        // receberem efeito pesado do mesmo parâmetro, marca `isEcoMode` nessas palavras.
        if plans.count > 4 {
            var heavyCountsByParam: [MorphParameter: Int] = [:]
            for plan in plans {
                let heavyParams = Set(plan.allActiveSlots.filter { $0.spec.isHeavyGPU }.map(\.parameter))
                for param in heavyParams {
                    heavyCountsByParam[param, default: 0] += 1
                }
            }

            let floodedParams = Set(heavyCountsByParam.compactMap { param, count in
                (count * 5 >= plans.count * 4) ? param : nil
            })

            if !floodedParams.isEmpty {
                plans = plans.map { plan in
                    let hit = plan.allActiveSlots.contains { $0.spec.isHeavyGPU && floodedParams.contains($0.parameter) }
                    guard hit else { return plan }
                    return WordAnimationPlan(
                        wordIndex: plan.wordIndex,
                        word: plan.word,
                        scores: plan.scores,
                        typography: plan.typography,
                        staticStructure: plan.staticStructure,
                        surface: plan.surface,
                        entrance: plan.entrance,
                        continuous: plan.continuous,
                        overlay: plan.overlay,
                        speedMultiplier: plan.speedMultiplier,
                        isEcoMode: true
                    )
                }
            }
        }

        return plans
    }

    static func resolveWord(
        word: String,
        wordIndex: Int,
        scores: ParameterScores,
        phraseSeed: Int,
        baseFontSize: CGFloat = 34.0,
        forcedEffectID: MorphEffectID? = nil
    ) -> WordAnimationPlan {
        let fontSeed = Int(truncatingIfNeeded: MorphDeterministicHash.mix(phraseSeed, wordIndex, 911))
        let typography = FontRegistrationManager.shared.resolveTypography(
            tomScore: scores[.tom],
            volumeScore: scores[.volume],
            dominioScore: scores[.dominio],
            calorScore: scores[.calor],
            felineContext: FontRegistrationManager.isFelineTerm(word),
            baseSize: baseFontSize,
            tieBreakSeed: fontSeed
        )
        let isDecorative = typography.isDecorativeSingleWeight
        let wordTokens = normalizedWordTokens(word)

        let activeParams = scores.activeParameters
        let tensaoReliefMag = scores[.tensao] < 0 ? abs(scores[.tensao]) : 0

        // 1. Canal 3 (Entrada 1x): todos os parâmetros ativos com entradas elegíveis competem por maior |nota|.
        var entranceSlot = resolveSingleChannel(
            channel: .entrance,
            activeParams: activeParams,
            wordTokens: wordTokens,
            wordIndex: wordIndex,
            phraseSeed: phraseSeed,
            isDecorativeFont: isDecorative,
            preferSensorialOverValencia: false
        )
        if let candidate = entranceSlot, tensaoReliefBeats(
            reliefMag: tensaoReliefMag,
            challengerMag: abs(candidate.score),
            wordIndex: wordIndex,
            phraseSeed: phraseSeed,
            channel: .entrance
        ) {
            entranceSlot = nil
        }

        // 2. Estrutura estática de Abertura no Canal 1 (excluindo controles sempre ativos de fonte).
        var staticStructureSlot: ResolvedEffectSlot? = nil
        if scores[.abertura] != 0 {
            let abertStatic = MorphEffectCatalog
                .eligibleSpecs(for: .abertura, score: scores[.abertura], isDecorativeFont: isDecorative)
                .filter { $0.channel == .typography && !$0.isAlwaysOnTypographyControl }
            if let picked = pickEffect(
                from: abertStatic,
                wordTokens: wordTokens,
                wordIndex: wordIndex,
                phraseSeed: phraseSeed,
                salt: MorphDeterministicHash.stableStringID("abertura_static")
            ) {
                staticStructureSlot = ResolvedEffectSlot(spec: picked, score: scores[.abertura])
            }
        }

        // 3. Canais persistentes (Canal 2 Cor, Canal 4 Movimento Contínuo, Canal 5 Overlay + Derretido em Fluidez).
        // Passo A: cada parâmetro ativo escolhe 1 efeito persistente preferido (Peça A: polo -> afinidade lexical -> hash).
        var preferredByChannel: [MorphEffectChannel: [(param: MorphParameter, score: Int, spec: MorphEffectSpec)]] = [:]
        var persistentPoolByParam: [MorphParameter: (score: Int, specs: [MorphEffectSpec])] = [:]

        for (param, score) in activeParams {
            let specs = MorphEffectCatalog
                .eligibleSpecs(for: param, score: score, isDecorativeFont: isDecorative)
                .filter { spec in
                    spec.channel == .surface
                        || spec.channel == .continuous
                        || spec.channel == .overlay
                        || spec.id == .fluidDerretido
                }
            guard !specs.isEmpty else { continue }
            persistentPoolByParam[param] = (score, specs)

            let salt = MorphDeterministicHash.stableStringID("persist_\(param.catalogoId)")
            if let picked = pickEffect(
                from: specs,
                wordTokens: wordTokens,
                wordIndex: wordIndex,
                phraseSeed: phraseSeed,
                salt: salt
            ) {
                preferredByChannel[picked.channel, default: []].append((param, score, picked))
            }
        }

        var winners: [MorphEffectChannel: ResolvedEffectSlot] = [:]
        var assignedParams = Set<MorphParameter>()

        for channel in [MorphEffectChannel.surface, .continuous, .overlay, .typography] {
            guard let candidates = preferredByChannel[channel], !candidates.isEmpty else { continue }
            if channel == .typography && staticStructureSlot != nil {
                // Se Abertura já ocupou `staticStructure`, só substitui se Fluidez (Derretido) tiver nota maior.
                let abertMag = abs(staticStructureSlot!.score)
                let winner = electWinner(
                    candidates: candidates,
                    wordIndex: wordIndex,
                    phraseSeed: phraseSeed,
                    channel: channel,
                    preferSensorialOverValencia: false
                )
                if abs(winner.score) > abertMag {
                    staticStructureSlot = ResolvedEffectSlot(spec: winner.spec, score: winner.score)
                    assignedParams.insert(winner.param)
                }
                continue
            }

            let winner = electWinner(
                candidates: candidates,
                wordIndex: wordIndex,
                phraseSeed: phraseSeed,
                channel: channel,
                preferSensorialOverValencia: channel == .surface
            )
            let slot = ResolvedEffectSlot(spec: winner.spec, score: winner.score)
            if channel == .typography {
                staticStructureSlot = slot
            } else {
                winners[channel] = slot
            }
            assignedParams.insert(winner.param)
        }

        // Passo B: parâmetros que perderam seu canal preferido podem preencher canais persistentes ainda vagos.
        for channel in [MorphEffectChannel.surface, .continuous, .overlay] where winners[channel] == nil {
            var fallbackCandidates: [(param: MorphParameter, score: Int, spec: MorphEffectSpec)] = []
            for (param, entry) in persistentPoolByParam where !assignedParams.contains(param) {
                let matching = entry.specs.filter { $0.channel == channel }
                guard !matching.isEmpty else { continue }
                let salt = MorphDeterministicHash.stableStringID("fallback_\(param.catalogoId)_\(channel.rawValue)")
                if let picked = pickEffect(
                    from: matching,
                    wordTokens: wordTokens,
                    wordIndex: wordIndex,
                    phraseSeed: phraseSeed,
                    salt: salt
                ) {
                    fallbackCandidates.append((param, entry.score, picked))
                }
            }
            guard !fallbackCandidates.isEmpty else { continue }
            let winner = electWinner(
                candidates: fallbackCandidates,
                wordIndex: wordIndex,
                phraseSeed: phraseSeed,
                channel: channel,
                preferSensorialOverValencia: channel == .surface
            )
            winners[channel] = ResolvedEffectSlot(spec: winner.spec, score: winner.score)
            assignedParams.insert(winner.param)
        }

        var continuousSlot = winners[.continuous]
        if let candidate = continuousSlot, tensaoReliefBeats(
            reliefMag: tensaoReliefMag,
            challengerMag: abs(candidate.score),
            wordIndex: wordIndex,
            phraseSeed: phraseSeed,
            channel: .continuous
        ) {
            continuousSlot = nil
        }
        var finalStatic = staticStructureSlot
        var finalSurface = isDecorative ? nil : winners[.surface]
        var finalEntrance = entranceSlot
        var finalContinuous = continuousSlot
        var finalOverlay = winners[.overlay]

        // Gatilhos fixos por palavra-chave (18 regras): sempre aplicam no seu canal, deixando os demais livres.
        if let triggerID = forcedEffectID ?? MorphWordTriggerCatalog.matchSingleWord(word) {
            let spec = MorphEffectCatalog.spec(for: triggerID)
            let mag = max(abs(scores[spec.parameter]), 4)
            let forcedScore = spec.polarity == .negative ? -mag : mag
            let slot = ResolvedEffectSlot(spec: spec, score: forcedScore)

            switch spec.channel {
            case .typography:
                finalStatic = slot
            case .surface:
                if !isDecorative { finalSurface = slot }
            case .entrance:
                finalEntrance = slot
            case .continuous:
                finalContinuous = slot
                if triggerID == .kwLetreiroNeon && !isDecorative {
                    finalSurface = nil
                }
            case .overlay:
                finalOverlay = slot
                if triggerID == .kwEstouroPopArt && !isDecorative {
                    finalSurface = nil
                }
            }
        }

        let speedMultiplier = resolveSpeedMultiplier(
            ativacaoScore: scores[.ativacao],
            ativacaoWonContinuous: finalContinuous?.parameter == .ativacao
        )

        return WordAnimationPlan(
            wordIndex: wordIndex,
            word: word,
            scores: scores,
            typography: typography,
            staticStructure: finalStatic,
            surface: finalSurface,
            entrance: finalEntrance,
            continuous: finalContinuous,
            overlay: finalOverlay,
            speedMultiplier: speedMultiplier,
            isEcoMode: false
        )
    }

    // MARK: - Helpers Internos

    private static func resolveSingleChannel(
        channel: MorphEffectChannel,
        activeParams: [(MorphParameter, Int)],
        wordTokens: [String],
        wordIndex: Int,
        phraseSeed: Int,
        isDecorativeFont: Bool,
        preferSensorialOverValencia: Bool
    ) -> ResolvedEffectSlot? {
        var candidates: [(param: MorphParameter, score: Int, spec: MorphEffectSpec)] = []
        for (param, score) in activeParams {
            let specs = MorphEffectCatalog
                .eligibleSpecs(for: param, score: score, isDecorativeFont: isDecorativeFont)
                .filter { $0.channel == channel }
            guard !specs.isEmpty else { continue }
            let salt = MorphDeterministicHash.stableStringID("ch\(channel.rawValue)_\(param.catalogoId)")
            if let picked = pickEffect(
                from: specs,
                wordTokens: wordTokens,
                wordIndex: wordIndex,
                phraseSeed: phraseSeed,
                salt: salt
            ) {
                candidates.append((param, score, picked))
            }
        }
        guard !candidates.isEmpty else { return nil }
        let winner = electWinner(
            candidates: candidates,
            wordIndex: wordIndex,
            phraseSeed: phraseSeed,
            channel: channel,
            preferSensorialOverValencia: preferSensorialOverValencia
        )
        return ResolvedEffectSlot(spec: winner.spec, score: winner.score)
    }

    /// Peça A: afinidade lexical primeiro; se não casar, sorteio determinístico por hash no polo inteiro.
    private static func pickEffect(
        from pool: [MorphEffectSpec],
        wordTokens: [String],
        wordIndex: Int,
        phraseSeed: Int,
        salt: Int
    ) -> MorphEffectSpec? {
        guard !pool.isEmpty else { return nil }
        if pool.count == 1 { return pool[0] }

        if !wordTokens.isEmpty {
            let lexicalMatches = pool.filter { spec in
                guard !spec.lexicalKeywords.isEmpty else { return false }
                return wordTokens.contains { token in
                    spec.lexicalKeywords.contains { kw in
                        token == kw || (kw.count >= 4 && token.hasPrefix(kw))
                    }
                }
            }
            if !lexicalMatches.isEmpty {
                let idx = MorphDeterministicHash.pickIndex(
                    count: lexicalMatches.count,
                    seed: phraseSeed,
                    wordIndex: wordIndex,
                    salt: salt &+ 17
                )
                return lexicalMatches[idx]
            }
        }

        let idx = MorphDeterministicHash.pickIndex(
            count: pool.count,
            seed: phraseSeed,
            wordIndex: wordIndex,
            salt: salt
        )
        return pool[idx]
    }

    /// Peça B: vence maior |nota|; empate exato no Canal Cor prioriza sensorial > Valência; demais empates por hash.
    private static func electWinner(
        candidates: [(param: MorphParameter, score: Int, spec: MorphEffectSpec)],
        wordIndex: Int,
        phraseSeed: Int,
        channel: MorphEffectChannel,
        preferSensorialOverValencia: Bool
    ) -> (param: MorphParameter, score: Int, spec: MorphEffectSpec) {
        let maxMag = candidates.map { abs($0.score) }.max() ?? 0
        var tied = candidates.filter { abs($0.score) == maxMag }
        if tied.count == 1 { return tied[0] }

        if preferSensorialOverValencia {
            let sensorial = tied.filter { sensorialSurfacePriority.contains($0.param) }
            if !sensorial.isEmpty {
                tied = sensorial
            }
        }
        if tied.count == 1 { return tied[0] }

        let ordered = tied.sorted { $0.param.catalogoId < $1.param.catalogoId }
        let idx = MorphDeterministicHash.pickIndex(
            count: ordered.count,
            seed: phraseSeed,
            wordIndex: wordIndex,
            salt: MorphDeterministicHash.stableStringID("tie_ch\(channel.rawValue)")
        )
        return ordered[idx]
    }

    /// Tensão negativa (alívio) compete nos canais animados para manter a palavra parada (preservando estrutura).
    private static func tensaoReliefBeats(
        reliefMag: Int,
        challengerMag: Int,
        wordIndex: Int,
        phraseSeed: Int,
        channel: MorphEffectChannel
    ) -> Bool {
        guard reliefMag > 0 else { return false }
        if reliefMag != challengerMag { return reliefMag > challengerMag }
        return MorphDeterministicHash.pickIndex(
            count: 2,
            seed: phraseSeed,
            wordIndex: wordIndex,
            salt: MorphDeterministicHash.stableStringID("tensao_relief_ch\(channel.rawValue)")
        ) == 0
    }

    private static func resolveSpeedMultiplier(ativacaoScore: Int, ativacaoWonContinuous: Bool) -> Double {
        if ativacaoScore > 0 && ativacaoWonContinuous {
            return 1.0
        }
        switch max(-5, min(5, ativacaoScore)) {
        case -5: return 0.14
        case -4: return 0.24
        case -3: return 0.38
        case -2: return 0.55
        case -1: return 0.76
        case 0:  return 1.00
        case 1:  return 1.35
        case 2:  return 1.75
        case 3:  return 2.30
        case 4:  return 3.10
        case 5:  return 4.20
        default: return 1.00
        }
    }

    private static func normalizedWordTokens(_ word: String) -> [String] {
        let folded = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
        return folded
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - Auto-verificação das Regras (Debug / Testes Rápidos)

    static func runSelfCheck() {
        MorphEffectCatalog.runSelfCheck()

        // 1. Determinismo com mesmo phraseSeed
        var sExplode = ParameterScores()
        sExplode[.fragmentacao] = 4
        sExplode[.ativacao] = 3
        sExplode[.valencia] = -3
        let runA = resolvePhrase(tokens: ["Tudo", "explodiu"], scoresPerWord: [ParameterScores(), sExplode], phraseSeed: 42)
        let runB = resolvePhrase(tokens: ["Tudo", "explodiu"], scoresPerWord: [ParameterScores(), sExplode], phraseSeed: 42)
        assert(runA == runB, "Mesmo seed deve gerar exatamente o mesmo plano")

        // 2. Afinidade lexical
        let gotaPlan = resolveWord(word: "gota!", wordIndex: 0, scores: .single(.fluidez, score: 2), phraseSeed: 7)
        assert(gotaPlan.entrance?.effectID == .fluidWaterDrop, "Lexical 'gota' deve selecionar Water Drop")

        let foguetePlan = resolveWord(word: "foguete", wordIndex: 0, scores: .single(.calor, score: 2), phraseSeed: 7)
        assert(foguetePlan.entrance?.effectID == .calLancamentoFoguete, "Lexical 'foguete' deve selecionar Lançamento de Foguete")

        let silencioPlan = resolveWord(word: "silêncio", wordIndex: 0, scores: .single(.volume, score: -3), phraseSeed: 7)
        assert(silencioPlan.overlay?.effectID == .volSolidToOutline, "Lexical 'silêncio' deve selecionar Solid To Outline")

        let derreteuPlan = resolveWord(word: "derreteu", wordIndex: 0, scores: .single(.fluidez, score: 2), phraseSeed: 7)
        assert(derreteuPlan.staticStructure?.effectID == .fluidDerretido, "Lexical 'derreteu' deve selecionar Derretido")
        assert(derreteuPlan.surface == nil, "Derretido não deve adicionar cor própria")

        // 3. Polaridades e Tensão negativa sem animação (vence animação mais fraca, perde para mais forte)
        var tensaoNeg = ParameterScores()
        tensaoNeg[.tensao] = -4
        tensaoNeg[.dominio] = 3
        tensaoNeg[.tom] = 4
        let alivioPlan = resolveWord(word: "aliviado", wordIndex: 0, scores: tensaoNeg, phraseSeed: 9)
        assert(alivioPlan.entrance == nil && alivioPlan.continuous == nil && alivioPlan.overlay == nil && alivioPlan.surface == nil)
        assert(alivioPlan.typography.familyName == "Comic Sans" && alivioPlan.typography.weightLabel == "Bold (+3)")

        var alivioComOndaForte = ParameterScores()
        alivioComOndaForte[.tensao] = -2
        alivioComOndaForte[.fluidez] = 4
        let pazFluida = resolveWord(word: "onda", wordIndex: 0, scores: alivioComOndaForte, phraseSeed: 9)
        assert(pazFluida.continuous?.parameter == .fluidez, "Fluidez +4 deve vencer Tensão -2 no canal contínuo")

        let lentoPlan = resolveWord(word: "devagar", wordIndex: 0, scores: .single(.andamento, score: -2), phraseSeed: 9)
        assert(lentoPlan.continuous?.effectID == .andLetargia, "Andamento negativo deve selecionar Letargia")

        // 4. Limiar de Valência ±1 bloqueia efeitos fortes
        for seed in 1...12 {
            let vPos1 = resolveWord(word: "ok", wordIndex: 0, scores: .single(.valencia, score: 1), phraseSeed: seed)
            assert(vPos1.entrance == nil, "Valência +1 não deve disparar entradas fortes")
            if let s = vPos1.surface { assert(s.effectID == .valPulsoSaturacao) }
            if let o = vPos1.overlay { assert(o.effectID == .valSombrasGemeas) }

            let vNeg1 = resolveWord(word: "chato", wordIndex: 0, scores: .single(.valencia, score: -1), phraseSeed: seed)
            assert(vNeg1.entrance == nil && vNeg1.overlay == nil, "Valência -1 não deve disparar aberração/anáglifo")
            assert(vNeg1.surface?.effectID == .valMercurioLiquido)
        }

        // 5. Empate no Canal Cor: sensorial (Fluidez -) vence Valência (-), e Valência ocupa Overlay
        var empateCor = ParameterScores()
        empateCor[.fluidez] = -3
        empateCor[.valencia] = -3
        let metalTriste = resolveWord(word: "aço", wordIndex: 0, scores: empateCor, phraseSeed: 5)
        assert(metalTriste.surface?.parameter == .fluidez, "Sensorial deve vencer Valência em empate exato no Canal Cor")
        assert(metalTriste.overlay?.parameter == .valencia, "Valência deve aproveitar o Canal Overlay livre")

        // 6. Proteção de fontes decorativas (CatsFont e SnowtopCaps)
        var gatoScores = ParameterScores()
        gatoScores[.calor] = 4
        gatoScores[.valencia] = 4
        gatoScores[.volume] = -3
        gatoScores[.dominio] = 4
        gatoScores[.fragmentacao] = 4
        let gatoPlan = resolveWord(word: "gato", wordIndex: 0, scores: gatoScores, phraseSeed: 3)
        assert(gatoPlan.typography.isDecorativeSingleWeight && gatoPlan.typography.extraStrokeWidth == 0)
        assert(gatoPlan.surface == nil, "CatsFont não deve receber alteração de cor no Canal 2")
        assert(gatoPlan.overlay?.effectID != .volSolidToOutline && gatoPlan.overlay?.spec.blockedOnDecorativeFont != true)

        var geloScores = ParameterScores()
        geloScores[.calor] = -4
        geloScores[.dominio] = 5
        let geloPlan = resolveWord(word: "gelo", wordIndex: 0, scores: geloScores, phraseSeed: 3)
        assert(geloPlan.typography.familyName == "Snowtop Caps" && geloPlan.typography.extraStrokeWidth == 0)
        assert(geloPlan.surface == nil && geloPlan.overlay?.effectID != .calGelidoQuebradico)

        // 7. Ativação como multiplicador quando outro parâmetro vence o Canal 4
        var ondaRapida = ParameterScores()
        ondaRapida[.fluidez] = 5
        ondaRapida[.ativacao] = 3
        let ondaPlan = resolveWord(word: "onda", wordIndex: 0, scores: ondaRapida, phraseSeed: 11)
        assert(ondaPlan.continuous?.parameter == .fluidez)
        assert(ondaPlan.speedMultiplier == 2.30, "Ativação secundária deve acelerar movimento vencedor")

        // 8. Freio de FPS (isEcoMode) em frase longa inundada por efeito pesado
        let heavyTokens = ["neve", "nevasca", "floco", "neve", "nevasca", "floco"]
        let heavyScores = Array(repeating: ParameterScores.single(.calor, score: -3), count: heavyTokens.count)
        let ecoPlans = resolvePhrase(tokens: heavyTokens, scoresPerWord: heavyScores, phraseSeed: 1)
        assert(ecoPlans.allSatisfy(\.isEcoMode), "Frase longa com >= 80% de efeito pesado deve ativar isEcoMode")

        // 9. Gatilhos dedicados por palavra-chave (18 regras, mesmo com notas = 0 e termos compostos)
        let keywordSamples: [(String, MorphEffectID)] = [
            ("coração!", .kwHeartbeatBurst),
            ("respiração", .kwRespiracaoOrganica),
            ("neon", .kwLetreiroNeon),
            ("sombra", .kwSombraOrbitante),
            ("arco", .kwArcoCurvado),
            ("escada", .kwEscadaDiagonal),
            ("subida", .kwEscadaDiagonal),
            ("palavrão", .kwTarjaCensurada),
            ("cassino", .kwRoloCassino),
            ("pêndulo", .kwPenduloNewton),
            ("bolhas", .kwBolhasSabao),
            ("dobrar", .kwArcoFlexivel),
            ("quadrinho", .kwEstouroPopArt),
            ("pintar", .kwTracoParaTinta),
            ("Coraline", .kwStopMotion6fps),
            ("bagunça", .kwLinhaDesconstruida),
            ("escorrimento", .fluidFluidoViscoso),
            ("caótico", .kwCaosImprevisivel),
            ("tontura", .kwTontura),
            ("bebida", .kwTontura)
        ]
        for (sample, expected) in keywordSamples {
            let p = resolveWord(word: sample, wordIndex: 0, scores: ParameterScores(), phraseSeed: 1)
            assert(p.allActiveSlots.contains { $0.effectID == expected }, "Palavra '\(sample)' deveria disparar \(expected)")
        }
        let bigramPlans = resolvePhrase(
            tokens: ["Estilo", "Pop", "Art", "e", "Stop", "Motion"],
            scoresPerWord: Array(repeating: ParameterScores(), count: 6),
            phraseSeed: 1
        )
        assert(bigramPlans[1].overlay?.effectID == .kwEstouroPopArt && bigramPlans[2].overlay?.effectID == .kwEstouroPopArt)
        assert(bigramPlans[4].continuous?.effectID == .kwStopMotion6fps && bigramPlans[5].continuous?.effectID == .kwStopMotion6fps)
        let arcoIrisPlan = resolveWord(word: "arco-íris", wordIndex: 0, scores: ParameterScores(), phraseSeed: 1)
        assert(arcoIrisPlan.staticStructure == nil, "'arco-íris' não deve disparar Arco Curvado")
    }
}
