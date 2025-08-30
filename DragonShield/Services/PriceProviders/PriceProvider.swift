import Foundation

// MARK: - Provider Protocols & Models

public struct PriceQuote {
    public let price: Double
    public let currency: String
    public let asOf: Date
    public let source: String
}

public struct PriceSourceRecord {
    public let instrumentId: Int
    public let providerCode: String
    public let externalId: String
    public let expectedCurrency: String?
}

public protocol PriceProvider {
    var code: String { get }
    var displayName: String { get }
    func fetchLatest(externalId: String, expectedCurrency: String?) async throws -> PriceQuote
}

public enum PriceProviderError: Error {
    case notFound
    case invalidResponse
    case rateLimited
    case unauthorized
    case network(Error)
}

// MARK: - Registry

public final class PriceProviderRegistry {
    public static let shared = PriceProviderRegistry()
    private var providers: [String: PriceProvider] = [:]
    private init() {}

    public func register(_ provider: PriceProvider) {
        providers[provider.code.lowercased()] = provider
    }

    public func provider(for code: String) -> PriceProvider? {
        providers[code.lowercased()]
    }
}

// MARK: - Example Mock Provider (for testing)

public final class MockPriceProvider: PriceProvider {
    public let code = "mock"
    public let displayName = "Mock Provider"

    public init() {}

    public func fetchLatest(externalId: String, expectedCurrency: String?) async throws -> PriceQuote {
        // Returns a static price for development/testing.
        return PriceQuote(price: 123.45, currency: expectedCurrency ?? "CHF", asOf: Date(), source: code)
    }
}

