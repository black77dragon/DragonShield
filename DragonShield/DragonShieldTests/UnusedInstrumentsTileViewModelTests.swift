import XCTest
@testable import DragonShield

final class UnusedInstrumentsTileViewModelTests: XCTestCase {
    func testSortsAndLimitsResults() {
        var sample: [UnusedInstrument] = []
        for i in 0..<600 {
            let name = i % 2 == 0 ? "b\(i)" : "A\(i)"
            sample.append(UnusedInstrument(instrumentId: i, name: name, type: "", currency: "", lastActivity: nil, themesCount: 0, refsCount: 0))
        }
        let vm = UnusedInstrumentsTileViewModel()
        vm.process(all: sample)
        XCTAssertEqual(vm.items.count, 500)
        XCTAssertTrue(vm.hasMore)
        let names = vm.items.map { $0.name }
        XCTAssertEqual(names, names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }
}

