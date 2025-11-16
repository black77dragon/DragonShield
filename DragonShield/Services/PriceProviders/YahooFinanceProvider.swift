import Foundation
import OSLog

final class YahooFinanceProvider: PriceProvider {
    let code = "yahoo"
    let displayName = "Yahoo Finance"

    // externalId: Yahoo symbol (e.g., "NESN.SW", "SIE.DE", "AAPL")
    func fetchLatest(externalId: String, expectedCurrency: String?) async throws -> PriceQuote {
        let symbol = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = LoggingService.shared

        var comps = URLComponents(string: "https://query1.finance.yahoo.com/v7/finance/quote")!
        comps.queryItems = [
            URLQueryItem(name: "symbols", value: symbol),
            URLQueryItem(name: "region", value: "CH"),
            URLQueryItem(name: "lang", value: "en-US"),
        ]
        guard let url = comps.url else { throw PriceProviderError.invalidResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("DragonShield/1.0", forHTTPHeaderField: "User-Agent")

        log.log("[Yahoo] GET \(url.path)?\(url.query ?? "") host=\(url.host ?? "-") symbol=\(symbol)", logger: .network)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            log.log("[Yahoo] Network error: \(error.localizedDescription)", type: .error, logger: .network)
            throw PriceProviderError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            log.log("[Yahoo] Invalid response object", type: .error, logger: .network)
            throw PriceProviderError.invalidResponse
        }
        log.log("[Yahoo] Response status=\(http.statusCode) bytes=\(data.count)", logger: .network)
        if http.statusCode != 200 {
            if let s = String(data: data, encoding: .utf8) { log.log("[Yahoo] Body: \(s)", type: .info, logger: .network) }
            // Fallback: try chart endpoint, which is often accessible when quote API is blocked
            if let fallback = try? await fetchFromChart(symbol: symbol) {
                return fallback
            }
            if http.statusCode == 401 { throw PriceProviderError.unauthorized }
            if http.statusCode == 429 { throw PriceProviderError.rateLimited }
            throw PriceProviderError.invalidResponse
        }

        // Parse primary quote
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let qr = root["quoteResponse"] as? [String: Any],
              let arr = qr["result"] as? [Any]
        else {
            log.log("[Yahoo] No quoteResponse for symbol=\(symbol)", type: .error, logger: .network)
            throw PriceProviderError.invalidResponse
        }
        let first = arr.first as? [String: Any]

        var price: Double? = {
            if let n = first?["regularMarketPrice"] as? NSNumber { return n.doubleValue }
            if let d = first?["regularMarketPrice"] as? Double { return d }
            return nil
        }()
        let rawCurrency: String? = (first?["currency"] as? String)
        var currStr: String? = rawCurrency?.uppercased()
        var tsSec: Double? = {
            if let n = first?["regularMarketTime"] as? NSNumber { return n.doubleValue }
            if let d = first?["regularMarketTime"] as? Double { return d }
            return nil
        }()

        // Fallback to chart API if missing
        if price == nil || price == 0 {
            var c = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
            c.queryItems = [
                URLQueryItem(name: "range", value: "5d"),
                URLQueryItem(name: "interval", value: "1d"),
                URLQueryItem(name: "region", value: "CH"),
                URLQueryItem(name: "lang", value: "en-US"),
            ]
            if let curl = c.url {
                var creq = URLRequest(url: curl)
                creq.httpMethod = "GET"
                creq.timeoutInterval = 20
                creq.cachePolicy = .reloadIgnoringLocalCacheData
                creq.setValue("application/json", forHTTPHeaderField: "Accept")
                creq.setValue("DragonShield/1.0", forHTTPHeaderField: "User-Agent")
                do {
                    let (cd, cr) = try await URLSession.shared.data(for: creq)
                    if let http2 = cr as? HTTPURLResponse, http2.statusCode == 200,
                       let chartRoot = try JSONSerialization.jsonObject(with: cd) as? [String: Any],
                       let chart = chartRoot["chart"] as? [String: Any],
                       let resArr = chart["result"] as? [Any],
                       let res0 = resArr.first as? [String: Any],
                       let meta = res0["meta"] as? [String: Any]
                    {
                        if price == nil {
                            if let n = meta["regularMarketPrice"] as? NSNumber { price = n.doubleValue }
                            else if let d = meta["regularMarketPrice"] as? Double { price = d }
                            else if let prev = meta["regularMarketPreviousClose"] as? Double { price = prev }
                        }
                        if currStr == nil, let ccy = meta["currency"] as? String { currStr = ccy.uppercased() }
                        if tsSec == nil, let t = meta["regularMarketTime"] as? Double { tsSec = t }
                    }
                } catch {
                    log.log("[Yahoo] Chart fetch error: \(error.localizedDescription)", type: .error, logger: .network)
                }
            }
        }

        guard let finalPrice = price, finalPrice > 0 else {
            log.log("[Yahoo] Unable to obtain price for symbol=\(symbol)", type: .error, logger: .network)
            throw PriceProviderError.notFound
        }
        let asOf = Date(timeIntervalSince1970: tsSec ?? Date().timeIntervalSince1970)
        // Normalize special Yahoo quirk: GBp/GBX (pence) -> GBP with 1/100 scaling
        let norm = normalizeCurrencyAndScale(rawCurrency ?? currStr)
        let adjustedPrice = finalPrice * norm.scale
        let currency = (norm.normalized.isEmpty ? (expectedCurrency ?? "") : norm.normalized).uppercased()
        log.log("[Yahoo] OK symbol=\(symbol) price=\(finalPrice) adj=\(adjustedPrice) curr_raw=\(rawCurrency ?? "-") curr=\(currency) scale=\(norm.scale) asOf=\(asOf)", type: .debug, logger: .network)
        return PriceQuote(price: adjustedPrice, currency: currency, asOf: asOf, source: code)
    }

