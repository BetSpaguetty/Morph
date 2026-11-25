import SwiftUI

// MARK: - Scrollbar Retrô Condicional (Cápsula com `=` + Botão `▼`)

struct RetroScrollbarView: View {
    let metrics: RetroFrameMetrics
    let controller: RetroScrollController

    @Environment(\.crtBarrelTransform) private var barrelTransform
    @Environment(CRTTextInputBridge.self) private var textInputBridge

    @State private var dragStartProgress: CGFloat?
    @State private var dragStartLogicalY: CGFloat = 0
    @State private var trackFrameInCRT: CGRect = .zero
    @State private var isHoldingDown = false
    @State private var holdScrollTask: Task<Void, Never>?

    private var scale: CGFloat { metrics.headerScale }
    private var barWidth: CGFloat { 32 * scale }
    private var strokeWidth: CGFloat { max(1.8, metrics.lineWidth * 0.65) }
    private var buttonStrokeWidth: CGFloat { max(2.2, metrics.lineWidth * 0.88) }

    var body: some View {
        if controller.metrics.needsScroll {
            VStack(spacing: 10 * scale) {
                GeometryReader { trackGeo in
                    let trackH = max(1, trackGeo.size.height)
                    let minThumbH = min(trackH, max(54 * scale, barWidth * 1.8))
                    let thumbH = min(trackH, max(minThumbH, trackH * controller.metrics.visibleFraction))
                    let travel = max(0, trackH - thumbH)
                    let offsetY = travel * controller.metrics.progress

                    ZStack(alignment: .top) {
                        Color.clear

                        thumbCapsule
                            .frame(width: barWidth, height: thumbH)
                            .offset(y: offsetY)
                    }
                    .crtHitAdjusted()
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(CRTCoordinateSpace.name))
                    } action: { frame in
                        if trackFrameInCRT != frame {
                            trackFrameInCRT = frame
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard travel > 0 else { return }
                                let logicalCurrentY = logicalTrackY(for: value.location)
                                if dragStartProgress == nil {
                                    let logicalStartY = logicalTrackY(for: value.startLocation)
                                    dragStartLogicalY = logicalStartY
                                    if logicalStartY >= offsetY && logicalStartY <= offsetY + thumbH {
                                        dragStartProgress = controller.metrics.progress
                                    } else {
                                        let jumped = min(1, max(0, (logicalStartY - thumbH * 0.5) / travel))
                                        dragStartProgress = jumped
                                        controller.scrollToProgress(jumped)
                                    }
                                }
                                if let start = dragStartProgress {
                                    controller.scrollToProgress(start + (logicalCurrentY - dragStartLogicalY) / travel)
                                }
                            }
                            .onEnded { _ in dragStartProgress = nil }
                    )
                }
                .frame(width: barWidth)

                downArrowButton
            }
            .padding(.top, 16 * scale)
            // Mantém a scrollbar e o botão ▼ visíveis acima do teclado do sistema quando aberto
            .padding(.bottom, max(14 * scale, controller.keyboardOverlap + 10 * scale))
            .padding(.trailing, 14 * scale)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(CRTCoordinateSpace.name))
            } action: { frame in
                textInputBridge.setExcludedFrame(frame, for: "scrollbar")
            }
            .transition(.opacity)
            .onDisappear {
                stopContinuousScroll()
                textInputBridge.setExcludedFrame(.zero, for: "scrollbar")
            }
        }
    }

    private func logicalTrackY(for localPoint: CGPoint) -> CGFloat {
        guard barrelTransform.isActive, !trackFrameInCRT.isEmpty else { return localPoint.y }
        let screenPoint = CGPoint(x: trackFrameInCRT.minX + localPoint.x, y: trackFrameInCRT.minY + localPoint.y)
        return barrelTransform.screenToLogical(screenPoint).y - trackFrameInCRT.minY
    }

    private var thumbCapsule: some View {
        ZStack {
            Capsule()
                .stroke(RetroTerminalStyle.ink, lineWidth: strokeWidth)

            VStack {
                gripLines
                Spacer(minLength: 4)
                gripLines
            }
            .padding(.vertical, 12 * scale)
        }
    }

    private var gripLines: some View {
        VStack(spacing: max(3, 4 * scale)) {
            ForEach(0..<2, id: \.self) { _ in
                Capsule()
                    .fill(RetroTerminalStyle.ink)
                    .frame(width: barWidth * 0.34, height: max(1.6, 2.0 * scale))
            }
        }
    }

    private var downArrowButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                .stroke(RetroTerminalStyle.ink, lineWidth: buttonStrokeWidth)

            DownTriangleShape()
                .fill(RetroTerminalStyle.ink)
                .frame(width: barWidth * 0.44, height: barWidth * 0.36)
                .offset(y: 1 * scale)
        }
        .frame(width: barWidth, height: barWidth)
        .opacity(isHoldingDown ? 0.65 : 1.0)
        .crtHitAdjusted()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHoldingDown else { return }
                    startPressDown()
                }
                .onEnded { _ in stopContinuousScroll() }
        )
        .accessibilityLabel("Rolar texto para baixo")
        .accessibilityAddTraits(.isButton)
    }

    private func startPressDown() {
        isHoldingDown = true
        controller.scrollDownByStep()

        holdScrollTask?.cancel()
        holdScrollTask = Task {
            try? await Task.sleep(for: .milliseconds(260))
            while !Task.isCancelled && isHoldingDown {
                guard controller.scrollDown(by: 4.5) else { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func stopContinuousScroll() {
        isHoldingDown = false
        holdScrollTask?.cancel()
        holdScrollTask = nil
    }
}

private struct DownTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.16
        let p1 = CGPoint(x: rect.minX, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY)
        let p3 = CGPoint(x: rect.midX, y: rect.maxY)

        var path = Path()
        path.move(to: CGPoint(x: (p1.x + p2.x) * 0.5, y: p1.y))
        path.addArc(tangent1End: p2, tangent2End: p3, radius: r)
        path.addArc(tangent1End: p3, tangent2End: p1, radius: r)
        path.addArc(tangent1End: p1, tangent2End: p2, radius: r)
        path.closeSubpath()
        return path
    }
}
