import SwiftUI
import UIKit
import Observation

// MARK: - Configuração Visual do Teclado (Elevação, Sombra e Bandeja Intermediária)

@MainActor
@Observable
final class MorphKeyboardVisualConfig {
    var keyFillEnabled: Bool = true
    var keyShadowEnabled: Bool = true
    var trayBackgroundEnabled: Bool = true

    var isFlatState: Bool {
        !keyFillEnabled && !keyShadowEnabled && !trayBackgroundEnabled
    }

    var isDefaultState: Bool {
        keyFillEnabled && keyShadowEnabled && trayBackgroundEnabled
    }

    func revertToFlat() {
        keyFillEnabled = false
        keyShadowEnabled = false
        trayBackgroundEnabled = false
    }

    func restoreDefaults() {
        keyFillEnabled = true
        keyShadowEnabled = true
        trayBackgroundEnabled = true
    }
}

// MARK: - Modelo das Camadas, Teclas e Acentos (Fiel aos Protótipos Figma)

enum MorphKeyboardLayer: Equatable {
    case letters
    case numbers
    case symbols
}

enum MorphShiftState: Equatable {
    case off
    case once
    case capsLock

    var isUppercase: Bool { self != .off }
}

enum MorphKeyAction: Hashable {
    case character(String)
    case shift
    case backspace
    case switchLayer(MorphKeyboardLayer)
    case space
    case returnKey
    case dismiss
}

struct MorphKeySpec: Identifiable, Hashable {
    let id: String
    let action: MorphKeyAction
    let widthWeight: CGFloat
    let accents: [String]
    let defaultAccentIndex: Int

    var hasAccents: Bool { !accents.isEmpty }
}

enum MorphKeyboardLayout {
    private static let accentMap: [String: (options: [String], defaultIndex: Int)] = [
        // Letras à esquerda expandem para a direita; letras à direita expandem para a esquerda (como no iOS)
        "a": (["a", "á", "â", "ã", "à", "ä", "ª"], 0),
        "e": (["e", "é", "ê", "è", "ë"], 0),
        "i": (["ï", "ì", "î", "í", "i"], 4),
        "o": (["º", "ö", "ò", "õ", "ô", "ó", "o"], 6),
        "u": (["ü", "ù", "û", "ú", "u"], 4),
        "c": (["c", "ç"], 0),
        "n": (["ñ", "n"], 1)
    ]

    static func rows(for layer: MorphKeyboardLayer) -> [[MorphKeySpec]] {
        switch layer {
        case .letters:
            return [
                charRow(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], prefix: "L1"),
                charRow(["a", "s", "d", "f", "g", "h", "j", "k", "l"], prefix: "L2"),
                [specialKey(id: "L3_shift", action: .shift, weight: 1.12)]
                    + charRow(["z", "x", "c", "v", "b", "n", "m"], prefix: "L3")
                    + [specialKey(id: "L3_bs", action: .backspace, weight: 1.28)],
                [
                    specialKey(id: "L4_123", action: .switchLayer(.numbers), weight: 1.45),
                    specialKey(id: "L4_space", action: .space, weight: 4.95),
                    specialKey(id: "L4_return", action: .returnKey, weight: 1.35),
                    specialKey(id: "L4_dismiss", action: .dismiss, weight: 1.15)
                ]
            ]

        case .numbers:
            return [
                charRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], prefix: "N1"),
                charRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""], prefix: "N2"),
                [specialKey(id: "N3_sym", action: .switchLayer(.symbols), weight: 1.48)]
                    + charRow([".", ",", "?", "!", "'"], prefix: "N3")
                    + [specialKey(id: "N3_bs", action: .backspace, weight: 1.48)],
                [
                    specialKey(id: "N4_abc", action: .switchLayer(.letters), weight: 1.45),
                    specialKey(id: "N4_space", action: .space, weight: 4.95),
                    specialKey(id: "N4_return", action: .returnKey, weight: 1.35),
                    specialKey(id: "N4_dismiss", action: .dismiss, weight: 1.15)
                ]
            ]

        case .symbols:
            return [
                charRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], prefix: "S1"),
                charRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"], prefix: "S2"),
                [specialKey(id: "S3_123", action: .switchLayer(.numbers), weight: 1.48)]
                    + charRow([".", ",", "?", "!", "'"], prefix: "S3")
                    + [specialKey(id: "S3_bs", action: .backspace, weight: 1.48)],
                [
                    specialKey(id: "S4_abc", action: .switchLayer(.letters), weight: 1.45),
                    specialKey(id: "S4_space", action: .space, weight: 4.95),
                    specialKey(id: "S4_return", action: .returnKey, weight: 1.35),
                    specialKey(id: "S4_dismiss", action: .dismiss, weight: 1.15)
                ]
            ]
        }
    }

    static func resolvedAccentOptions(for key: MorphKeySpec, uppercase: Bool) -> [String] {
        guard key.hasAccents else { return [] }
        return key.accents.map { option in
            if option == "ª" || option == "º" { return option }
            return uppercase ? option.uppercased() : option
        }
    }

    private static func charRow(_ chars: [String], prefix: String) -> [MorphKeySpec] {
        chars.enumerated().map { idx, ch in
            let entry = accentMap[ch]
            return MorphKeySpec(
                id: "\(prefix)_\(idx)_\(ch)",
                action: .character(ch),
                widthWeight: 1.0,
                accents: entry?.options ?? [],
                defaultAccentIndex: entry?.defaultIndex ?? 0
            )
        }
    }

    private static func specialKey(id: String, action: MorphKeyAction, weight: CGFloat) -> MorphKeySpec {
        MorphKeySpec(id: id, action: action, widthWeight: weight, accents: [], defaultAccentIndex: 0)
    }
}

