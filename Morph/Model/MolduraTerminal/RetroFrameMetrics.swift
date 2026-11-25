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
