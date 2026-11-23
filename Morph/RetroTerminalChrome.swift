import SwiftUI
import UIKit

enum RetroTerminalStyle {
    /// Mesmo grafite escuro (#2D3037) do asset `caret_morph.svg`
    static let ink = Color(red: 45.0 / 255.0, green: 48.0 / 255.0, blue: 55.0 / 255.0)
}

/// Métricas responsivas compartilhadas entre a moldura vetorial e o cabeçalho,
/// acompanhando o esticamento independente em X e Y da imagem `borda_tv`.
struct RetroFrameMetrics: Equatable {
    let horizontalOuterPadding: CGFloat
    let verticalOuterPadding: CGFloat
    let frameSize: CGSize
    let cornerSize: CGSize
    let lineWidth: CGFloat
    let headerHeight: CGFloat
    let bevelStartY: CGFloat
    let bevelEdgeInset: CGFloat
    let bevelRun: CGFloat
    let bendRadius: CGFloat
    let headerContentInsetX: CGFloat
    let headerScale: CGFloat

    init(containerSize: CGSize) {
        let cw = max(containerSize.width, 1)
        let ch = max(containerSize.height, 1)

        // Margem externa proporcional separada em X e Y para espelhar a abertura da `borda_tv`
        let hPad = max(15, cw * 0.042)
        let vPad = max(15, ch * 0.048)

        let fw = max(cw - hPad * 2, 120)
        let fh = max(ch - vPad * 2, 100)

        // Raio elíptico proporcional acompanha a curvatura esticada dos 4 cantos da TV
        let rx = Self.clamp(fw * 0.038, min: 14, max: 36)
        let ry = Self.clamp(fh * 0.054, min: 14, max: 36)

        let headerH = Self.clamp(fh * 0.092, min: 38, max: 58)
        let startY = min(ry * 0.86, headerH * 0.48)
        let dy = max(0, ry - startY)
        let ratio = ry > 0 ? min(1, dy / ry) : 0
        let edgeInset = dy > 0 ? rx * (1 - sqrt(max(0, 1 - ratio * ratio))) : 0

        let bevelDrop = max(10, headerH - startY)
        let run = min(bevelDrop * 1.08, fw * 0.09)
        let bend = min(10, bevelDrop * 0.42)

        // Conteúdo do cabeçalho sempre ancorado com folga além do vértice interno do chanfro
        let contentInsetX = edgeInset + run + Self.clamp(fw * 0.015, min: 8, max: 16)

        let scale = Self.clamp(min(fw / 460, headerH / 54), min: 0.72, max: 1.0)
        let stroke = Self.clamp(min(fw, fh) * 0.0055, min: 2.5, max: 3.5)

        self.horizontalOuterPadding = hPad
        self.verticalOuterPadding = vPad
        self.frameSize = CGSize(width: fw, height: fh)
        self.cornerSize = CGSize(width: rx, height: ry)
        self.lineWidth = stroke
        self.headerHeight = headerH
        self.bevelStartY = startY
        self.bevelEdgeInset = edgeInset
        self.bevelRun = run
        self.bendRadius = bend
        self.headerContentInsetX = contentInsetX
        self.headerScale = scale
    }

    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(upper, Swift.max(lower, value))
    }
}

/// Moldura retrô da tela de escrita: contorno externo arredondado + divisória superior chanfrada.
struct RetroWindowFrameShape: Shape {
    let metrics: RetroFrameMetrics

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let rx = min(metrics.cornerSize.width, rect.width / 4)
        let ry = min(metrics.cornerSize.height, rect.height / 4)
        let h = min(metrics.headerHeight, rect.height / 3)

        // 1. Contorno externo arredondado (arco elíptico exato garante junção sem folga com os chanfros)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: rx, height: ry), style: .circular)

        // 2. Divisória do cabeçalho nascendo exatamente na borda lateral
        let startY = min(metrics.bevelStartY, h - 6)
        let dy = max(0, ry - startY)
        let ratio = ry > 0 ? min(1, dy / ry) : 0
        let edgeInset = dy > 0 ? rx * (1 - sqrt(max(0, 1 - ratio * ratio))) : 0
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
                .contentShape(Rectangle())
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Relógio 24h sincronizado com a hora do dispositivo.
struct DeviceClockView: View {
    var scale: CGFloat = 1.0

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.formatter.string(from: context.date))
                .font(.system(size: 20 * scale, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(RetroTerminalStyle.ink)
                .fixedSize()
        }
    }
}

/// Indicador de bateria retrô de 5 segmentos ligado ao `UIDevice`.
struct DeviceBatteryView: View {
    var scale: CGFloat = 1.0
    @State private var batteryLevel: Float = UIDevice.current.batteryLevel

    private let totalSegments = 5

    static func filledSegments(for level: Float, total: Int = 5) -> Int {
        // No Simulador `batteryLevel` retorna -1.0; usa carga cheia como fallback visual.
        guard level >= 0 else { return total }
        let percent = Int((Double(level) * 100.0).rounded())
        if percent <= 5 { return 0 }
        let step = max(1, 100 / max(1, total))
        return min(total, max(1, (percent + step - 1) / step))
    }

    private var filledCount: Int {
        Self.filledSegments(for: batteryLevel, total: totalSegments)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5 * scale, style: .continuous)
                    .stroke(RetroTerminalStyle.ink, lineWidth: max(1.8, 2.5 * scale))

                HStack(spacing: max(1.5, 2 * scale)) {
                    ForEach(0..<totalSegments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(index < filledCount ? RetroTerminalStyle.ink.opacity(0.62) : Color.clear)
                    }
                }
                .padding(max(2.5, 3.5 * scale))
            }
            .frame(width: 44 * scale, height: 21 * scale)

            // Polo positivo da bateria
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 2 * scale,
                topTrailingRadius: 2 * scale
            )
            .fill(RetroTerminalStyle.ink)
            .frame(width: 3.5 * scale, height: 9 * scale)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(batteryAccessibilityLabel)
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryLevel = UIDevice.current.batteryLevel
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            batteryLevel = UIDevice.current.batteryLevel
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            batteryLevel = UIDevice.current.batteryLevel
        }
    }

    private var batteryAccessibilityLabel: String {
        guard batteryLevel >= 0 else { return "Bateria" }
        return "Bateria em \(Int((batteryLevel * 100).rounded())) por cento"
    }
}
