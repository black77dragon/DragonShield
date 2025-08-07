import XCTest
import SwiftUI
@testable import DragonShield
#if canImport(ViewInspector)
import ViewInspector

extension TargetValueCell: Inspectable {}

final class TargetValueCellTests: XCTestCase {
    func testShowsWarningIconWhenValidationFails() throws {
        let view = TargetValueCell(text: "3'000'000.00", hasValidationErrors: true)
        let hStack = try view.inspect().hStack()
        XCTAssertNoThrow(try hStack.image(1))
        XCTAssertEqual(try hStack.image(1).actualImage().name(), "exclamationmark.triangle.fill")
    }
}
#endif
