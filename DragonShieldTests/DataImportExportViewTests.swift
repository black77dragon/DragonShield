import XCTest
import SwiftUI
@testable import DragonShield

final class DataImportExportViewTests: XCTestCase {
    func testViewInitializes() {
        let view = DataImportExportView().environmentObject(DatabaseManager())
        XCTAssertNotNil(view.body)
    }

    func testInstructionsViewInitializes() {
        let view = CreditSuisseInstructionsView()
        XCTAssertNotNil(view.body)
    }
}
