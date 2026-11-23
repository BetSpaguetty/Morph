import SwiftUI
import UIKit

enum RetroTerminalStyle {
    /// Mesmo grafite escuro (#2D3037) do asset `caret_morph.svg`
    static let uiInk = UIColor(red: 45.0 / 255.0, green: 48.0 / 255.0, blue: 55.0 / 255.0, alpha: 1.0)
    static let ink = Color(uiColor: uiInk)
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
    let bevelRun: CGFloat
    let bendRadius: CGFloat
    let headerContentInsetX: CGFloat
    let headerScale: CGFloat

    init(containerSize: CGSize) {
        let cw = max(containerSize.width, 1)
        let ch = max(containerSize.height, 1)

        let hPad = max(15, cw * 0.042)
        let vPad = max(15, ch * 0.048)

        let fw = max(cw - hPad * 2, 120)
        let fh = max(ch - vPad * 2, 100)

        let rx = Self.clamp(fw * 0.038, min: 14, max: 36)
        let ry = Self.clamp(fh * 0.054, min: 14, max: 36)

        let headerH = Self.clamp(fh * 0.092, min: 38, max: 58)
        let startY = min(ry * 0.86, headerH * 0.48)
        let edgeInset = Self.bevelEdgeInset(rx: rx, ry: ry, at: startY)

        let bevelDrop = max(10, headerH - startY)
        let run = min(bevelDrop * 1.08, fw * 0.09)
        let bend = min(10, bevelDrop * 0.42)

        self.horizontalOuterPadding = hPad
        self.verticalOuterPadding = vPad
        self.frameSize = CGSize(width: fw, height: fh)
        self.cornerSize = CGSize(width: rx, height: ry)
        self.lineWidth = Self.clamp(min(fw, fh) * 0.0055, min: 2.5, max: 3.5)
        self.headerHeight = headerH
        self.bevelStartY = startY
        self.bevelRun = run
        self.bendRadius = bend
        self.headerContentInsetX = edgeInset + run + Self.clamp(fw * 0.015, min: 8, max: 16)
        self.headerScale = Self.clamp(min(fw / 460, headerH / 54), min: 0.72, max: 1.0)
    }

