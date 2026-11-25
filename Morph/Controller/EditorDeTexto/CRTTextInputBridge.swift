import SwiftUI
import Observation

/// Ponte entre a área de escrita (dentro do shader Metal) e o `UITextView` invisível (fora do shader).
@MainActor
@Observable
final class CRTTextInputBridge {
    struct Session {
        var text: Binding<String>
        var metrics: RetroFrameMetrics
        var scrollController: RetroScrollController
        var focusRequestID: Int
        var useSystemKeyboard: Bool
        var isVirtualKeyboardVisible: Bool = false
        var onKeyboardDismissed: () -> Void
    }

    var session: Session?
    var editorFrameInCRT: CGRect = .zero
    var excludedFramesInCRT: [String: CGRect] = [:]
    var keyboardStartYInCRT: CGFloat = -1.0

    func setExcludedFrame(_ frame: CGRect, for key: String) {
        if frame.isEmpty {
            if excludedFramesInCRT[key] != nil {
                excludedFramesInCRT.removeValue(forKey: key)
            }
        } else if excludedFramesInCRT[key] != frame {
            excludedFramesInCRT[key] = frame
        }
    }
}
