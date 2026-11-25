import SwiftUI
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
