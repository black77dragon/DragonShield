import SwiftUI

enum InstrumentSortKey: String, CaseIterable {
    case name, type, currency
}

class InstrumentFilterViewModel: ObservableObject {
    @Published var selectedTypes: Set<String> = []
    @Published var selectedCurrencies: Set<String> = []
    @Published var sortKey: InstrumentSortKey = .name
    @Published var ascending: Bool = true

    func toggleType(_ type: String) {
        if selectedTypes.contains(type) { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
    }

    func toggleCurrency(_ cur: String) {
        if selectedCurrencies.contains(cur) { selectedCurrencies.remove(cur) } else { selectedCurrencies.insert(cur) }
    }

    var hasFilters: Bool { !selectedTypes.isEmpty || !selectedCurrencies.isEmpty }
}
