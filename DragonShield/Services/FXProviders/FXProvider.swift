import Foundation

public struct FXRatesResponse {
    public let asOf: Date
    public let base: String
    public let rates: [String: Double]
    public let providerCode: String
}

public protocol FXRateProvider {
    /// Fetch latest FX rates for the given symbols relative to the base currency.
    /// Implementations should return rates where `1 base = rate * target` (e.g., base CHF -> USD rate is CHF to USD).
    func fetchLatest(base: String, symbols: [String]) async throws -> FXRatesResponse
    var code: String { get }
}

public enum FXProviderError: Error {
    case invalidURL
    case badResponse
    case decodingFailed
}
