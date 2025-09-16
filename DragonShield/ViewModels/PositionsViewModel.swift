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

  private var individualTopPositions: [TopPosition] = []
  private var consolidatedTopPositions: [TopPosition] = []
  private var showsConsolidatedTopPositions = true

  struct TopPosition: Identifiable {
    let id: String
    let instrument: String
    let valueCHF: Double
    let currency: String
  }

  private struct InstrumentGroupingKey: Hashable {
    let instrumentId: Int?
    let instrumentName: String
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
      var rateCache: [String: Double] = [:]
      var symbolCache: [String: String] = [:]
      var missingRate = false

      for p in positions {
        // Get latest price from centralized InstrumentPrice
        var price: Double?
        if let instrId = p.instrumentId, let lp = db.getLatestPrice(instrumentId: instrId) {
          price = lp.price
        }
        guard let price = price else { continue }
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
          var rate = rateCache[currency]
          if rate == nil {
            let rates = db.fetchExchangeRates(currencyCode: currency, upTo: nil)
            if let r = rates.first?.rateToChf {
              rateCache[currency] = r
              rate = r
            }
          }
          if let r = rate {
            valueCHF *= r
            chf[key] = valueCHF
            total += valueCHF
          } else {
            missingRate = true
            chf[key] = nil
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

        let individual: [TopPosition] = positions.compactMap { position in
          if let value = chf[position.id], let unwrapped = value {
            let currency = position.instrumentCurrency.uppercased()
            return TopPosition(
              id: "position-\(position.id)",
              instrument: position.instrumentName,
              valueCHF: unwrapped,
              currency: currency
            )
          }
          return nil
        }
        .sorted { $0.valueCHF > $1.valueCHF }

        let grouped = Dictionary(grouping: positions) { position in
          InstrumentGroupingKey(
            instrumentId: position.instrumentId,
            instrumentName: position.instrumentName,
            currency: position.instrumentCurrency.uppercased()
          )
        }

        var consolidated: [TopPosition] = []
        for (key, group) in grouped {
          var sumCHF: Double = 0
          var hasValue = false
          for position in group {
            if let value = chf[position.id], let unwrapped = value {
              sumCHF += unwrapped
              hasValue = true
            }
          }
          guard hasValue else { continue }

          let id: String
          if let instrumentId = key.instrumentId {
            id = "instrument-\(instrumentId)"
          } else {
            id = "instrument-\(key.instrumentName.lowercased())-\(key.currency)"
          }

          consolidated.append(
            TopPosition(
              id: id,
              instrument: key.instrumentName,
              valueCHF: sumCHF,
              currency: key.currency
            )
          )
        }
        consolidated.sort { $0.valueCHF > $1.valueCHF }

        self.individualTopPositions = individual
        self.consolidatedTopPositions = consolidated
        self.setConsolidation(enabled: self.showsConsolidatedTopPositions)
        self.calculating = false
        self.showErrorToast = missingRate
      }
    }
  }

  func setConsolidation(enabled: Bool) {
    showsConsolidatedTopPositions = enabled
    topPositions = enabled ? consolidatedTopPositions : individualTopPositions
  }

  func calculateTopPositions(db: DatabaseManager, consolidated: Bool) {
    showsConsolidatedTopPositions = consolidated
    let positions = db.fetchPositionReports()
    calculateValues(positions: positions, db: db)
  }
}
