import XCTest
import SwiftUI
@testable import DragonShield

final class ThemeStatusColorPresetsTests: XCTestCase {
    func testPresetCount() {
        XCTAssertEqual(themeStatusColorPresets.count, 20)
    }

    func testContainsEmeraldDefault() {
        XCTAssertTrue(themeStatusColorPresets.contains { $0.name == "Emerald" && $0.hex == "#10B981" })
    }

    func testTextColorContrast() {
        #if os(macOS)
        XCTAssertEqual(NSColor(Color.textColor(forHex: "#6366F1")), NSColor.white)
        XCTAssertEqual(NSColor(Color.textColor(forHex: "#EAB308")), NSColor.black)
        #else
        XCTAssertEqual(UIColor(Color.textColor(forHex: "#6366F1")), UIColor.white)
        XCTAssertEqual(UIColor(Color.textColor(forHex: "#EAB308")), UIColor.black)
        #endif
    }
}
