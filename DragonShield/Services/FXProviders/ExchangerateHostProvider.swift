import Foundation

/// Simple provider using exchangerate.host free API.
/// Docs: https://exchangerate.host/#/
/// Example: https://api.exchangerate.host/latest?base=CHF&symbols=USD,EUR
final class ExchangerateHostProvider: FXRateProvider {
    var code: String { "exchangerate.host" }

    struct ApiResponse: Decodable {
        let base: String
        let date: String
        let rates: [String: Double]
    }

    func fetchLatest(base: String, symbols: [String]) async throws -> FXRatesResponse {
        let baseUpper = base.uppercased()
        let symString = symbols.map { $0.uppercased() }.joined(separator: ",")
        guard var comps = URLComponents(string: "https://api.exchangerate.host/latest") else { throw FXProviderError.invalidURL }
        comps.queryItems = [
            URLQueryItem(name: "base", value: baseUpper),
            URLQueryItem(name: "symbols", value: symString)
        ]
        guard let url = comps.url else { throw FXProviderError.invalidURL }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FXProviderError.badResponse
        }
        let decoder = JSONDecoder()
        let api = try decoder.decode(ApiResponse.self, from: data)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let asOf = df.date(from: api.date) ?? Date()
        return FXRatesResponse(asOf: asOf, base: api.base.uppercased(), rates: api.rates, providerCode: code)
    }
}

