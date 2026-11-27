import SwiftUI

struct FilesView: View {
    @Environment(MorphRouter.self) private var router
    @Environment(SavedFilesStore.self) private var savedFilesStore

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
    }

    private func header(metrics: RetroFrameMetrics) -> some View {
        let scale = metrics.headerScale
        let iconSize = 20 * scale
        let buttonPadX = 6 * scale

        return HStack(spacing: 8 * scale) {
            Button {
                router.popToRoot()
            } label: {
                Image("botao_voltar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .padding(.horizontal, buttonPadX)
                    .frame(height: metrics.headerHeight)
                    .contentShape(Rectangle())
                    .crtHitAdjusted()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar ao início")

            Text("SAVED")
                .font(FontRegistrationManager.chicago(size: 16 * scale).bold())
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
    }

    private func savedFilesList(metrics: RetroFrameMetrics) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(FontRegistrationManager.chicago(size: 14 * metrics.headerScale).bold())
                Spacer()
                Text("date")
                    .font(FontRegistrationManager.chicago(size: 14 * metrics.headerScale).bold())
            }
            .foregroundStyle(RetroTerminalStyle.ink)
            .padding(.horizontal, 6 * metrics.headerScale)
            .padding(.bottom, 8 * metrics.headerScale)

            separator

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(savedFilesStore.files) { file in
                        Button {
                            router.push(.editor(fileID: file.id))
                        } label: {
                            HStack {
                                Text(file.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 12 * metrics.headerScale)
                                Text(dateLabel(for: file.savedAt))
                                    .monospacedDigit()
                            }
                            .font(FontRegistrationManager.chicago(size: 13 * metrics.headerScale))
                            .foregroundStyle(RetroTerminalStyle.ink)
                            .padding(.horizontal, 6 * metrics.headerScale)
                            .padding(.vertical, 9 * metrics.headerScale)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .crtHitAdjusted()

                        separator
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, metrics.headerContentInsetX)
        .padding(.top, metrics.headerHeight + 10 * metrics.headerScale)
        .padding(.bottom, 18 * metrics.headerScale)
    }

    private var separator: some View {
        Rectangle()
            .fill(RetroTerminalStyle.ink.opacity(0.48))
            .frame(height: 1.5)
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
}

#Preview {
    FilesView()
        .environment(MorphRouter())
        .environment(SavedFilesStore())
}
