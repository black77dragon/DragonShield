import SwiftUI

struct DragonAsset: Identifiable {
    var id = UUID()
    var name: String
    var type: String
    var currency: String
    var valorNr: String?
    var tickerSymbol: String?
    var isin: String?
}

class AssetManager: ObservableObject {
    @Published var assets: [DragonAsset] = []
    private let dbManager: DatabaseManager

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        loadAssets()
    }
    
    func loadAssets() {
        let instrumentData = dbManager.fetchAssets()
        let assetTypeData = dbManager.fetchAssetTypes()
        
        print("🔍 AssetManager loading: \(instrumentData.count) instruments, \(assetTypeData.count) types")
        
        // Create lookup with fallback
        let assetTypeLookup = Dictionary(uniqueKeysWithValues: assetTypeData.map { ($0.id, $0.name) })
        
        let loadedAssets = instrumentData.map { instrument in
            let typeName = assetTypeLookup[instrument.subClassId] ?? "Unknown"
            return DragonAsset(
                name: instrument.name,
                type: typeName,
                currency: instrument.currency,
                valorNr: instrument.valorNr,
                tickerSymbol: instrument.tickerSymbol,
                isin: instrument.isin
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
