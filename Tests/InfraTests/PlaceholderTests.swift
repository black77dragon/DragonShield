import XCTest
@testable import Infra

final class PlaceholderInfraTests: XCTestCase {
    func testDoNothing() {
        InfraService.doNothing()
    }
}
