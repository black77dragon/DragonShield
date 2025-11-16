@testable import DragonShield
import XCTest

final class PositionFormInstitutionTests: XCTestCase {
    func testAccountInstitutionLookup() {
        let accounts: [AccountInfo] = [
            (id: 1, name: "A", institutionId: 10, institutionName: "Bank A"),
            (id: 2, name: "B", institutionId: 20, institutionName: "Bank B"),
        ]
        let info = accountInstitution(for: 2, accounts: accounts)
        XCTAssertEqual(info?.id, 20)
        XCTAssertEqual(info?.name, "Bank B")
        XCTAssertNil(accountInstitution(for: nil, accounts: accounts))
        XCTAssertNil(accountInstitution(for: 3, accounts: accounts))
    }
}
