import SwiftUI
import Combine

struct DragonAsset: Identifiable {
    var id: Int
    var name: String
    var type: String
    var currency: String
    var valorNr: String?
    var tickerSymbol: String?
    var isin: String?
    var isDeleted: Bool
    var isActive: Bool
    var riskSRI: Int?
    var riskLiquidityTier: Int?
}

class AssetManager: ObservableObject {
    @Published var assets: [DragonAsset] = []
    private let dbManager = DatabaseManager()

    init() {
        loadAssets()
    }

    func loadAssets() {
        // Include all instruments (active + soft-deleted) for the Instruments screen
        let instrumentData = dbManager.fetchAssets(includeDeleted: true, includeInactive: true)
        let assetTypeData = dbManager.fetchAssetTypes()

        print("🔍 AssetManager loading: \(instrumentData.count) instruments, \(assetTypeData.count) types")

        // Create lookup with fallback
        let assetTypeLookup = Dictionary(uniqueKeysWithValues: assetTypeData.map { ($0.id, $0.name) })

        let loadedAssets = instrumentData.map { instrument in
            let typeName = assetTypeLookup[instrument.subClassId] ?? "Unknown"
            let profile = dbManager.fetchRiskProfile(instrumentId: instrument.id)
            return DragonAsset(
                id: instrument.id,
                name: instrument.name,
                type: typeName,
                currency: instrument.currency,
                valorNr: instrument.valorNr,
                tickerSymbol: instrument.tickerSymbol,
                isin: instrument.isin,
                isDeleted: instrument.isDeleted,
                isActive: instrument.isActive,
                riskSRI: profile?.effectiveSRI,
                riskLiquidityTier: profile?.effectiveLiquidityTier
            )
        }

        DispatchQueue.main.async {
            self.assets = loadedAssets
            print("✅ AssetManager loaded \(self.assets.count) assets")
        }
    }

    func addAsset(_ asset: DragonAsset) {
        assets.append(asset)
    }

    func deleteAsset(_ asset: DragonAsset) {
        assets.removeAll { $0.id == asset.id }
    }
}
