import SwiftUI

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
