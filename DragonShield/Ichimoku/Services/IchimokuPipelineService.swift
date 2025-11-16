import Foundation

struct IchimokuPipelineSummary {
    let runId: Int?
    let scanDate: Date
    let processedTickers: Int
    let candidates: [IchimokuCandidateStoreRow]
    let sellAlerts: [IchimokuSellAlertRow]
}

enum IchimokuPipelineError: Error {
    case noTickers
    case noConsensusDate
}

final class IchimokuPipelineService {
    private let dbManager: DatabaseManager
    private let settingsService: IchimokuSettingsService
    private let universeService: IchimokuUniverseService
    private let dataFetcher: IchimokuHistoricalDataFetcher
    private let indicatorCalculator: IchimokuIndicatorCalculator
    private let signalEngine: IchimokuSignalEngine
    private let logger = LoggingService.shared

    init(dbManager: DatabaseManager,
         settingsService: IchimokuSettingsService)
    {
        self.dbManager = dbManager
        self.settingsService = settingsService
        universeService = IchimokuUniverseService(dbManager: dbManager)
        dataFetcher = IchimokuHistoricalDataFetcher(dbManager: dbManager)
        indicatorCalculator = IchimokuIndicatorCalculator(regressionWindow: settingsService.state.regressionWindow)
        signalEngine = IchimokuSignalEngine(dbManager: dbManager)
    }

    func runDailyScan() async throws -> IchimokuPipelineSummary {
        universeService.ensureUniverseSeeded()
        let tickers = dbManager.ichimokuFetchTickers(activeOnly: true)
        guard !tickers.isEmpty else { throw IchimokuPipelineError.noTickers }

        let settings = settingsService.state
        let runId = dbManager.ichimokuStartRunLog()

        for ticker in tickers {
            do {
                _ = try await dataFetcher.fetchMissingHistory(for: ticker, lookbackDays: settings.historyLookbackDays)
            } catch IchimokuDataFetcherError.rateLimited {
                logger.log("[Ichimoku] Rate limited fetching \(ticker.symbol). Backing off.", type: .error, logger: .network)
                break
            } catch {
                logger.log("[Ichimoku] Failed to fetch history for \(ticker.symbol): \(error)", type: .error, logger: .network)
            }
        }

        // Recompute indicators
        for ticker in tickers {
            let bars = dbManager.ichimokuFetchPriceBars(tickerId: ticker.id, limit: settings.historyLookbackDays + 80, ascending: true)
            let indicators = indicatorCalculator.computeIndicators(for: bars)
            dbManager.ichimokuUpsertIndicators(indicators)
        }

        guard let scanDate = consensusDate(from: tickers) else {
            throw IchimokuPipelineError.noConsensusDate
        }

        let signalContext = IchimokuSignalContext(targetDate: scanDate, maxCandidates: settings.maxCandidates)
        let candidates = signalEngine.generateCandidates(for: tickers, context: signalContext)
        dbManager.ichimokuReplaceDailyCandidates(scanDate: scanDate, rows: candidates)

        let sellAlerts = evaluatePositions(scanDate: scanDate)
        let alertsInserted = sellAlerts.count
        let summary = IchimokuPipelineSummary(runId: runId,
                                              scanDate: scanDate,
                                              processedTickers: tickers.count,
                                              candidates: candidates,
                                              sellAlerts: sellAlerts)
        if let runId {
            _ = dbManager.ichimokuCompleteRunLog(runId: runId,
                                                 status: .success,
                                                 message: "Completed daily scan",
                                                 ticksProcessed: tickers.count,
                                                 candidatesFound: candidates.count,
                                                 alertsTriggered: alertsInserted,
                                                 completedAt: Date())
        }
        return summary
    }

    private func consensusDate(from tickers: [IchimokuTicker]) -> Date? {
        let formatter = DateFormatter.iso8601DateOnly
        var counts: [String: Int] = [:]
        for ticker in tickers {
            let bars = dbManager.ichimokuFetchPriceBars(tickerId: ticker.id, limit: 1, ascending: false)
            guard let bar = bars.first else { continue }
            let key = formatter.string(from: bar.date)
            counts[key, default: 0] += 1
        }
        guard let (key, _) = counts.max(by: { $0.value < $1.value }) else { return nil }
        return formatter.date(from: key)
    }

    @discardableResult
    private func evaluatePositions(scanDate: Date) -> [IchimokuSellAlertRow] {
        let candidates = dbManager.ichimokuFetchCandidates(for: scanDate)
        var generatedAlerts: [IchimokuSellAlertRow] = []
        for candidate in candidates {
            if dbManager.ichimokuFindActivePosition(tickerId: candidate.ticker.id) == nil {
                _ = dbManager.ichimokuCreatePosition(tickerId: candidate.ticker.id,
                                                     opened: scanDate,
                                                     confirmed: false)
            }
        }

        let activePositions = dbManager.ichimokuFetchPositions(includeClosed: false)
        for position in activePositions {
            let tickerId = position.ticker.id
            let bars = dbManager.ichimokuFetchPriceBars(tickerId: tickerId, limit: 200, ascending: true)
            guard let latestBar = bars.last else { continue }
            let indicators = dbManager.ichimokuFetchIndicators(tickerId: tickerId, limit: 1)
            guard let latestIndicator = indicators.first,
                  let kijun = latestIndicator.kijun else { continue }
            if latestBar.close < kijun {
                let reason = "Close below Kijun"
                if let alert = dbManager.ichimokuInsertSellAlert(tickerId: tickerId,
                                                                 alertDate: scanDate,
                                                                 closePrice: latestBar.close,
                                                                 kijunValue: kijun,
                                                                 reason: reason)
                {
                    _ = dbManager.ichimokuUpdatePositionStatus(positionId: position.id,
                                                               status: .closed,
                                                               closedDate: scanDate)
                    generatedAlerts.append(alert)
                }
            } else {
                _ = dbManager.ichimokuUpdatePositionEvaluation(positionId: position.id,
                                                               evaluatedOn: scanDate,
                                                               close: latestBar.close,
                                                               kijun: kijun)
            }
        }
        return generatedAlerts
    }
}
