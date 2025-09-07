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

    private static var cachedSupported: Set<String>? = nil
    private static let lock = NSLock()

    private func ensureSupportedSet() async throws -> Set<String> {
        FrankfurterProvider.lock.lock()
        if let s = FrankfurterProvider.cachedSupported { FrankfurterProvider.lock.unlock(); return s }
        FrankfurterProvider.lock.unlock()

        guard let url = URL(string: "https://api.frankfurter.app/currencies") else { throw FXProviderError.invalidURL }
        print("[FX][frankfurter.app] GET \(url.absoluteString)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw FXProviderError.badResponse }
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else { throw FXProviderError.decodingFailed }
        let codes = Set(dict.keys.map { $0.uppercased() })
        FrankfurterProvider.lock.lock(); FrankfurterProvider.cachedSupported = codes; FrankfurterProvider.lock.unlock()
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

