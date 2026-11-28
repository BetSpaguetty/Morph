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

/// Contorno de pasta do SVG `borda_pasta`, redimensionado sem alterar a espessura do traço.
struct RetroFolderFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 1009.0
        let scaleY = rect.height / 699.0
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        var outline = Path()
        outline.move(to: point(34, 690))
        outline.addLine(to: point(975, 684))
        outline.addCurve(
            to: point(996, 662),
            control1: point(989, 690),
            control2: point(996, 678)
        )
        outline.addLine(to: point(996, 114))
        outline.addCurve(
            to: point(975, 88),
            control1: point(996, 99),
            control2: point(987, 88)
        )
        outline.addLine(to: point(586, 88))
        outline.addCurve(
            to: point(562, 75),
            control1: point(576, 88),
            control2: point(568, 82)
        )
        outline.addLine(to: point(523, 22))
        outline.addCurve(
            to: point(499, 15),
            control1: point(514, 15),
            control2: point(506, 15)
        )
        outline.addLine(to: point(34, 15))
        outline.addCurve(
            to: point(13, 36),
            control1: point(22, 15),
            control2: point(13, 24)
        )
        outline.addLine(to: point(13, 668))
        outline.addCurve(
            to: point(34, 690),
            control1: point(13, 681),
            control2: point(22, 690)
        )
        outline.closeSubpath()

        var divider = Path()
        divider.move(to: point(8, 88))
        divider.addLine(to: point(584, 88))
        outline.addPath(divider)
        return outline
    }
}

/// Cabeçalho retrô: Início, Ajustes e Salvar à esquerda; relógio e bateria à direita.
struct RetroHeaderBar: View {
    let metrics: RetroFrameMetrics
    var onHome: () -> Void
    var onSettings: () -> Void
    var onSave: () -> Void
    var isSaved: Bool = false
    var onTapEmptySpace: (() -> Void)? = nil

    private var iconSize: CGFloat { 20 * metrics.headerScale }
    private var buttonPadX: CGFloat { 6 * metrics.headerScale }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4 * metrics.headerScale) {
                headerIconButton(systemName: "house", label: "Início", action: onHome)
                headerIconButton(systemName: "gearshape", label: "Ajustes", action: onSettings)
                //headerAssetButton(assetName: "botao_salvar", label: "Salvar", action: onSave)
                headerIconButton(
                    systemName: isSaved ? "square.and.arrow.down.badge.checkmark" : "square.and.arrow.down",
                    label: isSaved ? "Salvo" : "Salvar",
                    action: onSave
                )
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

    private func headerAssetButton(assetName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .padding(.horizontal, buttonPadX)
                .frame(height: metrics.headerHeight)
                .contentShape(Rectangle())
                .crtHitAdjusted()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