// MARK: - Métricas Responsivas (iPads mini / 11" / 13" em Portrait e Landscape + iPhone Landscape)

struct MorphKeyboardMetrics: Equatable {
    let isCompactHeight: Bool
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let unitKeyWidth: CGFloat
    let keyHeight: CGFloat
    let bottomRowHeight: CGFloat
    let cornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let strokeWidth: CGFloat
    let keyFontSize: CGFloat
    let utilityFontSize: CGFloat
    let accentCellWidth: CGFloat
    let accentCellHeight: CGFloat

    var totalHeight: CGFloat {
        topPadding + bottomPadding + (rowSpacing * 3) + (keyHeight * 3) + bottomRowHeight
    }

    init(bodySize: CGSize, frameMetrics: RetroFrameMetrics) {
        let w = max(240, bodySize.width)
        let h = max(140, bodySize.height)
        let aspect = w / h
        let compact = h < 340

        // Distância horizontal e vertical entre botões acompanha tamanho e proporção da tela
        let aspectFactor = Self.clamp(aspect / 1.45, min: 0.72, max: 1.25)
        let colSp = Self.clamp(w * 0.0115 * aspectFactor, min: compact ? 4.5 : 5.5, max: 14.0)
        let rowSp = Self.clamp(h * 0.016, min: compact ? 4.0 : 6.0, max: 12.0)

        let hPad = Self.clamp(max(frameMetrics.cornerSize.width * 0.72, w * 0.036), min: 14, max: 44)
        let topPad: CGFloat = compact ? 4 : 8
        let botPad = Self.clamp(frameMetrics.cornerSize.height * 0.42, min: compact ? 6 : 10, max: 18)

        let heightFraction: CGFloat = compact ? 0.64 : (aspect < 1.0 ? 0.36 : 0.48)
        let maxAllowedH: CGFloat = compact ? h * 0.66 : min(h * 0.52, 330)
        let minAllowedH: CGFloat = compact ? min(148, maxAllowedH) : min(210, maxAllowedH)
        let targetTotalH = Self.clamp(h * heightFraction, min: minAllowedH, max: maxAllowedH)

        let rawKeyH = (targetTotalH - topPad - botPad - rowSp * 3) / 3.84
        let keyH = Self.clamp(rawKeyH, min: compact ? 28 : 40, max: 72)
        let bottomRowH = max(25, keyH * 0.84)

        let usableW = max(180, w - hPad * 2)
        let rawUnitW = (usableW - colSp * 9) / 10.0
        // Limita a razão largura/altura para preservar a silhueta arredondada do Figma em telas muito largas
        let unitW = max(20, min(rawUnitW, keyH * 1.38))

        let minDim = min(unitW, keyH)

        self.isCompactHeight = compact
        self.columnSpacing = colSp
        self.rowSpacing = rowSp
        self.horizontalPadding = hPad
        self.topPadding = topPad
        self.bottomPadding = botPad
        self.unitKeyWidth = unitW
        self.keyHeight = keyH
        self.bottomRowHeight = bottomRowH
        self.cornerRadius = Self.clamp(minDim * 0.30, min: 8, max: 20)
        self.bottomCornerRadius = Self.clamp(bottomRowH * 0.34, min: 8, max: 18)
        self.strokeWidth = Self.clamp(frameMetrics.lineWidth * (compact ? 0.72 : 0.88), min: 1.8, max: 3.0)
        self.keyFontSize = Self.clamp(minDim * 0.43, min: 14, max: 26)
        self.utilityFontSize = Self.clamp(minDim * 0.33, min: 11, max: 20)
        self.accentCellWidth = Self.clamp(unitW * 0.76, min: compact ? 28 : 34, max: 52)
        self.accentCellHeight = Self.clamp(keyH * 0.90, min: compact ? 30 : 38, max: 58)
    }

