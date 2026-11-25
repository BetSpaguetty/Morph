import SwiftUI

// MARK: - Recorte SDF da Abertura Visível (Idêntico ao CRTScreenShader.metal)

extension CRTBarrelTransform {
    /// Verifica se um ponto visual na tela está dentro do vidro visível da TV (excluindo `borda_tv` e seus cantos curvos).
    func containsVisibleScreenPoint(_ point: CGPoint) -> Bool {
        guard openingRect.width > 1, openingRect.height > 1 else { return false }
        let halfW = openingRect.width * 0.5
        let halfH = openingRect.height * 0.5
        let ux = abs((point.x - openingRect.midX) / halfW)
        let uy = abs((point.y - openingRect.midY) / halfH)

        // Mesmo SDF de CRTScreenShader.metal (linhas 79-80)
        let qx = ux - 0.86
        let qy = uy - 0.86
        let outsideDist = hypot(max(qx, 0), max(qy, 0))
        let insideDist = min(max(qx, qy), 0)
        return (outsideDist + insideDist - 0.14) <= 0
    }
}

// MARK: - Parâmetros Calibrados da Distorção Magnética ao Toque

nonisolated struct CRTTouchConfig: Equatable, Sendable {
    static let `default` = CRTTouchConfig()

    var isEnabled: Bool = true
    var radius: CGFloat = 70.0                   // Raio de influência: 70 pt
    var force: CGFloat = 0.10                    // Força e polaridade: +10% (repulsão)
    var falloff: CGFloat = 1.00                  // Suavidade na borda: 1.00
    var vortex: CGFloat = -0.05                  // Torção magnética: -0.05
    var rgbSplit: CGFloat = 10.0                  // Separação RGB ao toque: 2.0 px
    var centerLuminance: CGFloat = -0.04         // Mancha de luminância central: -4%
    var scanlines: CGFloat = 0.35                // Scanlines reveladas no toque: 35%
    var decayTime: CGFloat = 0.30                // Tempo de dissipação: 0.30 s
    var elasticity: CGFloat = 0.25               // Elasticidade de retorno: 25%
    var keyboardAreaAttenuation: CGFloat = 0.15  // Atenuação na área do teclado: 15%
    var followSpeed: CGFloat = 1.0               // Resposta ao movimento: Instantâneo (1:1)

    /// Pico de amplitude com oscilação elástica e margem para sobreposição de múltiplos dedos.
    private var overlapPeakMultiplier: CGFloat {
        let elasticityPeak: CGFloat = elasticity > 0 ? min(1.5, 1.0 + elasticity * 0.30) : 1.0
        return elasticityPeak * 2.0
    }

    var maxDispBudget: CGFloat {
        guard isEnabled, radius > 0.5 else { return 0 }
        let singleTouchMax = radius * hypot(0.35 * abs(force), 0.25 * abs(vortex))
        return singleTouchMax * overlapPeakMultiplier
    }

    var maxSplitBudget: CGFloat {
        guard isEnabled, radius > 0.5 else { return 0 }
        return max(0, rgbSplit) * overlapPeakMultiplier
    }

    /// Folga fixa somada ao `maxSampleOffset` do barril (evita realocação de textura no 1º toque).
    var extraSampleOffset: CGFloat {
        guard isEnabled, radius > 0.5 else { return 0 }
        return ceil(maxDispBudget + maxSplitBudget) + 2
    }
}
