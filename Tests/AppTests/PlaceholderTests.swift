import XCTest
@testable import App

final class PlaceholderAppTests: XCTestCase {
    func testRun() async {
        await AppStarter.run()
    }
}