    func keyWidth(for weight: CGFloat) -> CGFloat {
        unitKeyWidth * weight
    }

    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(upper, Swift.max(lower, value))
    }
}

// MARK: - Geometria do Popover de Acentos

struct AccentPopoverLayout: Equatable {
    let frameInKeyboard: CGRect
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let paddingX: CGFloat
    let paddingY: CGFloat

    static func compute(
        anchorFrameInKeyboard: CGRect,
        keyboardSize: CGSize,
        optionCount: Int,
        baseIndex: Int,
        metrics: MorphKeyboardMetrics
    ) -> AccentPopoverLayout {
        let count = max(1, optionCount)
        let sideMargin = max(6, metrics.horizontalPadding * 0.35)
        let maxPopoverW = max(60, keyboardSize.width - sideMargin * 2)

        var cellW = metrics.accentCellWidth
        let cellH = metrics.accentCellHeight
        let padX = max(4, cellW * 0.14)
        let padY = max(4, cellH * 0.12)

        let rawW = CGFloat(count) * cellW + padX * 2
        if rawW > maxPopoverW {
            cellW = max(22, (maxPopoverW - padX * 2) / CGFloat(count))
        }

        let popoverW = CGFloat(count) * cellW + padX * 2
        let popoverH = cellH + padY * 2

        let clampedBase = min(count - 1, max(0, baseIndex))
        let idealOriginX = anchorFrameInKeyboard.midX - padX - (CGFloat(clampedBase) + 0.5) * cellW
        let maxOriginX = max(sideMargin, keyboardSize.width - sideMargin - popoverW)
        let originX = min(maxOriginX, max(sideMargin, idealOriginX))
        let originY = anchorFrameInKeyboard.minY - popoverH - max(6, metrics.rowSpacing * 0.85)

        return AccentPopoverLayout(
            frameInKeyboard: CGRect(x: originX, y: originY, width: popoverW, height: popoverH),
            cellWidth: cellW,
            cellHeight: cellH,
            paddingX: padX,
            paddingY: padY
        )
    }

    func index(forKeyboardX x: CGFloat, optionCount: Int) -> Int {
        guard optionCount > 1, cellWidth > 0 else { return 0 }
        let raw = Int(floor((x - frameInKeyboard.minX - paddingX) / cellWidth))
        return min(optionCount - 1, max(0, raw))
    }
}

private struct AccentPopoverState: Equatable {
    let keyID: String
    let options: [String]
    let layout: AccentPopoverLayout
    var selectedIndex: Int
    var openLogicalX: CGFloat
    var hasSlid: Bool
}

private struct MorphKeyFramesPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Teclado Virtual Integrado à Tela CRT

struct MorphVirtualKeyboardView: View {
    let bodySize: CGSize
    let frameMetrics: RetroFrameMetrics
    let visualConfig: MorphKeyboardVisualConfig
    let startsCapitalized: Bool
    let onInsert: (String) -> Void
    let onDeleteBackward: () -> Void
    let onDismiss: () -> Void

    @Environment(\.crtBarrelTransform) private var barrelTransform
    @Environment(CRTTextInputBridge.self) private var textInputBridge

    @State private var layer: MorphKeyboardLayer = .letters
    @State private var shiftState: MorphShiftState
    @State private var pressedKeyID: String?
    @State private var accentState: AccentPopoverState?

    @State private var isTrackingTouch = false
    @State private var lastLogicalPoint: CGPoint = .zero
    @State private var lastShiftTapDate: Date?

    @State private var keyFramesInCRT: [String: CGRect] = [:]
    @State private var keyboardFrameInCRT: CGRect = .zero

    @State private var longPressTask: Task<Void, Never>?
    @State private var repeatDeleteTask: Task<Void, Never>?

