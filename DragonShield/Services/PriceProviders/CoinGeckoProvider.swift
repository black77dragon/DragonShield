import Foundation
import OSLog

final class CoinGeckoProvider: PriceProvider {
    let code = "coingecko"
    let displayName = "CoinGecko"
    private static var preferFreeHost = false

    func fetchLatest(externalId: String, expectedCurrency: String?) async throws -> PriceQuote {
        let currency = (expectedCurrency ?? "USD").lowercased()
        let log = LoggingService.shared
        // Resolve API key and choose endpoint (allow forcing free host to avoid Keychain access)
        let preferFreeUser = UserDefaults.standard.bool(forKey: "coingeckoPreferFree")
        let apiKey: String? = {
            if preferFreeUser { return nil }
            if let key = KeychainService.get(account: "coingecko"), !key.isEmpty { return key }
            if let env = ProcessInfo.processInfo.environment["COINGECKO_API_KEY"], !env.isEmpty { return env }
            return nil
        }()
        let usingPro = (apiKey != nil) && !Self.preferFreeHost
        var comps = URLComponents(string: (usingPro ? "https://pro-api.coingecko.com" : "https://api.coingecko.com") + "/api/v3/simple/price")!
        comps.queryItems = [
            URLQueryItem(name: "ids", value: externalId.lowercased()),
            URLQueryItem(name: "vs_currencies", value: currency),
            URLQueryItem(name: "include_last_updated_at", value: "true")
        ]
        guard let url = comps.url else {
            log.log("[CoinGecko] Failed to build URL", type: .error, logger: .network)
            throw PriceProviderError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("DragonShield/1.0", forHTTPHeaderField: "User-Agent")
        if usingPro, let key = apiKey { req.addValue(key, forHTTPHeaderField: "x-cg-pro-api-key") }
        log.log("[CoinGecko] GET \(url.path)?\(url.query ?? "") host=\(url.host ?? "-") pro=\(usingPro) keyPresent=\(apiKey != nil)", logger: .network)

        func logBody(_ data: Data) {
            if data.isEmpty { return }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = obj["error"] ?? obj["message"] ?? obj["status"] ?? obj
                log.log("[CoinGecko] Body: \(msg)", type: .info, logger: .network)
            } else if let s = String(data: data, encoding: .utf8) {
                let snippet = s.count > 600 ? String(s.prefix(600)) + "…" : s
                log.log("[CoinGecko] Body: \(snippet)", type: .info, logger: .network)
            }
        }

        func isDemoKeyHint(_ data: Data) -> Bool {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let fields = ["error", "message", "error_message", "status"]
                for k in fields {
                    if let v = obj[k] as? String, v.lowercased().contains("demo api key") {
                        return true
                    }
                }
            }
            if let s = String(data: data, encoding: .utf8)?.lowercased() {
                if s.contains("demo api key") || (s.contains("pro-api.coingecko.com") && s.contains("api.coingecko.com")) {
                    return true
                }
            }
            return false
        }

        func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            do {
                let (d, r) = try await URLSession.shared.data(for: request)
                guard let http = r as? HTTPURLResponse else {
                    log.log("[CoinGecko] Invalid response object", type: .error, logger: .network)
                    throw PriceProviderError.invalidResponse
                }
                return (d, http)
            } catch {
                log.log("[CoinGecko] Network error: \(error.localizedDescription)", type: .error, logger: .network)
                throw PriceProviderError.network(error)
            }
        }

        var (data, http) = try await perform(req)
        var rateRemain = http.allHeaderFields["X-RateLimit-Remaining"] ?? http.allHeaderFields["x-ratelimit-remaining"] ?? "-"
        var rateReset = http.allHeaderFields["X-RateLimit-Reset"] ?? http.allHeaderFields["x-ratelimit-reset"] ?? "-"
        log.log("[CoinGecko] Response status=\(http.statusCode) bytes=\(data.count) rateRemaining=\(rateRemain) rateReset=\(rateReset)", logger: .network)
        if http.statusCode != 200 {
            logBody(data)
            // Fallback to free endpoint if Pro returns 4xx (except 401/429)
            if usingPro, (400...499).contains(http.statusCode), http.statusCode != 401, http.statusCode != 429 {
                // Detect demo key hint → pin to free for the session
                if isDemoKeyHint(data) { Self.preferFreeHost = true }
                var freeComps = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
                freeComps.queryItems = comps.queryItems
                if let freeUrl = freeComps.url {
                    var freeReq = URLRequest(url: freeUrl)
                    freeReq.httpMethod = "GET"
                    freeReq.timeoutInterval = 20
                    freeReq.cachePolicy = .reloadIgnoringLocalCacheData
                    freeReq.setValue("application/json", forHTTPHeaderField: "Accept")
                    freeReq.setValue("DragonShield/1.0", forHTTPHeaderField: "User-Agent")
                    log.log("[CoinGecko] Falling back → GET \(freeUrl.path)?\(freeUrl.query ?? "") host=\(freeUrl.host ?? "-") pro=false", logger: .network)
                    (data, http) = try await perform(freeReq)
                    rateRemain = http.allHeaderFields["X-RateLimit-Remaining"] ?? http.allHeaderFields["x-ratelimit-remaining"] ?? "-"
                    rateReset = http.allHeaderFields["X-RateLimit-Reset"] ?? http.allHeaderFields["x-ratelimit-reset"] ?? "-"
                    log.log("[CoinGecko] Fallback response status=\(http.statusCode) bytes=\(data.count) rateRemaining=\(rateRemain) rateReset=\(rateReset)", logger: .network)
                    if http.statusCode != 200 {
                        logBody(data)
                    }
                }
            }
        }
        guard http.statusCode == 200 else {
            let code = http.statusCode
            if code == 401 { log.log("[CoinGecko] 401 unauthorized", type: .error, logger: .network); throw PriceProviderError.unauthorized }
            if code == 429 { log.log("[CoinGecko] 429 rate limited", type: .error, logger: .network); throw PriceProviderError.rateLimited }
            log.log("[CoinGecko] HTTP error status=\(code)", type: .error, logger: .network)
            throw PriceProviderError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = json[externalId.lowercased()] as? [String: Any] else {
            log.log("[CoinGecko] Missing id key in JSON for id=\(externalId.lowercased())", type: .error, logger: .network)
            throw PriceProviderError.notFound
        }
        // Price may decode as NSNumber; convert safely to Double
        let priceValue: Double
        if let n = obj[currency] as? NSNumber {
            priceValue = n.doubleValue
        } else if let d = obj[currency] as? Double {
            priceValue = d
        } else if let s = obj[currency] as? String, let d = Double(s) {
            priceValue = d
        } else {
            log.log("[CoinGecko] Price for currency=\(currency) not found or invalid in payload: keys=\(Array(obj.keys))", type: .error, logger: .network)
            throw PriceProviderError.invalidResponse
        }
        // last_updated_at is a UNIX seconds value
        let ts: Date
        if let n = obj["last_updated_at"] as? NSNumber {
            ts = Date(timeIntervalSince1970: n.doubleValue)
        } else if let d = obj["last_updated_at"] as? Double {
            ts = Date(timeIntervalSince1970: d)
        } else {
            ts = Date()
        }
        let curr = expectedCurrency?.uppercased() ?? currency.uppercased()
        log.log("[CoinGecko] OK id=\(externalId) price=\(priceValue) curr=\(curr) asOf=\(ts)", type: .debug, logger: .network)
        return PriceQuote(price: priceValue, currency: curr, asOf: ts, source: code)
    }
}
