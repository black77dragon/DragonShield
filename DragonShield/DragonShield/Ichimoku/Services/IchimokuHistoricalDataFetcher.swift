import Foundation

struct IchimokuFetchSummary {
    let ticker: IchimokuTicker
    let fetchedBars: Int
    let insertedBars: Int
    let updatedBars: Int
    let lastDate: Date?
}

enum IchimokuDataFetcherError: Error {
    case invalidResponse
    case rateLimited
    case network(Error)
}

final class IchimokuHistoricalDataFetcher {
    private let dbManager: DatabaseManager
    private let logger = LoggingService.shared
    private let session: URLSession

    init(dbManager: DatabaseManager, session: URLSession = .shared) {
        self.dbManager = dbManager
        self.session = session
    }

    func fetchMissingHistory(for ticker: IchimokuTicker,
                             lookbackDays: Int) async throws -> IchimokuFetchSummary {
        let latestDate = dbManager.ichimokuLatestPriceDate(for: ticker.id)
        let today = Date()
        let calendar = Calendar(identifier: .gregorian)
        var startDate: Date
        if let latestDate {
            guard let next = calendar.date(byAdding: .day, value: 1, to: latestDate) else {
                return IchimokuFetchSummary(ticker: ticker, fetchedBars: 0, insertedBars: 0, updatedBars: 0, lastDate: latestDate)
            }
            startDate = next
        } else {
            startDate = calendar.date(byAdding: .day, value: -lookbackDays, to: today) ?? today
        }
        // Align to midnight UTC
        startDate = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: today)
        if startDate >= endDate {
            return IchimokuFetchSummary(ticker: ticker, fetchedBars: 0, insertedBars: 0, updatedBars: 0, lastDate: latestDate)
        }
        // Yahoo period2 is exclusive; add one day to include current day
        guard let period2 = calendar.date(byAdding: .day, value: 1, to: endDate) else {
            return IchimokuFetchSummary(ticker: ticker, fetchedBars: 0, insertedBars: 0, updatedBars: 0, lastDate: latestDate)
        }

        let yahooSymbol = normalizedYahooSymbol(for: ticker.symbol)
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(yahooSymbol)")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "false"),
            URLQueryItem(name: "events", value: "div,splits"),
            URLQueryItem(name: "period1", value: String(Int(startDate.timeIntervalSince1970))),
            URLQueryItem(name: "period2", value: String(Int(period2.timeIntervalSince1970)))
        ]
        guard let url = components.url else { throw IchimokuDataFetcherError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        logger.log("[Ichimoku] Fetching history \(ticker.symbol) range=\(DateFormatter.iso8601DateOnly.string(from: startDate))...\(DateFormatter.iso8601DateOnly.string(from: endDate))", logger: .network)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw IchimokuDataFetcherError.invalidResponse
            }
            guard http.statusCode == 200 else {
                if http.statusCode == 429 { throw IchimokuDataFetcherError.rateLimited }
                throw IchimokuDataFetcherError.invalidResponse
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [Any],
                  let first = results.first as? [String: Any],
                  let timestamps = first["timestamp"] as? [Double],
                  let indicators = first["indicators"] as? [String: Any],
                  let quotes = indicators["quote"] as? [Any],
                  let quote = quotes.first as? [String: Any],
                  let opens = quote["open"] as? [Double?],
                  let highs = quote["high"] as? [Double?],
                  let lows = quote["low"] as? [Double?],
                  let closes = quote["close"] as? [Double?],
                  let volumes = quote["volume"] as? [Double?]
            else {
                throw IchimokuDataFetcherError.invalidResponse
            }

            var bars: [IchimokuPriceBar] = []
            let count = timestamps.count
            for i in 0..<count {
                let ts = timestamps[i]
                let open = i < opens.count ? opens[i] : nil
                let high = i < highs.count ? highs[i] : nil
                let low = i < lows.count ? lows[i] : nil
                let close = i < closes.count ? closes[i] : nil
                let volume = i < volumes.count ? volumes[i] : nil
                guard let o = open, let h = high, let l = low, let c = close, o > 0, h > 0, l > 0, c > 0 else { continue }
                let date = Date(timeIntervalSince1970: ts)
                bars.append(IchimokuPriceBar(
                    tickerId: ticker.id,
                    date: date,
                    open: o,
                    high: h,
                    low: l,
                    close: c,
                    volume: volume,
                    source: "yahoo"
                ))
            }
            guard !bars.isEmpty else {
                return IchimokuFetchSummary(ticker: ticker, fetchedBars: 0, insertedBars: 0, updatedBars: 0, lastDate: latestDate)
            }
            let (inserted, updated) = dbManager.ichimokuInsertPriceBars(bars)
            return IchimokuFetchSummary(ticker: ticker,
                                        fetchedBars: bars.count,
                                        insertedBars: inserted,
                                        updatedBars: updated,
                                        lastDate: bars.last?.date ?? latestDate)
        } catch let error as IchimokuDataFetcherError {
            throw error
        } catch {
            throw IchimokuDataFetcherError.network(error)
        }
    }

    private func normalizedYahooSymbol(for symbol: String) -> String {
        // Yahoo uses hyphen instead of dot for class shares (e.g., BRK.B -> BRK-B)
        var normalized = symbol.uppercased()
        normalized = normalized.replacingOccurrences(of: ".", with: "-")
        // Handle forward slashes (if any) by replacing with hyphen
        normalized = normalized.replacingOccurrences(of: "/", with: "-")
        return normalized
    }
}
