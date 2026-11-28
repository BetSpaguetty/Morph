import SwiftUI

struct FilesView: View {
    @Environment(MorphRouter.self) private var router
    @Environment(SavedFilesStore.self) private var savedFilesStore

    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat? = nil
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let metrics = RetroFrameMetrics(containerSize: geometry.size)

            VStack(spacing: 0) {
                header(metrics: metrics)
                    .zIndex(1)

                savedFilesList(metrics: metrics)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipShape(RoundedRectangle(cornerSize: metrics.cornerSize, style: .circular))
            .overlay {
                RetroFolderFrameShape()
                    .stroke(
                        RetroTerminalStyle.ink,
                        style: StrokeStyle(
                            lineWidth: metrics.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, metrics.horizontalOuterPadding)
            .padding(.vertical, metrics.verticalOuterPadding)
        }
        .onAppear {
            savedFilesStore.reload()
            scrollOffset = 0
            dragStartOffset = nil
        }
    }

    private func header(metrics: RetroFrameMetrics) -> some View {
        let scale = metrics.headerScale
        let iconSize = 20 * scale
        let buttonPadX = 6 * scale

        return HStack(spacing: 8 * scale) {
            Button {
                router.popToRoot()
            } label: {
                Image(systemName: "arrow.backward.circle")
                    .font(.system(size: iconSize, weight: .semibold))
                    .frame(width: iconSize, height: iconSize)
                    .padding(.horizontal, buttonPadX)
                    .frame(height: metrics.headerHeight)
                    .contentShape(Rectangle())
                    .crtHitAdjusted()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar ao início")

            Text("SAVED")
                .font(FontRegistrationManager.chicago(size: 32 * scale).bold())
                .tracking(1.2 * scale)
                .foregroundStyle(RetroTerminalStyle.ink)

            Spacer(minLength: 12 * scale)

            HStack(spacing: 10 * scale) {
                DeviceClockView(scale: scale)
                DeviceBatteryView(scale: scale)
            }
        }
        .padding(.leading, max(0, metrics.headerContentInsetX - buttonPadX))
        .padding(.trailing, metrics.headerContentInsetX)
        .frame(height: metrics.headerHeight)
        .padding(.top, 20 * metrics.headerScale)
    }

    private func savedFilesList(metrics: RetroFrameMetrics) -> some View {
        let maxScroll = max(0, contentHeight - viewportHeight)
        let clampedOffset = min(maxScroll, max(0, scrollOffset))

        return VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(FontRegistrationManager.chicago(size: 24 * metrics.headerScale).bold())
                Spacer()
                Text("date")
                    .font(FontRegistrationManager.chicago(size: 24 * metrics.headerScale).bold())
            }
            .foregroundStyle(RetroTerminalStyle.ink)
            .padding(.horizontal, 6 * metrics.headerScale)
            .padding(.bottom, 10 * metrics.headerScale)

            separator

            ZStack(alignment: .top) {
                Color.clear

                VStack(spacing: 0) {
                    if savedFilesStore.files.isEmpty {
                        Text("No saved files found")
                            .font(FontRegistrationManager.chicago(size: 13 * metrics.headerScale))
                            .foregroundStyle(RetroTerminalStyle.ink.opacity(0.75))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 6 * metrics.headerScale)
                    } else {
                        ForEach(savedFilesStore.files) { file in
                            SavedFileRow(file: file, scale: metrics.headerScale) {
                                router.push(.editor(fileID: file.id))
                            }
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if abs(contentHeight - height) > 0.5 {
                        contentHeight = height
                    }
                }
                .offset(y: -clampedOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if abs(viewportHeight - height) > 0.5 {
                    viewportHeight = height
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard maxScroll > 0 else { return }
                        if dragStartOffset == nil {
                            dragStartOffset = clampedOffset
                        }
                        let base = dragStartOffset ?? 0
                        scrollOffset = min(maxScroll, max(0, base - value.translation.height))
                    }
                    .onEnded { _ in
                        dragStartOffset = nil
                    }
            )
        }
        .padding(.horizontal, metrics.headerContentInsetX)
        .padding(.top, 14 * metrics.headerScale)
        .padding(.bottom, 18 * metrics.headerScale)
    }

    private var separator: some View {
        Rectangle()
            .fill(RetroTerminalStyle.ink.opacity(0.48))
            .frame(height: 1.5)
    }
}

/// Linha selecionável que representa um arquivo persistido no aplicativo.
private struct SavedFileRow: View {
    let file: SavedMorphFile
    let scale: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack {
                    Text(file.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 12 * scale)
                    Text(dateLabel)
                        .monospacedDigit()
                }
                .font(FontRegistrationManager.chicago(size: 16 * scale))
                .foregroundStyle(RetroTerminalStyle.ink)
                .padding(.horizontal, 6 * scale)
                .padding(.vertical, 10 * scale)
                .contentShape(Rectangle())

                Rectangle()
                    .fill(RetroTerminalStyle.ink.opacity(0.48))
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(.plain)
        .crtHitAdjusted()
        .accessibilityLabel("\(file.name), salvo em \(dateLabel)")
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: file.savedAt)
    }
}

#Preview {
    FilesView()
        .environment(MorphRouter())
        .environment(SavedFilesStore())
}
