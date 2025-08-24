import XCTest
@testable import DragonShield

final class ThemeStatusSaveErrorTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(ThemeStatusSaveError.codeExists, ThemeStatusSaveError.codeExists)
    }
}
