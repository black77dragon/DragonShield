import Foundation

final class CoinGeckoProvider: PriceProvider {
    let code = "coingecko"
    let displayName = "CoinGecko"

    func fetchLatest(externalId: String, expectedCurrency: String?) async throws -> PriceQuote {
        let currency = (expectedCurrency ?? "USD").lowercased()
        var comps = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        comps.queryItems = [
            URLQueryItem(name: "ids", value: externalId),
            URLQueryItem(name: "vs_currencies", value: currency),
            URLQueryItem(name: "include_last_updated_at", value: "true")
        ]
        var req = URLRequest(url: comps.url!)
        // Optional API key header
        if let key = KeychainService.get(account: "coingecko"), !key.isEmpty {
            req.addValue(key, forHTTPHeaderField: "x-cg-pro-api-key")
        } else if let env = ProcessInfo.processInfo.environment["COINGECKO_API_KEY"], !env.isEmpty {
            req.addValue(env, forHTTPHeaderField: "x-cg-pro-api-key")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw PriceProviderError.invalidResponse }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = json[externalId.lowercased()] as? [String: Any],
              let price = obj[currency] as? Double else {
            throw PriceProviderError.invalidResponse
        }
        let ts = (obj["last_updated_at"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()
        let curr = expectedCurrency?.uppercased() ?? currency.uppercased()
        return PriceQuote(price: price, currency: curr, asOf: ts, source: code)
    }
}

