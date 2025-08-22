import XCTest
import SwiftUI
@testable import DragonShield

final class NewThemeUpdateViewTests: XCTestCase {
    func testViewInitializes() {
        let manager = DatabaseManager()
        let theme = PortfolioTheme(id: 1, name: "T", code: "T", description: nil, institutionId: nil, statusId: 1, createdAt: "", updatedAt: "", archivedAt: nil, softDelete: false)
        let view = NewThemeUpdateView(theme: theme, valuation: nil, onSave: { _ in }, onCancel: {}).environmentObject(manager)
        XCTAssertNotNil(view.body)
    }
}