    // Try chart API as a fallback when quote API is blocked or missing values
    private func fetchFromChart(symbol: String) async throws -> PriceQuote {
        let log = LoggingService.shared
        var c = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
        c.queryItems = [
            URLQueryItem(name: "range", value: "5d"),
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "region", value: "CH"),
            URLQueryItem(name: "lang", value: "en-US"),
        ]
        guard let curl = c.url else { throw PriceProviderError.invalidResponse }
        var creq = URLRequest(url: curl)
        creq.httpMethod = "GET"
        creq.timeoutInterval = 20
        creq.cachePolicy = .reloadIgnoringLocalCacheData
        creq.setValue("application/json", forHTTPHeaderField: "Accept")
        creq.setValue("DragonShield/1.0", forHTTPHeaderField: "User-Agent")
        let (cd, cr) = try await URLSession.shared.data(for: creq)
        guard let http2 = cr as? HTTPURLResponse else { throw PriceProviderError.invalidResponse }
        log.log("[Yahoo] Chart status=\(http2.statusCode) bytes=\(cd.count)", logger: .network)
        guard http2.statusCode == 200,
              let chartRoot = try JSONSerialization.jsonObject(with: cd) as? [String: Any],
              let chart = chartRoot["chart"] as? [String: Any],
              let resArr = chart["result"] as? [Any],
              let res0 = resArr.first as? [String: Any],
              let meta = res0["meta"] as? [String: Any]
        else {
            throw PriceProviderError.invalidResponse
        }
        var price: Double?
        if let n = meta["regularMarketPrice"] as? NSNumber { price = n.doubleValue }
        else if let d = meta["regularMarketPrice"] as? Double { price = d }
        else if let prev = meta["regularMarketPreviousClose"] as? Double { price = prev }
        let rawCurrency = (meta["currency"] as? String)
        let norm = normalizeCurrencyAndScale(rawCurrency)
        let ts = (meta["regularMarketTime"] as? Double) ?? Date().timeIntervalSince1970
        guard let p = price, p > 0 else { throw PriceProviderError.notFound }
        let adj = p * norm.scale
        let quote = PriceQuote(price: adj, currency: norm.normalized, asOf: Date(timeIntervalSince1970: ts), source: code)
        log.log("[Yahoo] Chart OK symbol=\(symbol) price=\(p) adj=\(adj) curr_raw=\(rawCurrency ?? "-") curr=\(norm.normalized) scale=\(norm.scale) asOf=\(quote.asOf)", type: .debug, logger: .network)
        return quote
    }

    // Normalize Yahoo currency quirks (e.g., GBp/GBX) and provide a multiplier to scale price to major unit.
    private func normalizeCurrencyAndScale(_ raw: String?) -> (normalized: String, scale: Double) {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return ("", 1.0)
        }
        // Yahoo sometimes returns GBp (pence) or GBX; both are 1/100 of GBP
        if raw == "GBp" || raw.uppercased() == "GBX" {
            return ("GBP", 0.01)
        }
        return (raw.uppercased(), 1.0)
    }
}