    static func bevelEdgeInset(rx: CGFloat, ry: CGFloat, at y: CGFloat) -> CGFloat {
        let dy = max(0, ry - y)
        guard dy > 0, ry > 0 else { return 0 }
        let ratio = min(1, dy / ry)
        return rx * (1 - sqrt(max(0, 1 - ratio * ratio)))
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

/// Relógio 24h sincronizado com a hora do dispositivo (acorda apenas na virada de minuto).
struct DeviceClockView: View {
    var scale: CGFloat = 1.0

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(Self.formatter.string(from: context.date))
                .font(.system(size: 20 * scale, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(RetroTerminalStyle.ink)
                .fixedSize()
        }
    }
}

/// Indicador de bateria retrô de 5 segmentos ligado ao `UIDevice` e ao Modo Economia de Energia.
struct DeviceBatteryView: View {
    let scale: CGFloat

    @State private var batteryLevel: Float
    @State private var batteryState: UIDevice.BatteryState
    @State private var isLowPowerMode: Bool

    private let totalSegments = 5

    private static let fullOliveColor = Color(red: 132.0 / 255.0, green: 102.0 / 255.0, blue: 48.0 / 255.0)
    private static let partialBeigeColor = Color(red: 196.0 / 255.0, green: 180.0 / 255.0, blue: 148.0 / 255.0)
    private static let lowPowerYellowColor = Color(red: 236.0 / 255.0, green: 212.0 / 255.0, blue: 76.0 / 255.0)
    private static let criticalRedColor = Color(red: 184.0 / 255.0, green: 0.0 / 255.0, blue: 0.0 / 255.0)

    init(scale: CGFloat = 1.0) {
        self.scale = scale
        // Habilita antes da primeira leitura para evitar flash inicial com -1.0
        UIDevice.current.isBatteryMonitoringEnabled = true
        _batteryLevel = State(initialValue: UIDevice.current.batteryLevel)
        _batteryState = State(initialValue: UIDevice.current.batteryState)
        _isLowPowerMode = State(initialValue: ProcessInfo.processInfo.isLowPowerModeEnabled)
        #if DEBUG
        Self.verifyBatteryRules()
        #endif
    }

    static func percent(for level: Float) -> Int? {
        guard level >= 0 else { return nil }
        return Int((Double(level) * 100.0).rounded())
    }

    static func filledSegments(for level: Float, total: Int = 5) -> Int {
        // No Simulador `batteryLevel` retorna -1.0; usa carga cheia como fallback visual.
        guard let pct = percent(for: level) else { return total }
        if pct <= 0 { return 0 }
        let step = max(1, 100 / max(1, total))
        return min(total, max(1, (pct + step - 1) / step))
    }

    static func segmentColor(
        level: Float,
        isCharging: Bool,
        isLowPowerMode: Bool,
        total: Int = 5
    ) -> Color {
        let pct = percent(for: level)
        let filled = filledSegments(for: level, total: total)

        if !isCharging, let pct, pct > 0, pct < 10 { return criticalRedColor }
        if isLowPowerMode { return lowPowerYellowColor }
        return filled >= total ? fullOliveColor : partialBeigeColor
    }

    #if DEBUG
    private static var didVerifyRules = false
    private static func verifyBatteryRules() {
        guard !didVerifyRules else { return }
        didVerifyRules = true
        assert(filledSegments(for: -1.0) == 5)
        assert(filledSegments(for: 0.0) == 0)
        assert(filledSegments(for: 0.05) == 1)
        assert(filledSegments(for: 0.20) == 1)
        assert(filledSegments(for: 0.80) == 4)
        assert(filledSegments(for: 0.85) == 5)
        assert(segmentColor(level: 0.05, isCharging: false, isLowPowerMode: false) == criticalRedColor)
        assert(segmentColor(level: 0.05, isCharging: true, isLowPowerMode: false) == partialBeigeColor)
        assert(segmentColor(level: 0.50, isCharging: false, isLowPowerMode: true) == lowPowerYellowColor)
        assert(segmentColor(level: 1.00, isCharging: false, isLowPowerMode: false) == fullOliveColor)
    }
    #endif

    private var isCharging: Bool { batteryState == .charging }
    private var filledCount: Int { Self.filledSegments(for: batteryLevel, total: totalSegments) }
    private var activeSegmentColor: Color {
        Self.segmentColor(level: batteryLevel, isCharging: isCharging, isLowPowerMode: isLowPowerMode, total: totalSegments)
    }

    var body: some View {
        let bodyWidth = 44 * scale
        let capWidth = 4.5 * scale
        let totalWidth = bodyWidth + capWidth
        let height = 22 * scale
        let strokeW = max(1.9, 2.6 * scale)

        ZStack(alignment: .leading) {
            HStack(spacing: max(1.5, 2.0 * scale)) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    Rectangle()
                        .fill(index < filledCount ? activeSegmentColor : Color.clear)
                }
            }
            .padding(max(3.0, 4.0 * scale))
            .frame(width: bodyWidth, height: height)

            BatteryOutlineShape(capWidth: capWidth, capHeightRatio: 0.42)
                .stroke(
                    RetroTerminalStyle.ink,
                    style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round)
                )
                .frame(width: totalWidth, height: height)

            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 26 * scale, weight: .semibold))
                    .foregroundStyle(RetroTerminalStyle.ink)
                    .frame(width: bodyWidth, height: height)
            }
        }
        .frame(width: totalWidth, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(batteryAccessibilityLabel)
        .onAppear(perform: syncBatteryStatus)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            syncBatteryStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            syncBatteryStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func syncBatteryStatus() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private var batteryAccessibilityLabel: String {
        guard let pct = Self.percent(for: batteryLevel) else { return "Bateria" }
        var parts = ["Bateria em \(pct) por cento"]
        if isCharging { parts.append("carregando") }
        if isLowPowerMode { parts.append("modo economia de energia") }
        return parts.joined(separator: ", ")
    }
}

/// Silhueta contínua da bateria com o polo positivo direito também contornado/vazado.
private struct BatteryOutlineShape: Shape {
    let capWidth: CGFloat
    let capHeightRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let bodyMaxX = max(rect.minX + 6, rect.maxX - capWidth)
        let capH = rect.height * capHeightRatio
        let capTop = rect.midY - capH * 0.5
        let capBottom = rect.midY + capH * 0.5

        let rBody = min(3.2, rect.height * 0.16)
        let rCap = min(1.8, capH * 0.22)
        let rNotch: CGFloat = 0.8

        let pTL = CGPoint(x: rect.minX, y: rect.minY)
        let pTR = CGPoint(x: bodyMaxX, y: rect.minY)
        let pNotchTop = CGPoint(x: bodyMaxX, y: capTop)
        let pCapTR = CGPoint(x: rect.maxX, y: capTop)
        let pCapBR = CGPoint(x: rect.maxX, y: capBottom)
        let pNotchBot = CGPoint(x: bodyMaxX, y: capBottom)
        let pBR = CGPoint(x: bodyMaxX, y: rect.maxY)
        let pBL = CGPoint(x: rect.minX, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rBody, y: rect.minY))
        path.addArc(tangent1End: pTR, tangent2End: pNotchTop, radius: rBody)
        path.addArc(tangent1End: pNotchTop, tangent2End: pCapTR, radius: rNotch)
        path.addArc(tangent1End: pCapTR, tangent2End: pCapBR, radius: rCap)
        path.addArc(tangent1End: pCapBR, tangent2End: pNotchBot, radius: rCap)
        path.addArc(tangent1End: pNotchBot, tangent2End: pBR, radius: rNotch)
        path.addArc(tangent1End: pBR, tangent2End: pBL, radius: rBody)
        path.addArc(tangent1End: pBL, tangent2End: pTL, radius: rBody)
        path.addArc(tangent1End: pTL, tangent2End: pTR, radius: rBody)
        path.closeSubpath()
        return path
    }
}