    private static let popoverFill = Color(red: 238.0 / 255.0, green: 230.0 / 255.0, blue: 184.0 / 255.0)
    private static let keyFillColor = Color(red: 247.0 / 255.0, green: 241.0 / 255.0, blue: 208.0 / 255.0)
    private static let trayBackgroundColor = Color(red: 207.0 / 255.0, green: 196.0 / 255.0, blue: 144.0 / 255.0)
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    init(
        bodySize: CGSize,
        frameMetrics: RetroFrameMetrics,
        visualConfig: MorphKeyboardVisualConfig,
        startsCapitalized: Bool,
        onInsert: @escaping (String) -> Void,
        onDeleteBackward: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.bodySize = bodySize
        self.frameMetrics = frameMetrics
        self.visualConfig = visualConfig
        self.startsCapitalized = startsCapitalized
        self.onInsert = onInsert
        self.onDeleteBackward = onDeleteBackward
        self.onDismiss = onDismiss
        _shiftState = State(initialValue: startsCapitalized ? .once : .off)
        #if DEBUG
        Self.verifyKeyboardMathOnce()
        #endif
    }

    private var kbMetrics: MorphKeyboardMetrics {
        MorphKeyboardMetrics(bodySize: bodySize, frameMetrics: frameMetrics)
    }

    private var currentRows: [[MorphKeySpec]] {
        MorphKeyboardLayout.rows(for: layer)
    }

