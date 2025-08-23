import XCTest
import SwiftUI
@testable import DragonShield

final class ThemeStatusColorPresetTests: XCTestCase {
    func testPresetCount() {
        XCTAssertEqual(PortfolioThemeStatus.colorPresets.count, 20)
    }

    func testPresetLookup() {
        let emerald = PortfolioThemeStatus.preset(for: "#10B981")
        XCTAssertEqual(emerald?.name, "Emerald")
        let emeraldLower = PortfolioThemeStatus.preset(for: "#10b981")
        XCTAssertEqual(emeraldLower?.name, "Emerald")
    }

    func testColorContrast() {
        let dark = Color(hex: "#000000")
        XCTAssertNotNil(dark)
        XCTAssertTrue(dark?.isDarkColor ?? false)
        let light = Color(hex: "#FFFFFF")
        XCTAssertNotNil(light)
        XCTAssertFalse(light?.isDarkColor ?? true)
    }
}
