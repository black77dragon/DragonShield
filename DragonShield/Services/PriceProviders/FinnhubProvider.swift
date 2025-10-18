import Foundation
import OSLog

final class FinnhubProvider: PriceProvider {
    let code = "finnhub"
    let displayName = "Finnhub"

    func fetchLatest(externalId: String, expectedCurrency: String?) async throws -> PriceQuote {
        // Finnhub quote endpoint returns: { c: current, t: epoch seconds }
        // Currency is not included; use expectedCurrency if provided, else default to USD
        let currency = (expectedCurrency ?? "USD").uppercased()
        let log = LoggingService.shared

        // Resolve token from UserDefaults, Keychain, or env (FINNHUB_API_KEY); sent as query token
        let token: String? = {
            if let v = UserDefaults.standard.string(forKey: "api_key.finnhub"), !v.isEmpty { return v }
            if let v = KeychainService.get(account: "finnhub"), !v.isEmpty { return v }
            if let v = ProcessInfo.processInfo.environment["FINNHUB_API_KEY"], !v.isEmpty { return v }
            return nil
        }()

        // Normalize US symbols: FINNHUB expects plain ticker for US (e.g., "BE" not "BE.US")
        let normalizedSymbol: String = {
            let s = externalId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if s.hasSuffix(".US") { return String(s.dropLast(3)) }
            return s
        }()

        var comps = URLComponents(string: "https://finnhub.io/api/v1/quote")!
        comps.queryItems = [
            URLQueryItem(name: "symbol", value: normalizedSymbol),
        ]
        if let token { comps.queryItems?.append(URLQueryItem(name: "token", value: token)) }
        guard let url = comps.url else { throw PriceProviderError.invalidResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("DragonShield/1.0", forHTTPHeaderField: "User-Agent")

        log.log("[Finnhub] GET \(url.path)?\(url.query ?? "") host=\(url.host ?? "-") token=\(token != nil)", logger: .network)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                log.log("[Finnhub] Invalid response object", type: .error, logger: .network)
                throw PriceProviderError.invalidResponse
            }
            log.log("[Finnhub] Response status=\(http.statusCode) bytes=\(data.count)", logger: .network)
            guard http.statusCode == 200 else {
                if http.statusCode == 401 { throw PriceProviderError.unauthorized }
                if http.statusCode == 429 { throw PriceProviderError.rateLimited }
                if let s = String(data: data, encoding: .utf8) { log.log("[Finnhub] Body: \(s)", type: .info, logger: .network) }
                throw PriceProviderError.invalidResponse
            }

            // Parse JSON: { "c": Double, "t": Int }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PriceProviderError.invalidResponse
            }
            let price: Double
            if let n = obj["c"] as? NSNumber { price = n.doubleValue }
            else if let d = obj["c"] as? Double { price = d }
            else { throw PriceProviderError.invalidResponse }

            let tsSec: Double
            if let n = obj["t"] as? NSNumber { tsSec = n.doubleValue }
            else if let d = obj["t"] as? Double { tsSec = d }
            else { tsSec = 0 }

            // Finnhub returns 0 for c/t when symbol is unknown or there is no current data
            if price <= 0 || tsSec <= 0 {
                log.log("[Finnhub] No data for symbol=\(normalizedSymbol) (price=\(price), t=\(tsSec)). Check symbol or market hours.", type: .error, logger: .network)
                throw PriceProviderError.notFound
            }
            let asOf = Date(timeIntervalSince1970: tsSec)

            log.log("[Finnhub] OK symbol=\(normalizedSymbol) price=\(price) curr=\(currency) asOf=\(asOf)", type: .debug, logger: .network)
            return PriceQuote(price: price, currency: currency, asOf: asOf, source: code)
        } catch {
            if let err = error as? PriceProviderError { throw err }
            throw PriceProviderError.network(error)
        }
    }
}
