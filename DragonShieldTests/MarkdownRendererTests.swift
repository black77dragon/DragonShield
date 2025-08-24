import XCTest
@testable import DragonShield

final class MarkdownRendererTests: XCTestCase {
    func testPlainTextStripsMarkdown() {
        let md = "**Bold** _Italic_"
        let plain = MarkdownRenderer.plainText(from: md)
        XCTAssertEqual(plain, "Bold Italic")
    }
}
