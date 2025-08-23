import XCTest
@testable import DragonShield

final class ThemeUpdateReaderViewTests: XCTestCase {
    func testDisplayTitleFallbacksToHost() {
        let link = Link(id: 1, normalizedURL: "", rawURL: "https://example.com/path", title: nil, createdAt: "", createdBy: "")
        XCTAssertEqual(themeUpdateDisplayTitle(link), "example.com")
    }

    func testDisplayTitleUsesTitle() {
        let link = Link(id: 1, normalizedURL: "", rawURL: "https://example.com", title: "Doc", createdAt: "", createdBy: "")
        XCTAssertEqual(themeUpdateDisplayTitle(link), "Doc")
    }
}
