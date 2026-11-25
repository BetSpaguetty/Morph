import SwiftUI
import UIKit

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
