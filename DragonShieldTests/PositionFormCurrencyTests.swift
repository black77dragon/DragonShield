import XCTest
@testable import DragonShield

final class PositionFormCurrencyTests: XCTestCase {
    func testInstrumentCurrencyLookup() {
        let instruments: [InstrumentInfo] = [
            (id: 1, name: "A", subClassId: 1, currency: "USD", valorNr: nil, tickerSymbol: nil, isin: nil, notes: nil),
            (id: 2, name: "B", subClassId: 1, currency: "CHF", valorNr: nil, tickerSymbol: nil, isin: nil, notes: nil)
        ]
        XCTAssertEqual(instrumentCurrency(for: 2, instruments: instruments), "CHF")
        XCTAssertNil(instrumentCurrency(for: nil, instruments: instruments))
        XCTAssertNil(instrumentCurrency(for: 3, instruments: instruments))
    }
}
