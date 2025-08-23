import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#endif
@testable import DragonShield

final class ThemeStatusColorPresetsTests: XCTestCase {
    func testPresetCount() {
        XCTAssertEqual(ThemeStatusColorPreset.all.count, 20)
    }

    func testPresetLookup() {
        let green = ThemeStatusColorPreset.preset(for: "#22C55E")
        XCTAssertEqual(green?.name, "Green")
        XCTAssertNil(ThemeStatusColorPreset.preset(for: "#123ABC"))
    }

    func testContrastColor() {
        #if os(macOS)
        let lightColor = NSColor(Color.contrastColor(for: "#EAB308"))
        XCTAssertEqual(lightColor, .black)
        let darkColor = NSColor(Color.contrastColor(for: "#6366F1"))
        XCTAssertEqual(darkColor, .white)
        #endif
    }
}
