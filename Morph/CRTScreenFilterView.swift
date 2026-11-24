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

/// Transformação matemática exata compartilhada entre o shader Metal e o hit-testing em Swift.
struct CRTBarrelTransform: Equatable, Sendable {
    static let openingWidthRatio: CGFloat = 0.826
    static let openingHeightRatio: CGFloat = 0.815
    static let identity = CRTBarrelTransform(containerSize: .zero, curvature: 0)

    let containerSize: CGSize
    let openingRect: CGRect
    let curvature: CGFloat

    init(containerSize: CGSize, curvature: CGFloat) {
        self.containerSize = containerSize
        self.curvature = max(0, curvature)
        let openW = containerSize.width * Self.openingWidthRatio
        let openH = containerSize.height * Self.openingHeightRatio
        self.openingRect = CGRect(
            x: (containerSize.width - openW) * 0.5,
            y: (containerSize.height - openH) * 0.5,
            width: openW,
            height: openH
        )
    }

    var isActive: Bool {
        curvature > 0.0001 && openingRect.width > 1 && openingRect.height > 1
    }

    var maxSampleOffset: CGSize {
        let factor = curvature * 1.25 / (1.0 + curvature)
        return CGSize(
            width: ceil(openingRect.width * 0.5 * factor) + 4,
            height: ceil(openingRect.height * 0.5 * factor) + 4
        )
    }

    /// Converte um ponto tocado na tela visual (curvada) para a coordenada lógica da UI (idêntico ao shader Metal).
    func screenToLogical(_ screenPoint: CGPoint) -> CGPoint {
        guard isActive else { return screenPoint }
        let cx = openingRect.midX
        let cy = openingRect.midY
        let hx = openingRect.width * 0.5
        let hy = openingRect.height * 0.5

        let ux = (screenPoint.x - cx) / hx
        let uy = (screenPoint.y - cy) / hy
        let r2 = ux * ux + uy * uy
        let factor = (1.0 + curvature * r2) / (1.0 + curvature)

        return CGPoint(
            x: cx + ux * factor * hx,
            y: cy + uy * factor * hy
        )
    }

    /// Inversa exata via Newton-Raphson: converte uma coordenada lógica da UI para onde ela aparece no vidro.
    func logicalToScreen(_ logicalPoint: CGPoint) -> CGPoint {
        guard isActive else { return logicalPoint }
        let cx = openingRect.midX
        let cy = openingRect.midY
        let hx = openingRect.width * 0.5
        let hy = openingRect.height * 0.5

        let sx = (logicalPoint.x - cx) / hx
        let sy = (logicalPoint.y - cy) / hy
        let rSrc = hypot(sx, sy)
        guard rSrc > 1e-7 else { return logicalPoint }

        let c = (1.0 + curvature) * rSrc
        var r = c / (1.0 + curvature * min(c * c, 2.0))
        for _ in 0..<5 {
            let f = curvature * r * r * r + r - c
            let df = 3.0 * curvature * r * r + 1.0
            r -= f / df
        }

        let scale = r / rSrc
        return CGPoint(
            x: cx + sx * scale * hx,
            y: cy + sy * scale * hy
        )
    }
}

private struct CRTBarrelTransformKey: EnvironmentKey {
    static let defaultValue = CRTBarrelTransform.identity
}

extension EnvironmentValues {
    var crtBarrelTransform: CRTBarrelTransform {
        get { self[CRTBarrelTransformKey.self] }
        set { self[CRTBarrelTransformKey.self] = newValue }
    }
}

/// Contorno curvado no espaço local da view para alinhar a área de toque exatamente aos pixels distorcidos.
struct CRTWarpedRectShape: Shape {
    let logicalFrame: CGRect
    let transform: CRTBarrelTransform

    func path(in rect: CGRect) -> Path {
        guard transform.isActive, logicalFrame.width > 0.5, logicalFrame.height > 0.5 else {
            return Path(rect)
        }

        let steps = 8
        let minX = logicalFrame.minX
        let maxX = logicalFrame.maxX
        let minY = logicalFrame.minY
        let maxY = logicalFrame.maxY

        func mapped(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let s = transform.logicalToScreen(CGPoint(x: x, y: y))
            return CGPoint(x: s.x - minX, y: s.y - minY)
        }

        var path = Path()
        path.move(to: mapped(minX, minY))

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            path.addLine(to: mapped(minX + (maxX - minX) * t, minY))
        }
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            path.addLine(to: mapped(maxX, minY + (maxY - minY) * t))
        }
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            path.addLine(to: mapped(maxX - (maxX - minX) * t, maxY))
        }
        for i in 1..<steps {
            let t = CGFloat(i) / CGFloat(steps)
            path.addLine(to: mapped(minX, maxY - (maxY - minY) * t))
        }

        path.closeSubpath()
        return path
    }
}

private struct CRTHitAdjustedModifier: ViewModifier {
    let enabled: Bool
    @Environment(\.crtBarrelTransform) private var transform
    @State private var logicalFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(CRTCoordinateSpace.name))
            } action: { frame in
                if logicalFrame != frame {
                    logicalFrame = frame
                }
            }
            .contentShape(
                CRTWarpedRectShape(
                    logicalFrame: enabled ? logicalFrame : .zero,
                    transform: enabled ? transform : .identity
                )
            )
    }
}

extension View {
    /// Ajusta a área de toque de qualquer botão ou controle interativo para coincidir 100% com sua posição curvada.
    func crtHitAdjusted(_ enabled: Bool = true) -> some View {
        modifier(CRTHitAdjustedModifier(enabled: enabled))
    }
}
