import SwiftUI

struct DragonAsset: Identifiable {
    var id = UUID()
    var name: String
    var type: String
    var currency: String
    var tickerSymbol: String?
    var isin: String?
}

class AssetManager: ObservableObject {
    @Published var assets: [DragonAsset] = []
    private let dbManager = DatabaseManager()
    
    init() {
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
                tickerSymbol: instrument.tickerSymbol,  // ✅ Use actual data
                isin: instrument.isin                   // ✅ Use actual data
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
