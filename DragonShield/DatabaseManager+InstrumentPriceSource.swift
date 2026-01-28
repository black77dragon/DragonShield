import Foundation

extension DatabaseManager {
    func enabledPriceSourceRecords() -> [PriceSourceRecord] {
        // Restrict to active, non-deleted instruments to mirror the maintenance UI.
        let activeInstruments = Dictionary(uniqueKeysWithValues: fetchAssets().map { ($0.id, $0.currency) })
        return InstrumentPriceSourceRepository(connection: databaseConnection)
            .enabledPriceSourceRecords(activeInstruments: activeInstruments)
    }

    /// Returns the latest price source per instrument id using the same ordering as `getPriceSource`.
    func getPriceSources(instrumentIds: [Int]) -> [Int: InstrumentPriceSource] {
        InstrumentPriceSourceRepository(connection: databaseConnection)
            .getPriceSources(instrumentIds: instrumentIds)
    }

    func getPriceSource(instrumentId: Int) -> InstrumentPriceSource? {
        InstrumentPriceSourceRepository(connection: databaseConnection)
            .getPriceSource(instrumentId: instrumentId)
    }

    @discardableResult
    func upsertPriceSource(instrumentId: Int, providerCode: String, externalId: String, enabled: Bool, priority: Int = 1) -> Bool {
        InstrumentPriceSourceRepository(connection: databaseConnection)
            .upsertPriceSource(
                instrumentId: instrumentId,
                providerCode: providerCode,
                externalId: externalId,
                enabled: enabled,
                priority: priority
            )
    }

    @discardableResult
    func updatePriceSourceStatus(instrumentId: Int, providerCode: String, status: String?) -> Bool {
        InstrumentPriceSourceRepository(connection: databaseConnection)
            .updatePriceSourceStatus(
                instrumentId: instrumentId,
                providerCode: providerCode,
                status: status
            )
    }

    @discardableResult
    func disablePriceSources(instrumentId: Int) -> Bool {
        InstrumentPriceSourceRepository(connection: databaseConnection)
            .disablePriceSources(instrumentId: instrumentId)
    }
}
