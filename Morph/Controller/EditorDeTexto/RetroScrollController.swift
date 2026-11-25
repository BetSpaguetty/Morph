import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
final class RetroScrollController {
    var metrics = RetroScrollMetrics()
    var keyboardOverlap: CGFloat = 0
    var isFocused: Bool = false
    var renderVersion: Int = 0
    weak var textView: RetroCaretTextView?

    func markNeedsCanvasRedraw() {
        renderVersion &+= 1
    }

    func insertText(_ string: String) {
        textView?.insertVirtualText(string)
    }

    func deleteBackward() {
        textView?.deleteVirtualBackward()
    }

    func scrollToProgress(_ progress: CGFloat) {
        guard let tv = textView else { return }
        let clamped = min(1, max(0, progress))
        let targetY = -tv.adjustedContentInset.top + clamped * metrics.maxOffset
        tv.setContentOffset(CGPoint(x: tv.contentOffset.x, y: targetY), animated: false)
        tv.publishScrollMetrics()
        markNeedsCanvasRedraw()
    }

    func scrollDownByStep() {
        let step = max(56, metrics.viewportHeight * 0.24)
        _ = scrollDown(by: step, animated: true)
    }

    @discardableResult
    func scrollDown(by delta: CGFloat, animated: Bool = false) -> Bool {
        guard let tv = textView, metrics.needsScroll else { return false }
        let maxY = -tv.adjustedContentInset.top + metrics.maxOffset
        let nextY = min(maxY, tv.contentOffset.y + delta)
        guard nextY > tv.contentOffset.y + 0.1 else { return false }
        tv.setContentOffset(CGPoint(x: tv.contentOffset.x, y: nextY), animated: animated)
        if !animated {
            tv.publishScrollMetrics()
            markNeedsCanvasRedraw()
        }
        return true
    }

    func resignFocus() {
        _ = textView?.resignFirstResponder()
    }
}
