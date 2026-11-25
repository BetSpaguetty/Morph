import SwiftUI

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
