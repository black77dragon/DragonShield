import Foundation

struct IchimokuSignalContext {
    let targetDate: Date
    let maxCandidates: Int
}

final class IchimokuSignalEngine {
    private let dbManager: DatabaseManager
    private let logger = LoggingService.shared

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func generateCandidates(for tickers: [IchimokuTicker],
                            context: IchimokuSignalContext) -> [IchimokuCandidateStoreRow] {
        let dateStr = DateFormatter.iso8601DateOnly.string(from: context.targetDate)
        logger.log("[Ichimoku] Evaluating candidates for \(dateStr)...", logger: .general)
        var scored: [CandidateScore] = []
        for ticker in tickers where ticker.isActive {
            autoreleasepool {
                let bars = dbManager.ichimokuFetchPriceBars(tickerId: ticker.id, limit: 340, ascending: true)
                if let result = evaluateTicker(ticker, bars: bars, targetDate: context.targetDate) {
                    scored.append(result)
                }
            }
        }
        scored.sort { lhs, rhs in
            if lhs.momentum != rhs.momentum { return lhs.momentum > rhs.momentum }
            if lhs.priceDistance != rhs.priceDistance { return lhs.priceDistance > rhs.priceDistance }
            return lhs.tkDistance > rhs.tkDistance
        }
        let limited = scored.prefix(context.maxCandidates).enumerated().map { index, element -> IchimokuCandidateStoreRow in
            let row = element.storeRow
            return IchimokuCandidateStoreRow(scanDate: row.scanDate,
                                            tickerId: row.tickerId,
                                            rank: index + 1,
                                            momentumScore: row.momentumScore,
                                            closePrice: row.closePrice,
                                            tenkan: row.tenkan,
                                            kijun: row.kijun,
                                            tenkanSlope: row.tenkanSlope,
                                            kijunSlope: row.kijunSlope,
                                            priceToKijunRatio: row.priceToKijunRatio,
                                            tenkanKijunDistance: row.tenkanKijunDistance,
                                            notes: row.notes)
        }
        return Array(limited)
    }

    private struct CandidateScore {
        let storeRow: IchimokuCandidateStoreRow
        let momentum: Double
        let priceDistance: Double
        let tkDistance: Double
    }

    private func evaluateTicker(_ ticker: IchimokuTicker,
                                 bars: [IchimokuPriceBar],
                                 targetDate: Date) -> CandidateScore? {
        guard bars.count >= 90 else { return nil }
        let dateFormatter = DateFormatter.iso8601DateOnly
        let targetKey = dateFormatter.string(from: targetDate)
        guard let index = bars.firstIndex(where: { dateFormatter.string(from: $0.date) == targetKey }) else {
            return nil
        }
        let indicatorRows = dbManager.ichimokuFetchIndicators(tickerId: ticker.id, limit: 380)
        let indicatorMap: [String: IchimokuIndicatorRow] = Dictionary(uniqueKeysWithValues: indicatorRows.map { (dateFormatter.string(from: $0.date), $0) })
        guard let indicator = indicatorMap[targetKey] else { return nil }
        guard let tenkan = indicator.tenkan, let kijun = indicator.kijun, tenkan > kijun else { return nil }
        let price = bars[index].close
        let cloudTop = max(indicator.senkouA ?? -Double.greatestFiniteMagnitude,
                           indicator.senkouB ?? -Double.greatestFiniteMagnitude)
        if price <= cloudTop { return nil }
        guard index >= 26 else { return nil }
        let pastPrice = bars[index - 26].close
        if price <= pastPrice { return nil }

        let tenkanSlope = indicator.tenkanSlope ?? 0
        let kijunSlope = indicator.kijunSlope ?? 0
        let slopeScore = tenkanSlope * 0.6 + kijunSlope * 0.4
        let priceDistance = (indicator.priceToKijunRatio ?? price / (kijun == 0 ? price : kijun)) - 1.0
        let tkDistanceRaw = indicator.tenkanKijunDistance ?? (tenkan - kijun)
        let normalizedTK = (kijun != 0) ? tkDistanceRaw / kijun : tkDistanceRaw
        let momentumScore = slopeScore + 0.1 * priceDistance + 0.05 * normalizedTK

        let storeRow = IchimokuCandidateStoreRow(
            scanDate: targetDate,
            tickerId: ticker.id,
            rank: 0,
            momentumScore: momentumScore,
            closePrice: price,
            tenkan: tenkan,
            kijun: kijun,
            tenkanSlope: indicator.tenkanSlope,
            kijunSlope: indicator.kijunSlope,
            priceToKijunRatio: indicator.priceToKijunRatio,
            tenkanKijunDistance: indicator.tenkanKijunDistance,
            notes: nil
        )
        return CandidateScore(storeRow: storeRow,
                              momentum: momentumScore,
                              priceDistance: priceDistance,
                              tkDistance: normalizedTK)
    }
}
