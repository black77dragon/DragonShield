import SwiftUI

enum TableFontMetrics {
    private static let minSize: CGFloat = 10
    private static let maxSize: CGFloat = 18
    private static let steps: Int = 5

    static func baseSize(for index: Int) -> CGFloat {
        guard steps > 1 else { return minSize }
        let clamped = max(0, min(index, steps - 1))
        let stepSize = (maxSize - minSize) / CGFloat(steps - 1)
        return minSize + CGFloat(clamped) * stepSize
    }
}
