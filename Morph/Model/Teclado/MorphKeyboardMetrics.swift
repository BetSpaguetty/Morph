import SwiftUI

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
