import XCTest
@testable import DragonShield

final class MarkdownRendererPlainTextTests: XCTestCase {
    func testPlainTextStripsMarkdown() {
        let md = "**Hello** _world_ [link](https://example.com)"
        let result = MarkdownRenderer.plainText(from: md)
        XCTAssertEqual(result, "Hello world link")
    }
}
