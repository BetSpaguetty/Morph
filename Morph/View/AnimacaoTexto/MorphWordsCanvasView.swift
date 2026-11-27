import SwiftUI

// MARK: - Canvas de Palavras Equatable (Sem Closures no Diff + Relógio Isolado por Palavra)

struct MorphWordsCanvasView: View, Equatable {
    let plans: [WordAnimationPlan]
    let wordSpacings: [CGFloat]
    let layoutKey: Int
    let scope: ModificationScope
    let selectedWordIndex: Int
    let stageReferenceDate: Date
    let isAndamentoPaused: Bool
    var onWhiteCanvas: Bool = false
    var maxAvailableWidth: CGFloat = 320
    var onSelectWord: ((Int) -> Void)? = nil

    static func == (lhs: MorphWordsCanvasView, rhs: MorphWordsCanvasView) -> Bool {
        lhs.plans == rhs.plans
            && lhs.wordSpacings == rhs.wordSpacings
            && lhs.layoutKey == rhs.layoutKey
            && lhs.scope == rhs.scope
            && lhs.selectedWordIndex == rhs.selectedWordIndex
            && lhs.stageReferenceDate == rhs.stageReferenceDate
            && lhs.isAndamentoPaused == rhs.isAndamentoPaused
            && lhs.onWhiteCanvas == rhs.onWhiteCanvas
            && abs(lhs.maxAvailableWidth - rhs.maxAvailableWidth) < 0.5
    }

    static func computeWordSpacings(plans: [WordAnimationPlan]) -> [CGFloat] {
        plans.indices.map { index in
            let currentDist = plans[index].scores[.distancia]
            let nextDist = (index + 1 < plans.count) ? plans[index + 1].scores[.distancia] : currentDist
            switch max(currentDist, nextDist) {
            case 0: return 14
            case 1: return 24
            case 2: return 36
            case 3: return 52
            case 4: return 70
            case 5: return 92
            default: return 14
            }
        }
    }

    static func computeLayoutKey(plans: [WordAnimationPlan]) -> Int {
        var acc = plans.count
        for (i, p) in plans.enumerated() {
            let wordHash = MorphDeterministicHash.stableStringID(p.word)
            let sizeKey = Int(p.typography.fontSize.rounded()) &* 31
                &+ MorphDeterministicHash.stableStringID(p.typography.familyName)
                &+ MorphDeterministicHash.stableStringID(p.typography.weightLabel)
                &+ p.scores[.abertura] &* 13
                &+ p.scores[.distancia] &* 7
                &+ MorphDeterministicHash.stableStringID(p.staticStructure?.effectID.rawValue ?? "")
                &+ MorphDeterministicHash.stableStringID(p.continuous?.effectID.rawValue ?? "")
                &+ MorphDeterministicHash.stableStringID(p.entrance?.effectID.rawValue ?? "")
                &+ MorphDeterministicHash.stableStringID(p.overlay?.effectID.rawValue ?? "")
            acc = Int(truncatingIfNeeded: MorphDeterministicHash.mix(acc, wordHash ^ sizeKey, i))
        }
        return acc
    }

    var body: some View {
        MorphFlowLayout(
            lineSpacing: 30,
            wordSpacings: wordSpacings,
            layoutKey: layoutKey
        ) {
            ForEach(plans, id: \.wordIndex) { plan in
                let isSelected = (scope == .specificWord && plan.wordIndex == selectedWordIndex)

                if scope == .specificWord {
                    MorphWordClockView(
                        plan: plan,
                        stageReferenceDate: stageReferenceDate,
                        isPaused: isAndamentoPaused,
                        isSelectedInWordMode: isSelected,
                        showWordSelectionHighlight: true,
                        onWhiteCanvas: onWhiteCanvas,
                        maxAvailableWidth: maxAvailableWidth
                    )
                    .equatable()
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectWord?(plan.wordIndex) }
                } else {
                    // Em modo frase inteira o tap é tratado uma única vez pelo container externo (evita disputa com DragGesture).
                    MorphWordClockView(
                        plan: plan,
                        stageReferenceDate: stageReferenceDate,
                        isPaused: isAndamentoPaused,
                        isSelectedInWordMode: false,
                        showWordSelectionHighlight: false,
                        onWhiteCanvas: onWhiteCanvas,
                        maxAvailableWidth: maxAvailableWidth
                    )
                    .equatable()
                }
            }
        }
    }
}

