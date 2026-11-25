import SwiftUI
import UIKit

struct RetroScrollMetrics: Equatable {
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var contentOffsetY: CGFloat = 0

    var maxOffset: CGFloat { max(0, contentHeight - viewportHeight) }
    var needsScroll: Bool { maxOffset > 4 }

    var progress: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return min(1, max(0, contentOffsetY / maxOffset))
    }

    var visibleFraction: CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(1, max(0.08, viewportHeight / contentHeight))
    }
}

enum RetroEditorLayout {
    static func compute(
        for metrics: RetroFrameMetrics,
        isVirtualKeyboardVisible: Bool
    ) -> (fontSize: CGFloat, insets: UIEdgeInsets) {
        let fw = metrics.frameSize.width
        let bodyH = max(120, metrics.frameSize.height - metrics.headerHeight)
        let compactWithKeyboard = isVirtualKeyboardVisible && bodyH < 420

        let fontSize = compactWithKeyboard
            ? min(22, max(17, 21 * metrics.headerScale))
            : min(26, max(19, 25 * metrics.headerScale))
        let leftInset = min(190, max(24, fw * 0.20))
        let topInset = compactWithKeyboard
            ? min(28, max(10, bodyH * 0.05))
            : min(68, max(20, bodyH * 0.11))
        let rightInset = max(62 * metrics.headerScale, fw * 0.11)
        let bottomInset = isVirtualKeyboardVisible
            ? (compactWithKeyboard ? 8 : 14)
            : max(24, bodyH * 0.08)

        return (fontSize, UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset))
    }
}
