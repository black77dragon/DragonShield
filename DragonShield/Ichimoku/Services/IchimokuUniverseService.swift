import Foundation

struct IchimokuBundledTicker: Decodable {
    let symbol: String
    let name: String
}

final class IchimokuUniverseService {
    private let dbManager: DatabaseManager
    private let logger = LoggingService.shared

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func ensureUniverseSeeded() {
        let existing = dbManager.ichimokuFetchTickers(activeOnly: false)
        guard existing.isEmpty else { return }
        logger.log("[Ichimoku] Seeding ticker universe from bundled resources...", logger: .database)
        let totalInserted = IchimokuIndexSource.allCases.reduce(into: 0) { partial, source in
            partial += seedTickers(for: source)
        }
        logger.log("[Ichimoku] Seeded \(totalInserted) tickers", logger: .database)
        _ = dbManager.upsertConfiguration(key: "ichimoku.universe.seeded_at",
                                          value: DateFormatter.iso8601DateTime.string(from: Date()),
                                          dataType: "string",
                                          description: "Timestamp when the Ichimoku Dragon universe was last seeded from bundled resources.")
    }

    func seedTickers(for source: IchimokuIndexSource) -> Int {
        guard let tickers = loadBundledTickers(for: source) else { return 0 }
        var inserted = 0
        for item in tickers {
            if let ticker = dbManager.ichimokuUpsertTicker(symbol: item.symbol,
                                                           name: item.name,
                                                           indexSource: source,
                                                           isActive: true,
                                                           notes: nil)
            {
                inserted += 1
                logger.log("[Ichimoku] Seeded ticker \(ticker.symbol) (\(source.displayName))", type: .debug, logger: .database)
            }
        }
        return inserted
    }

    private func loadBundledTickers(for source: IchimokuIndexSource) -> [IchimokuBundledTicker]? {
        let resourceName: String
        switch source {
        case .sp500: resourceName = "sp500_tickers"
        case .nasdaq100: resourceName = "nasdaq100_tickers"
        }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            logger.log("[Ichimoku] Missing bundled ticker list \(resourceName).json", type: .error, logger: .database)
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let tickers = try decoder.decode([IchimokuBundledTicker].self, from: data)
            return tickers
        } catch {
            logger.log("[Ichimoku] Failed to decode \(resourceName).json: \(error)", type: .error, logger: .database)
            return nil
        }
    }
}