// MARK: - Layout Customizado de Fluxo com Cache (Evita Re-Medir Todas as Palavras Durante o Scroll)

struct MorphFlowLayout: Layout {
    var lineSpacing: CGFloat = 18
    var wordSpacings: [CGFloat] = []
    var layoutKey: Int = 0

    struct Cache {
        var maxWidth: CGFloat = -1
        var layoutKey: Int = 0
        var subviewCount: Int = -1
        var wordSpacings: [CGFloat] = []
        var rows: [CachedRow] = []
        var totalHeight: CGFloat = 60
    }

    struct CachedItem {
        let index: Int
        let size: CGSize
        let spacingAfter: CGFloat
    }

    struct CachedRow {
        var items: [CachedItem] = []
        var totalWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let maxWidth = proposal.width ?? 340
        ensureCache(maxWidth: maxWidth, subviews: subviews, cache: &cache)
        return CGSize(width: maxWidth, height: cache.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        ensureCache(maxWidth: bounds.width, subviews: subviews, cache: &cache)
        var currentY = bounds.minY + max(0, (bounds.height - cache.totalHeight) / 2.0)

        for row in cache.rows {
            var currentX = bounds.minX + max(0, (bounds.width - row.totalWidth) / 2.0)
            for item in row.items {
                guard item.index < subviews.count else { continue }
                let centerX = currentX + item.size.width * 0.5
                let centerY = currentY + row.maxHeight * 0.5
                // `.unspecified` impede o SwiftUI de truncar palavras com `...` caso a largura varie em ~1pt após a entrada 1x.
                subviews[item.index].place(
                    at: CGPoint(x: centerX, y: centerY),
                    anchor: .center,
                    proposal: .unspecified
                )
                currentX += item.size.width + item.spacingAfter
            }
            currentY += row.maxHeight + lineSpacing
        }
    }

    private func ensureCache(maxWidth: CGFloat, subviews: Subviews, cache: inout Cache) {
        if abs(cache.maxWidth - maxWidth) < 0.5
            && cache.layoutKey == layoutKey
            && cache.subviewCount == subviews.count
            && cache.wordSpacings == wordSpacings {
            return
        }

        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let rawHeight = rows.reduce(CGFloat(0)) { $0 + $1.maxHeight }
            + CGFloat(max(0, rows.count - 1)) * lineSpacing
        cache.maxWidth = maxWidth
        cache.layoutKey = layoutKey
        cache.subviewCount = subviews.count
        cache.wordSpacings = wordSpacings
        cache.rows = rows
        cache.totalHeight = max(60, rawHeight)
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [CachedRow] {
        guard !subviews.isEmpty else { return [] }
        var rows: [CachedRow] = [CachedRow()]

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let spacing = index < wordSpacings.count ? wordSpacings[index] : 10.0

            let currentRow = rows[rows.count - 1]
            let proposedWidth = currentRow.items.isEmpty
                ? size.width
                : currentRow.totalWidth + (currentRow.items.last?.spacingAfter ?? 10.0) + size.width

            if !currentRow.items.isEmpty && proposedWidth > maxWidth {
                var newRow = CachedRow()
                newRow.items.append(CachedItem(index: index, size: size, spacingAfter: spacing))
                newRow.totalWidth = size.width
                newRow.maxHeight = size.height
                rows.append(newRow)
            } else {
                let prevSpacing = currentRow.items.last?.spacingAfter ?? 0
                rows[rows.count - 1].items.append(CachedItem(index: index, size: size, spacingAfter: spacing))
                rows[rows.count - 1].totalWidth += (currentRow.items.isEmpty ? 0 : prevSpacing) + size.width
                rows[rows.count - 1].maxHeight = max(rows[rows.count - 1].maxHeight, size.height)
            }
        }
        return rows
    }
}
