import SwiftUI

struct ResolvedTypography: Equatable, Sendable {
    let font: Font
    let fontSize: CGFloat
    let familyName: String
    let weightLabel: String
    let extraStrokeWidth: CGFloat
    let whisperOpacityMultiplier: Double
    /// Fontes ilustradas de peso único (`CatsFont`, `SnowtopCaps`) que protegem cor, traço extra e erosões.
    let isDecorativeSingleWeight: Bool
}
