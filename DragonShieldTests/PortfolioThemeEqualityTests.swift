import XCTest

@testable import DragonShield

final class PortfolioThemeEqualityTests: XCTestCase {
    func testTotalValueBaseAffectsEquality() {
        var a = PortfolioTheme(
            id: 1, name: "T", code: "T", description: nil, institutionId: nil, statusId: 1, createdAt: "2023-01-01T12:00:00Z", updatedAt: "2023-01-01T12:00:00Z", archivedAt: nil,
            softDelete: false
        )
        var b = a
        XCTAssertEqual(a, b)
        a.totalValueBase = 100
        XCTAssertNotEqual(a, b)
    }
}
