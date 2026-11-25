import SwiftUI
import Observation

enum CRTCoordinateSpace {
    static let name = "morphCRTScreen"
}

/// Configuração compartilhada da curvatura barril e iluminação do vidro CRT.
/// Após os testes de usuário, substitua os `default*` pelos valores finais escolhidos.
@MainActor
@Observable
final class CRTBarrelConfig {
    static let defaultCurvature: Double = 0.07
    static let defaultVignetteStrength: Double = 0.38
    static let defaultBezelShadowStrength: Double = 0.42
    static let defaultGlassGlareStrength: Double = 0.24

    static let curvatureRange: ClosedRange<Double> = 0.0...0.45
    static let vignetteRange: ClosedRange<Double> = 0.0...0.75
    static let bezelShadowRange: ClosedRange<Double> = 0.0...0.85
    static let glassGlareRange: ClosedRange<Double> = 0.0...0.60

    var curvature: Double = CRTBarrelConfig.defaultCurvature
    var vignetteStrength: Double = CRTBarrelConfig.defaultVignetteStrength
    var bezelShadowStrength: Double = CRTBarrelConfig.defaultBezelShadowStrength
    var glassGlareStrength: Double = CRTBarrelConfig.defaultGlassGlareStrength

    var hasCustomValues: Bool {
        abs(curvature - Self.defaultCurvature) > 0.001
            || abs(vignetteStrength - Self.defaultVignetteStrength) > 0.001
            || abs(bezelShadowStrength - Self.defaultBezelShadowStrength) > 0.001
            || abs(glassGlareStrength - Self.defaultGlassGlareStrength) > 0.001
    }

    func resetToDefaults() {
        curvature = Self.defaultCurvature
        vignetteStrength = Self.defaultVignetteStrength
        bezelShadowStrength = Self.defaultBezelShadowStrength
        glassGlareStrength = Self.defaultGlassGlareStrength
    }

    init() {
        #if DEBUG
        Self.verifyBarrelMathOnce()
        #endif
    }

    #if DEBUG
    private static var didVerifyMath = false

    private static func verifyBarrelMathOnce() {
        guard !didVerifyMath else { return }
        didVerifyMath = true

        let ipad = CRTBarrelTransform(containerSize: CGSize(width: 1180, height: 820), curvature: 0.05)
        let iphone = CRTBarrelTransform(containerSize: CGSize(width: 393, height: 852), curvature: 0.05)
        let extreme = CRTBarrelTransform(containerSize: CGSize(width: 1366, height: 1024), curvature: 0.45)
        let flat = CRTBarrelTransform(containerSize: CGSize(width: 1180, height: 820), curvature: 0.0)

        // Identidade em curvatura 0
        let sample = CGPoint(x: 200, y: 150)
        assert(flat.screenToLogical(sample) == sample)
        assert(flat.logicalToScreen(sample) == sample)

        // Pontos médios das bordas ficam travados na abertura (edgeAnchor = 1.0)
        let midRight = CGPoint(x: extreme.openingRect.maxX, y: extreme.openingRect.midY)
        let midTop = CGPoint(x: extreme.openingRect.midX, y: extreme.openingRect.minY)
        assert(hypot(extreme.screenToLogical(midRight).x - midRight.x, extreme.screenToLogical(midRight).y - midRight.y) < 1e-4)
        assert(hypot(extreme.screenToLogical(midTop).x - midTop.x, extreme.screenToLogical(midTop).y - midTop.y) < 1e-4)

        // Cantos curvam estritamente para dentro da abertura
        let corner = CGPoint(x: extreme.openingRect.minX, y: extreme.openingRect.minY)
        let warpedCorner = extreme.logicalToScreen(corner)
        assert(warpedCorner.x > corner.x && warpedCorner.y > corner.y)

        // Round-trip exato entre screenToLogical e logicalToScreen mesmo em curvatura extrema
        for t in [ipad, iphone, extreme] {
            let pts = [
                CGPoint(x: t.openingRect.midX, y: t.openingRect.midY),
                CGPoint(x: t.openingRect.minX, y: t.openingRect.minY),
                CGPoint(x: t.openingRect.maxX, y: t.openingRect.maxY),
                CGPoint(x: t.openingRect.minX + t.openingRect.width * 0.2, y: t.openingRect.maxY - t.openingRect.height * 0.15)
            ]
            for p in pts {
                let back = t.screenToLogical(t.logicalToScreen(p))
                assert(hypot(back.x - p.x, back.y - p.y) < 1e-3)
            }
        }

        // Invariância de proporção: mesma posição normalizada de canto gera mesmo deslocamento normalizado
        let ipadCorner = ipad.logicalToScreen(CGPoint(x: ipad.openingRect.maxX, y: ipad.openingRect.maxY))
        let iphoneCorner = iphone.logicalToScreen(CGPoint(x: iphone.openingRect.maxX, y: iphone.openingRect.maxY))
        let ipadNormX = (ipadCorner.x - ipad.openingRect.midX) / (ipad.openingRect.width * 0.5)
        let iphoneNormX = (iphoneCorner.x - iphone.openingRect.midX) / (iphone.openingRect.width * 0.5)
        assert(abs(ipadNormX - iphoneNormX) < 1e-5)
    }
    #endif
}
