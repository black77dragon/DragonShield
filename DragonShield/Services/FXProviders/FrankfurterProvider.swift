import Foundation

/// Provider using frankfurter.app (ECB rates), no API key required.
/// Docs: https://www.frankfurter.app/docs/
/// Example latest: https://api.frankfurter.app/latest?from=EUR&to=USD,CHF
final class FrankfurterProvider: FXRateProvider {
    var code: String { "frankfurter.app" }

    struct LatestResponse: Decodable {
        let amount: Double
        let base: String
        let date: String
        let rates: [String: Double]
    }

    // Async-safe cache for supported currency codes
    private actor SupportCache {
        static let shared = SupportCache()
        private var codes: Set<String>? = nil
        func get() -> Set<String>? { codes }
        func set(_ new: Set<String>) { codes = new }
    }

    private func ensureSupportedSet() async throws -> Set<String> {
        if let s = await SupportCache.shared.get() { return s }
        guard let url = URL(string: "https://api.frankfurter.app/currencies") else { throw FXProviderError.invalidURL }
        print("[FX][frankfurter.app] GET \(url.absoluteString)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw FXProviderError.badResponse }
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else { throw FXProviderError.decodingFailed }
        let codes = Set(dict.keys.map { $0.uppercased() })
        await SupportCache.shared.set(codes)
        print("[FX][frankfurter.app] Supported codes: \(codes.count)")
        return codes
    }

    func fetchLatest(base: String, symbols: [String]) async throws -> FXRatesResponse {
        // frankfurter supports only base EUR, so we request from=EUR and include CHF plus requested symbols.
        let supported = try await ensureSupportedSet()
        var targets = Set(symbols.map { $0.uppercased() }.filter { supported.contains($0) })
        targets.insert("CHF")
        let toParam = targets.sorted().joined(separator: ",")

        guard var comps = URLComponents(string: "https://api.frankfurter.app/latest") else { throw FXProviderError.invalidURL }
        comps.queryItems = [
            URLQueryItem(name: "from", value: "EUR"),
            URLQueryItem(name: "to", value: toParam)
        ]
        guard let url = comps.url else { throw FXProviderError.invalidURL }
        print("[FX][frankfurter.app] GET \(url.absoluteString)")

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            print("[FX][frankfurter.app] HTTP status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            throw FXProviderError.badResponse
        }
        let decoder = JSONDecoder()
        let api: LatestResponse
        do {
            api = try decoder.decode(LatestResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[FX][frankfurter.app] Decode error: \(error)\nRaw: \(raw)")
            throw FXProviderError.decodingFailed
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let asOf = df.date(from: api.date) ?? Date()
        print("[FX][frankfurter.app] OK base=\(api.base) date=\(api.date) keys=\(api.rates.keys.sorted().joined(separator: ","))")
        return FXRatesResponse(asOf: asOf, base: api.base.uppercased(), rates: api.rates, providerCode: code)
    }
}
