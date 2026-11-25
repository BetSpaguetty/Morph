import SwiftUI
import UIKit

// MARK: - Canvas SwiftUI do Editor (100% dentro do Shader Metal CRT)

struct RetroTextCanvasView: View {
    let scrollController: RetroScrollController
    let metrics: RetroFrameMetrics
    let text: String

    @Environment(CRTTextInputBridge.self) private var textInputBridge

    var body: some View {
        Canvas { context, size in
            _ = scrollController.renderVersion

            if let tv = scrollController.textView {
                context.withCGContext { cgContext in
                    cgContext.saveGState()
                    cgContext.clip(to: CGRect(origin: .zero, size: size))
                    tv.drawMirroredContent(in: cgContext, viewportSize: size)
                    cgContext.restoreGState()
                }

                if let caretRect = tv.currentCaretRectInViewport(), tv.caretAlpha > 0.01 {
                    var caretContext = context
                    caretContext.opacity = Double(tv.caretAlpha)
                    caretContext.draw(Image("caret_morph"), in: caretRect)
                }
            } else if text.isEmpty {
                // Caret inicial imediato no primeiro frame antes do overlay UIKit anexar
                let layout = RetroEditorLayout.compute(for: metrics, isVirtualKeyboardVisible: false)
                let lineH = UIFont.monospacedSystemFont(ofSize: layout.fontSize, weight: .regular).lineHeight
                let caretH = lineH * 1.06
                let caretW = caretH * (11.0 / 41.0)
                let rect = CGRect(
                    x: layout.insets.left + 5,
                    y: layout.insets.top + (lineH - caretH) * 0.5,
                    width: caretW,
                    height: caretH
                )
                context.draw(Image("caret_morph"), in: rect)
            }
        }
        .allowsHitTesting(false)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(CRTCoordinateSpace.name))
        } action: { frame in
            if textInputBridge.editorFrameInCRT != frame {
                textInputBridge.editorFrameInCRT = frame
            }
        }
    }
}

// MARK: - Indicador Minimalista de Processamento do Gemini

struct RetroProcessingIndicator: View {
    var scale: CGFloat = 1.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.28)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.28) % 4
            HStack(spacing: 5 * scale) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(RetroTerminalStyle.ink)
                        .frame(width: 6 * scale, height: 6 * scale)
                        .opacity(index < step ? 0.9 : 0.22)
                }
            }
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 6 * scale)
            .overlay(
                Capsule()
                    .stroke(RetroTerminalStyle.ink.opacity(0.45), lineWidth: max(1.4, 1.8 * scale))
            )
            .accessibilityLabel("Interpretando texto")
        }
    }
}
