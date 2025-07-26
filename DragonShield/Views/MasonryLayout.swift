import SwiftUI

struct MasonryLayout: Layout {
    var columns: Int
    var spacing: CGFloat = 0
    var verticalSpacing: CGFloat = 0

    typealias Cache = Void

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 0
        guard columns > 0, width > 0 else { return .zero }
        let columnWidth = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
            let index = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columnHeights[index] += size.height + verticalSpacing
        }
        let height = columnHeights.max() ?? 0
        return CGSize(width: width, height: height - verticalSpacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard columns > 0 else { return }
        let columnWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        for subview in subviews {
            let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
            let index = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let x = bounds.minX + CGFloat(index) * (columnWidth + spacing)
            let y = bounds.minY + columnHeights[index]
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .init(width: columnWidth, height: size.height))
            columnHeights[index] += size.height + verticalSpacing
        }
    }
}
