import SwiftUI

@main struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("morph.sineToneEnabled") private var sineToneEnabled = true
    @State private var tonePlayer = SineTonePlayer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, initial: true) { _, phase in
                    syncTone(for: phase)
                }
                .onChange(of: sineToneEnabled, initial: true) { _, _ in
                    syncTone(for: scenePhase)
                }
        }
    }

    private func syncTone(for phase: ScenePhase) {
        if phase == .active && sineToneEnabled {
            tonePlayer.start()
        } else {
            tonePlayer.stop()
        }
    }
}
