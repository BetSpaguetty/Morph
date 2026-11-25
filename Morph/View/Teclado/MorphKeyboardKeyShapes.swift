import SwiftUI

// MARK: - Formas Vetoriais dos Ícones (Peso de Traço Alinhado ao Terminal Retrô)

/// Arco inferior externo da tecla para projetar sombra limpa abaixo do botão sem escurecer o interior translúcido.
struct KeyBottomShadowShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) * 0.5)
        let insetX = min(2.0, r * 0.18)
        let startY = rect.maxY - r * 0.68

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + insetX, y: startY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.maxY),
            control: CGPoint(x: rect.minX + insetX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - insetX, y: startY),
            control: CGPoint(x: rect.maxX - insetX, y: rect.maxY)
        )
        return p
    }
}

struct ShiftArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = rect.midX
        let headY = rect.minY + h * 0.52
        let stemHalfW = w * 0.22

        var p = Path()
        p.move(to: CGPoint(x: midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: headY))
        p.addLine(to: CGPoint(x: midX + stemHalfW, y: headY))
        p.addLine(to: CGPoint(x: midX + stemHalfW, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX - stemHalfW, y: rect.maxY))
        p.addLine(to: CGPoint(x: midX - stemHalfW, y: headY))
        p.addLine(to: CGPoint(x: rect.minX, y: headY))
        p.closeSubpath()
        return p
    }
}

struct BackspaceIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tipX = rect.minX
        let neckX = rect.minX + rect.width * 0.30
        let r = min(rect.height * 0.18, 4.0)

        var p = Path()
        p.move(to: CGPoint(x: tipX, y: rect.midY))
        p.addLine(to: CGPoint(x: neckX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: neckX, y: rect.maxY))
        p.closeSubpath()

        // X interno centralizado no corpo retangular
        let cx = neckX + (rect.maxX - neckX) * 0.48
        let cy = rect.midY
        let arm = min((rect.maxX - neckX) * 0.22, rect.height * 0.22)
        p.move(to: CGPoint(x: cx - arm, y: cy - arm))
        p.addLine(to: CGPoint(x: cx + arm, y: cy + arm))
        p.move(to: CGPoint(x: cx + arm, y: cy - arm))
        p.addLine(to: CGPoint(x: cx - arm, y: cy + arm))

        return p
    }
}

struct ReturnArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let arrowY = rect.minY + rect.height * 0.62
        let head = min(rect.width * 0.24, rect.height * 0.38)
        let cornerR = min(rect.height * 0.22, 4.0)

        var p = Path()
        // Haste vertical descendo à direita e virando para a esquerda
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: arrowY - cornerR))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - cornerR, y: arrowY), control: CGPoint(x: rect.maxX, y: arrowY))
        p.addLine(to: CGPoint(x: rect.minX, y: arrowY))

        // Ponta da seta à esquerda
        p.move(to: CGPoint(x: rect.minX + head, y: arrowY - head))
        p.addLine(to: CGPoint(x: rect.minX, y: arrowY))
        p.addLine(to: CGPoint(x: rect.minX + head, y: arrowY + head))
        return p
    }
}
