import XCTest

@testable import DragonShield

final class PortfolioThemeEqualityTests: XCTestCase {
  func testTotalValueBaseAffectsEquality() {
    var a = PortfolioTheme(
      id: 1, name: "T", code: "T", statusId: 1, createdAt: "", updatedAt: "", archivedAt: nil,
      softDelete: false)
    var b = a
    XCTAssertEqual(a, b)
    a.totalValueBase = 100
    XCTAssertNotEqual(a, b)
  }
}
