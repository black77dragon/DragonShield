import XCTest
@testable import DragonShield

final class ColorContrastTests: XCTestCase {
    func testIsDark() {
        XCTAssertTrue(ColorContrast.isDark(hex: "#6366F1"))
        XCTAssertFalse(ColorContrast.isDark(hex: "#F59E0B"))
    }

    func testHexInitializer() {
        XCTAssertNotNil(Color(hex: "#10B981"))
        XCTAssertNil(Color(hex: "#ZZZZZZ"))
    }
}