    var body: some View {
        let m = kbMetrics
        let rows = currentRows

        VStack(spacing: m.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                let isBottomRow = rowIndex == rows.count - 1
                let rowHeight = isBottomRow ? m.bottomRowHeight : m.keyHeight
                let radius = isBottomRow ? m.bottomCornerRadius : m.cornerRadius

                HStack(spacing: m.columnSpacing) {
                    ForEach(row) { key in
                        keyView(key: key, width: m.keyWidth(for: key.widthWeight), height: rowHeight, cornerRadius: radius, metrics: m)
                    }
                }
            }
        }
        .padding(.horizontal, m.horizontalPadding)
        .padding(.top, m.topPadding + (visualConfig.trayBackgroundEnabled ? (m.isCompactHeight ? 3 : 6) : 0))
        .padding(.bottom, m.bottomPadding)
        .frame(maxWidth: .infinity)
        .background {
            if visualConfig.trayBackgroundEnabled {
                keyboardTrayBackground(metrics: m)
            }
        }
        .contentShape(Rectangle())
        .crtHitAdjusted()
        .onPreferenceChange(MorphKeyFramesPreferenceKey.self) { frames in
            keyFramesInCRT = frames
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(CRTCoordinateSpace.name))
        } action: { frame in
            if keyboardFrameInCRT != frame {
                keyboardFrameInCRT = frame
            }
            let nextStartY = frame.isEmpty ? -1.0 : frame.minY
            if textInputBridge.keyboardStartYInCRT != nextStartY {
                textInputBridge.keyboardStartYInCRT = nextStartY
            }
        }
        .overlay(alignment: .topLeading) {
            if let accent = accentState {
                accentPopoverView(state: accent, metrics: m)
                    .allowsHitTesting(false)
            }
        }
        // Gesto único no espaço CRT: remapeia a distorção de barril uma vez para clique, segurar acentos e arraste
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(CRTCoordinateSpace.name))
                .onChanged { value in
                    handleTouchChanged(screenLocation: value.location, rows: rows, metrics: m)
                }
                .onEnded { _ in
                    handleTouchEnded(rows: rows)
                }
        )
        .onDisappear {
            cancelTimers()
            resetTouchState()
            if textInputBridge.keyboardStartYInCRT != -1.0 {
                textInputBridge.keyboardStartYInCRT = -1.0
            }
        }
    }

    // MARK: - Bandeja Intermediária e Visual das Teclas

    private func keyboardTrayBackground(metrics: MorphKeyboardMetrics) -> some View {
        ZStack(alignment: .top) {
            Self.trayBackgroundColor

            LinearGradient(
                colors: [RetroTerminalStyle.ink.opacity(0.11), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: metrics.isCompactHeight ? 5 : 8)

            Rectangle()
                .fill(RetroTerminalStyle.ink.opacity(0.42))
                .frame(height: max(1.4, metrics.strokeWidth * 0.7))
        }
    }

    private func keyView(
        key: MorphKeySpec,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        metrics: MorphKeyboardMetrics
    ) -> some View {
        let isPressed = pressedKeyID == key.id
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let pressDrop: CGFloat = (visualConfig.keyShadowEnabled && isPressed) ? 1.0 : 0.0

        return ZStack {
            if visualConfig.keyShadowEnabled {
                KeyBottomShadowShape(cornerRadius: cornerRadius)
                    .stroke(
                        RetroTerminalStyle.ink.opacity(isPressed ? 0.14 : 0.30),
                        style: StrokeStyle(
                            lineWidth: max(2.2, metrics.strokeWidth * 1.15),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .offset(y: isPressed ? 0.8 : 2.5)
                    .blur(radius: isPressed ? 0.4 : 1.0)
            }

            ZStack {
                if visualConfig.keyFillEnabled {
                    shape.fill(Self.keyFillColor.opacity(isPressed ? 0.34 : 0.62))
                }

                if isPressed {
                    shape.fill(RetroTerminalStyle.ink.opacity(0.16))
                }

                shape.stroke(RetroTerminalStyle.ink, lineWidth: metrics.strokeWidth)

                keyContent(for: key, height: height, metrics: metrics)
                    .foregroundStyle(RetroTerminalStyle.ink)
            }
            .offset(y: pressDrop)
        }
        .frame(width: width, height: height)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MorphKeyFramesPreferenceKey.self,
                    value: [key.id: proxy.frame(in: .named(CRTCoordinateSpace.name))]
                )
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: key))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func keyContent(for key: MorphKeySpec, height: CGFloat, metrics: MorphKeyboardMetrics) -> some View {
        switch key.action {
        case .character(let base):
            let label = (layer == .letters && shiftState.isUppercase) ? base.uppercased() : base
            Text(label)
                .font(.system(size: metrics.keyFontSize, weight: .regular, design: .monospaced))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

        case .shift:
            let iconSize = min(height * 0.48, metrics.unitKeyWidth * 0.48)
            VStack(spacing: max(1.5, metrics.strokeWidth * 0.8)) {
                ShiftArrowShape()
                    .fill(shiftState.isUppercase ? RetroTerminalStyle.ink : Color.clear)
                    .overlay(
                        ShiftArrowShape()
                            .stroke(
                                RetroTerminalStyle.ink,
                                style: StrokeStyle(lineWidth: metrics.strokeWidth, lineCap: .round, lineJoin: .round)
                            )
                    )
                    .frame(width: iconSize, height: iconSize * 0.92)

                if shiftState == .capsLock {
                    Capsule()
                        .fill(RetroTerminalStyle.ink)
                        .frame(width: iconSize * 0.72, height: max(2, metrics.strokeWidth * 0.85))
                }
            }

        case .backspace:
            let iconW = min(metrics.keyWidth(for: key.widthWeight) * 0.44, height * 0.62)
            let iconH = iconW * 0.68
            BackspaceIconShape()
                .stroke(
                    RetroTerminalStyle.ink,
                    style: StrokeStyle(lineWidth: max(1.6, metrics.strokeWidth * 0.85), lineCap: .round, lineJoin: .round)
                )
                .frame(width: iconW, height: iconH)

        case .switchLayer(let target):
            let title: String = {
                switch target {
                case .letters: return "ABC"
                case .numbers: return "123"
                case .symbols: return "#+="
                }
            }()
            Text(title)
                .font(.system(size: metrics.utilityFontSize, weight: .regular, design: .monospaced))
                .minimumScaleFactor(0.75)
                .lineLimit(1)

        case .space:
            Color.clear

        case .returnKey:
            let iconW = min(metrics.keyWidth(for: key.widthWeight) * 0.34, height * 0.68)
            let iconH = iconW * 0.54
            ReturnArrowShape()
                .stroke(
                    RetroTerminalStyle.ink,
                    style: StrokeStyle(lineWidth: max(1.6, metrics.strokeWidth * 0.85), lineCap: .round, lineJoin: .round)
                )
                .frame(width: iconW, height: iconH)

        case .dismiss:
            let iconSize = min(metrics.keyWidth(for: key.widthWeight) * 0.44, height * 0.54)
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: iconSize, weight: .medium))
        }
    }

    // MARK: - Balão Opaco de Acentos (Creme CRT #EEE6B8 + Selecionado Invertido)

    private func accentPopoverView(state: AccentPopoverState, metrics: MorphKeyboardMetrics) -> some View {
        let layout = state.layout
        let radius = max(10, metrics.cornerRadius * 0.85)
        let cellRadius = max(6, radius * 0.62)

        return HStack(spacing: 0) {
            ForEach(Array(state.options.enumerated()), id: \.offset) { idx, option in
                let isSelected = idx == state.selectedIndex
                Text(option)
                    .font(.system(size: metrics.keyFontSize, weight: isSelected ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? Self.popoverFill : RetroTerminalStyle.ink)
                    .frame(width: layout.cellWidth, height: layout.cellHeight)
                    .background(
                        RoundedRectangle(cornerRadius: cellRadius, style: .continuous)
                            .fill(isSelected ? RetroTerminalStyle.ink : Color.clear)
                    )
            }
        }
        .padding(.horizontal, layout.paddingX)
        .padding(.vertical, layout.paddingY)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Self.popoverFill)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(RetroTerminalStyle.ink, lineWidth: metrics.strokeWidth)
                )
        )
        .frame(width: layout.frameInKeyboard.width, height: layout.frameInKeyboard.height)
        .offset(x: layout.frameInKeyboard.minX, y: layout.frameInKeyboard.minY)
    }

    // MARK: - Máquina de Gestos com Remapeamento Barril

    private func handleTouchChanged(
        screenLocation: CGPoint,
        rows: [[MorphKeySpec]],
        metrics: MorphKeyboardMetrics
    ) {
        let logicalPoint = barrelTransform.screenToLogical(screenLocation)
        lastLogicalPoint = logicalPoint

        if !isTrackingTouch {
            isTrackingTouch = true
            guard let hitKey = hitTestKey(at: logicalPoint, in: rows, metrics: metrics) else { return }
            beginPress(on: hitKey, at: logicalPoint, metrics: metrics)
            return
        }

        // Modo seleção de acentos: desliza o dedo horizontalmente entre as opções
        if var accent = accentState {
            let deadzone = max(6, accent.layout.cellWidth * 0.22)
            if !accent.hasSlid && abs(logicalPoint.x - accent.openLogicalX) > deadzone {
                accent.hasSlid = true
            }
            if accent.hasSlid {
                let localX = logicalPoint.x - keyboardFrameInCRT.minX
                let nextIdx = accent.layout.index(forKeyboardX: localX, optionCount: accent.options.count)
                if nextIdx != accent.selectedIndex {
                    accent.selectedIndex = nextIdx
                    Self.selectionGenerator.selectionChanged()
                }
            }
            accentState = accent
            return
        }

        // Se o dedo arrastar para longe da tecla antes de abrir o popover, cancela o toque
        if let activeID = pressedKeyID, let frame = keyFramesInCRT[activeID] {
            let expanded = frame.insetBy(dx: -metrics.unitKeyWidth * 0.65, dy: -metrics.keyHeight * 0.75)
            if !expanded.contains(logicalPoint) {
                cancelTimers()
                pressedKeyID = nil
            }
        }
    }

    private func handleTouchEnded(rows: [[MorphKeySpec]]) {
        cancelTimers()

        if let accent = accentState {
            let chosen = accent.options[accent.selectedIndex]
            commitInsertedCharacter(chosen, fromLettersLayer: layer == .letters)
        } else if let activeID = pressedKeyID, let key = findKey(id: activeID, in: rows) {
            switch key.action {
            case .character(let base):
                let output = (layer == .letters && shiftState.isUppercase) ? base.uppercased() : base
                commitInsertedCharacter(output, fromLettersLayer: layer == .letters)
            case .space:
                onInsert(" ")
            case .returnKey:
                onInsert("\n")
            case .dismiss:
                onDismiss()
            case .shift, .backspace, .switchLayer:
                break // Já executados no toque inicial para resposta instantânea
            }
        }

        resetTouchState()
    }

    private func beginPress(on key: MorphKeySpec, at logicalPoint: CGPoint, metrics: MorphKeyboardMetrics) {
        pressedKeyID = key.id
        Self.impactGenerator.impactOccurred()

        switch key.action {
        case .shift:
            handleShiftTap()

        case .switchLayer(let target):
            layer = target
            if target != .letters {
                shiftState = .off
            }

        case .backspace:
            onDeleteBackward()
            startBackspaceRepeat()

        case .character:
            if layer == .letters && key.hasAccents {
                startAccentLongPress(for: key, metrics: metrics)
            }

        case .space, .returnKey, .dismiss:
            break
        }
    }

    private func handleShiftTap() {
        let now = Date()
        switch shiftState {
        case .off:
            shiftState = .once
        case .once:
            if let last = lastShiftTapDate, now.timeIntervalSince(last) < 0.35 {
                shiftState = .capsLock
            } else {
                shiftState = .off
            }
        case .capsLock:
            shiftState = .off
        }
        lastShiftTapDate = now
    }

    private func commitInsertedCharacter(_ text: String, fromLettersLayer: Bool) {
        onInsert(text)
        if fromLettersLayer && shiftState == .once {
            shiftState = .off
        }
    }

    private func startAccentLongPress(for key: MorphKeySpec, metrics: MorphKeyboardMetrics) {
        longPressTask?.cancel()
        longPressTask = Task {
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled, pressedKeyID == key.id else { return }
            await MainActor.run {
                openAccentPopover(for: key, metrics: metrics)
            }
        }
    }

    private func openAccentPopover(for key: MorphKeySpec, metrics: MorphKeyboardMetrics) {
        guard let keyFrameCRT = keyFramesInCRT[key.id], !keyboardFrameInCRT.isEmpty else { return }
        let options = MorphKeyboardLayout.resolvedAccentOptions(for: key, uppercase: shiftState.isUppercase)
        guard !options.isEmpty else { return }

        let anchorInKeyboard = keyFrameCRT.offsetBy(dx: -keyboardFrameInCRT.minX, dy: -keyboardFrameInCRT.minY)
        let layout = AccentPopoverLayout.compute(
            anchorFrameInKeyboard: anchorInKeyboard,
            keyboardSize: keyboardFrameInCRT.size,
            optionCount: options.count,
            baseIndex: key.defaultAccentIndex,
            metrics: metrics
        )

        Self.selectionGenerator.prepare()
        Self.impactGenerator.impactOccurred(intensity: 0.75)

        accentState = AccentPopoverState(
            keyID: key.id,
            options: options,
            layout: layout,
            selectedIndex: min(options.count - 1, max(0, key.defaultAccentIndex)),
            openLogicalX: lastLogicalPoint.x,
            hasSlid: false
        )
    }

    private func startBackspaceRepeat() {
        repeatDeleteTask?.cancel()
        repeatDeleteTask = Task {
            try? await Task.sleep(for: .milliseconds(360))
            while !Task.isCancelled && pressedKeyID != nil {
                await MainActor.run {
                    onDeleteBackward()
                }
                try? await Task.sleep(for: .milliseconds(85))
            }
        }
    }

    private func cancelTimers() {
        longPressTask?.cancel()
        longPressTask = nil
        repeatDeleteTask?.cancel()
        repeatDeleteTask = nil
    }

    private func resetTouchState() {
        isTrackingTouch = false
        pressedKeyID = nil
        accentState = nil
    }

    private func hitTestKey(
        at logicalPoint: CGPoint,
        in rows: [[MorphKeySpec]],
        metrics: MorphKeyboardMetrics
    ) -> MorphKeySpec? {
        let allKeys = rows.flatMap { $0 }

        // 1. Acerto exato dentro do retângulo lógico da tecla
        for key in allKeys {
            if let frame = keyFramesInCRT[key.id], frame.contains(logicalPoint) {
                return key
            }
        }

        // 2. Tolerância nas frestas entre teclas vizinhas para digitação fluida
        let maxGap = max(metrics.columnSpacing, metrics.rowSpacing) * 0.75 + 2
        var bestKey: MorphKeySpec?
        var bestDistSq = maxGap * maxGap

        for key in allKeys {
            guard let frame = keyFramesInCRT[key.id] else { continue }
            let dx = max(frame.minX - logicalPoint.x, 0, logicalPoint.x - frame.maxX)
            let dy = max(frame.minY - logicalPoint.y, 0, logicalPoint.y - frame.maxY)
            let distSq = dx * dx + dy * dy
            if distSq <= bestDistSq {
                bestDistSq = distSq
                bestKey = key
            }
        }

        return bestKey
    }

    private func findKey(id: String, in rows: [[MorphKeySpec]]) -> MorphKeySpec? {
        for row in rows {
            if let found = row.first(where: { $0.id == id }) { return found }
        }
        return nil
    }

    private func accessibilityLabel(for key: MorphKeySpec) -> String {
        switch key.action {
        case .character(let ch): return (layer == .letters && shiftState.isUppercase) ? ch.uppercased() : ch
        case .shift: return shiftState == .capsLock ? "Fixar maiúsculas" : "Maiúsculas"
        case .backspace: return "Apagar"
        case .switchLayer(.letters): return "Letras"
        case .switchLayer(.numbers): return "Números"
        case .switchLayer(.symbols): return "Símbolos"
        case .space: return "Espaço"
        case .returnKey: return "Nova linha"
        case .dismiss: return "Abaixar teclado"
        }
    }

    // MARK: - Autoverificação Matemática (DEBUG)

    #if DEBUG
    private static var didVerifyMath = false

    private static func verifyKeyboardMathOnce() {
        guard !didVerifyMath else { return }
        didVerifyMath = true

        // 1. Estrutura exata das 3 camadas do Figma + botão de abaixar teclado no canto inferior direito
        assert(MorphKeyboardLayout.rows(for: .letters).map(\.count) == [10, 9, 9, 4])
        assert(MorphKeyboardLayout.rows(for: .numbers).map(\.count) == [10, 10, 7, 4])
        assert(MorphKeyboardLayout.rows(for: .symbols).map(\.count) == [10, 10, 7, 4])

        // 2. Resolução de acentos preserva ª e º mesmo em maiúsculas
        let oKey = MorphKeyboardLayout.rows(for: .letters)[0][8]
        let upperO = MorphKeyboardLayout.resolvedAccentOptions(for: oKey, uppercase: true)
        assert(upperO.contains("Ó") && upperO.contains("Ô") && upperO.contains("Õ") && upperO.contains("º"))

        // 3. Responsividade entre diferentes telas de iPad e iPhone Landscape
        let devices: [(CGSize, Bool)] = [
            (CGSize(width: 1128, height: 835), false), // iPad Pro 13" Landscape
            (CGSize(width: 975, height: 668), false),  // iPad 11" Landscape
            (CGSize(width: 936, height: 606), false),  // iPad mini Landscape
            (CGSize(width: 677, height: 962), false),  // iPad 11" Portrait
            (CGSize(width: 704, height: 320), true)    // iPhone Landscape
        ]

        var landscapeSpacings: [CGFloat] = []
        var portraitSpacing: CGFloat = 0

        for (openingSize, expectCompact) in devices {
            let fm = RetroFrameMetrics(containerSize: openingSize)
            let body = CGSize(width: fm.frameSize.width, height: fm.frameSize.height - fm.headerHeight)
            let km = MorphKeyboardMetrics(bodySize: body, frameMetrics: fm)

            assert(km.isCompactHeight == expectCompact)
            let row1Width = km.unitKeyWidth * 10 + km.columnSpacing * 9
            assert(row1Width <= body.width - km.horizontalPadding * 2 + 0.5)
            assert(km.totalHeight < body.height - 60)

            if openingSize.width > openingSize.height && !expectCompact {
                landscapeSpacings.append(km.columnSpacing)
            } else if openingSize.height > openingSize.width {
                portraitSpacing = km.columnSpacing
            }
        }
        assert(landscapeSpacings.allSatisfy { $0 > portraitSpacing })

        // 4. Clamp do popover de acentos nas extremidades (tecla A na esquerda e tecla O na direita)
        let fm = RetroFrameMetrics(containerSize: CGSize(width: 975, height: 668))
        let body = CGSize(width: fm.frameSize.width, height: fm.frameSize.height - fm.headerHeight)
        let km = MorphKeyboardMetrics(bodySize: body, frameMetrics: fm)
        let kbSize = CGSize(width: body.width, height: km.totalHeight)

        let leftAnchor = CGRect(x: km.horizontalPadding, y: km.topPadding, width: km.unitKeyWidth, height: km.keyHeight)
        let leftPop = AccentPopoverLayout.compute(anchorFrameInKeyboard: leftAnchor, keyboardSize: kbSize, optionCount: 7, baseIndex: 0, metrics: km)
        assert(leftPop.frameInKeyboard.minX >= 0 && leftPop.frameInKeyboard.maxX <= kbSize.width)

        let rightAnchor = CGRect(x: kbSize.width - km.horizontalPadding - km.unitKeyWidth, y: km.topPadding, width: km.unitKeyWidth, height: km.keyHeight)
        let rightPop = AccentPopoverLayout.compute(anchorFrameInKeyboard: rightAnchor, keyboardSize: kbSize, optionCount: 7, baseIndex: 6, metrics: km)
        assert(rightPop.frameInKeyboard.minX >= 0 && rightPop.frameInKeyboard.maxX <= kbSize.width)
        assert(rightPop.index(forKeyboardX: rightPop.frameInKeyboard.minX, optionCount: 7) == 0)
        assert(rightPop.index(forKeyboardX: rightPop.frameInKeyboard.maxX, optionCount: 7) == 6)

        // 5. Estados de configuração visual (elevado padrão vs. chapado anterior)
        let cfg = MorphKeyboardVisualConfig()
        assert(cfg.isDefaultState && !cfg.isFlatState)
        cfg.revertToFlat()
        assert(cfg.isFlatState && !cfg.isDefaultState)
        cfg.restoreDefaults()
        assert(cfg.isDefaultState)
    }
    #endif
}

// MARK: - Formas Vetoriais dos Ícones (Peso de Traço Alinhado ao Terminal Retrô)

/// Arco inferior externo da tecla para projetar sombra limpa abaixo do botão sem escurecer o interior translúcido.
private struct KeyBottomShadowShape: Shape {
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

private struct ShiftArrowShape: Shape {
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

private struct BackspaceIconShape: Shape {
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

private struct ReturnArrowShape: Shape {
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
