import SwiftUI

class PositionsViewModel: ObservableObject {
  @Published var totalAssetValueCHF: Double = 0
  @Published var positionValueOriginal: [Int: Double] = [:]
  @Published var positionValueCHF: [Int: Double?] = [:]
  @Published var currencySymbols: [String: String] = [:]
  @Published var calculating: Bool = false
  @Published var showErrorToast: Bool = false
  /// All positions sorted by value in CHF descending.
  @Published var topPositions: [TopPosition] = []

  struct TopPosition: Identifiable {
    let id: Int
    let instrument: String
    let valueCHF: Double
    let currency: String
  }

  /// Returns positions filtered by search text, institutions and currency filters.
  /// - Parameters:
  ///   - positions: The original list of positions.
  ///   - searchText: Case-insensitive text to match across all fields.
  ///   - selectedInstitutionNames: Institutions to include, empty for all.
  ///   - currencyFilters: Instrument currencies to include, empty for all.
  func filterPositions(
    _ positions: [PositionReportData],
    searchText: String,
    selectedInstitutionNames: [String],
    currencyFilters: Set<String>
  ) -> [PositionReportData] {
    var result = positions
    if !searchText.isEmpty {
      let lowered = searchText.lowercased()
      result = result.filter { pos in
        let fields: [String] = [
          pos.accountName,
          pos.institutionName,
          pos.instrumentName,
          pos.instrumentCurrency,
          pos.instrumentCountry ?? "",
          pos.instrumentSector ?? "",
          pos.assetClass ?? "",
          pos.assetSubClass ?? "",
          String(pos.quantity),
          pos.purchasePrice.map { String($0) } ?? "",
          pos.currentPrice.map { String($0) } ?? "",
          pos.notes ?? "",
          DateFormatter.iso8601DateOnly.string(from: pos.reportDate),
          DateFormatter.iso8601DateTime.string(from: pos.uploadedAt),
          String(pos.id),
          pos.importSessionId.map { String($0) } ?? "",
        ]
        return fields.contains { $0.localizedCaseInsensitiveContains(lowered) }
      }
    }
    if !selectedInstitutionNames.isEmpty {
      result = result.filter { selectedInstitutionNames.contains($0.institutionName) }
    }
    if !currencyFilters.isEmpty {
      result = result.filter { currencyFilters.contains($0.instrumentCurrency) }
    }
    return result
  }

  func calculateValues(positions: [PositionReportData], db: DatabaseManager) {
    calculating = true
    DispatchQueue.global().async {
      var total: Double = 0
      var orig: [Int: Double] = [:]
      var chf: [Int: Double?] = [:]
      var rateCache: [String: Double?] = [:]
      var symbolCache: [String: String] = [:]
      var missingRate = false

      let fxService = FXConversionService(dbManager: db)
      let positionsAsOf = positions.map { $0.reportDate }.max() ?? Date()
      for p in positions {
        guard let price = p.currentPrice else { continue }
        let key = p.id
        let currency = p.instrumentCurrency.uppercased()
        let valueOrig = p.quantity * price
        orig[key] = valueOrig

        if let sym = symbolCache[currency] {
          symbolCache[currency] = sym
        } else if let details = db.fetchCurrencyDetails(code: currency) {
          symbolCache[currency] = details.symbol
        } else {
          symbolCache[currency] = currency
        }

        var valueCHF = valueOrig
        if currency != "CHF" {
          if let cached = rateCache[currency] {
            if let r = cached {
              valueCHF *= r
              chf[key] = valueCHF
              total += valueCHF
            } else {
              missingRate = true
              chf[key] = nil
            }
          } else {
            if let result = fxService.convert(amount: 1.0, from: currency, to: "CHF", asOf: positionsAsOf) {
              rateCache[currency] = result.rate
              valueCHF *= result.rate
              chf[key] = valueCHF
              total += valueCHF
            } else {
              rateCache[currency] = nil
              missingRate = true
              chf[key] = nil
            }
          }
        } else {
          chf[key] = valueCHF
          total += valueCHF
        }
      }

      DispatchQueue.main.async {
        self.positionValueOriginal = orig
        self.positionValueCHF = chf
        self.currencySymbols = symbolCache
        self.totalAssetValueCHF = total
        self.topPositions = orig.keys.compactMap { id in
          if let value = chf[id], let v = value {
            let name = positions.first { $0.id == id }?.instrumentName ?? ""
            let currency = positions.first { $0.id == id }?.instrumentCurrency.uppercased() ?? "CHF"
            return TopPosition(id: id, instrument: name, valueCHF: v, currency: currency)
          }
          return nil
        }
        .sorted { $0.valueCHF > $1.valueCHF }
        self.calculating = false
        self.showErrorToast = missingRate
      }
    }
  }

  func calculateTopPositions(db: DatabaseManager) {
    let positions = db.fetchPositionReports()
    calculateValues(positions: positions, db: db)
  }
}
