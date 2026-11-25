import SwiftUI

/// Moldura retrô da tela de escrita: contorno externo arredondado + divisória superior chanfrada.
struct RetroWindowFrameShape: Shape {
    let metrics: RetroFrameMetrics

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let rx = min(metrics.cornerSize.width, rect.width / 4)
        let ry = min(metrics.cornerSize.height, rect.height / 4)
        let h = min(metrics.headerHeight, rect.height / 3)

        // Arco circular/elíptico exato garante junção sem folga com os chanfros laterais
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: rx, height: ry), style: .circular)

        let startY = min(metrics.bevelStartY, h - 6)
        let edgeInset = RetroFrameMetrics.bevelEdgeInset(rx: rx, ry: ry, at: startY)
        let run = min(metrics.bevelRun, rect.width * 0.14)
        let bend = min(metrics.bendRadius, max(2, (h - startY) * 0.45))

        let leftStart = CGPoint(x: rect.minX + edgeInset, y: rect.minY + startY)
        let leftCorner = CGPoint(x: rect.minX + edgeInset + run, y: rect.minY + h)
        let rightCorner = CGPoint(x: rect.maxX - edgeInset - run, y: rect.minY + h)
        let rightEnd = CGPoint(x: rect.maxX - edgeInset, y: rect.minY + startY)

        path.move(to: leftStart)
        path.addArc(tangent1End: leftCorner, tangent2End: rightCorner, radius: bend)
        path.addArc(tangent1End: rightCorner, tangent2End: rightEnd, radius: bend)
        path.addLine(to: rightEnd)

        return path
    }
}

/// Cabeçalho retrô dentro da faixa chanfrada: Home + Ajustes vazados à esquerda; relógio + bateria à direita.
struct RetroHeaderBar: View {
    let metrics: RetroFrameMetrics
    var onHome: () -> Void
    var onSettings: () -> Void
    var onTapEmptySpace: (() -> Void)? = nil

    private var iconSize: CGFloat { 20 * metrics.headerScale }
    private var buttonPadX: CGFloat { 6 * metrics.headerScale }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4 * metrics.headerScale) {
                headerIconButton(systemName: "house", label: "Início", action: onHome)
                headerIconButton(systemName: "gearshape", label: "Ajustes", action: onSettings)
            }

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .crtHitAdjusted()
                .onTapGesture { onTapEmptySpace?() }

            HStack(spacing: 10 * metrics.headerScale) {
                DeviceClockView(scale: metrics.headerScale)
                DeviceBatteryView(scale: metrics.headerScale)
            }
        }
        .padding(.leading, max(0, metrics.headerContentInsetX - buttonPadX))
        .padding(.trailing, metrics.headerContentInsetX)
        .frame(height: metrics.headerHeight)
    }

    private func headerIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(RetroTerminalStyle.ink)
                .padding(.horizontal, buttonPadX)
                .frame(height: metrics.headerHeight)
                .crtHitAdjusted()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
