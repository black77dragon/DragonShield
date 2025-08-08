import Foundation

struct Asset: Identifiable, Codable {
    let id: Int64
    var assetTypeId: Int64
    var name: String
    var tickerSymbol: String?
    var isin: String?
    var currency: String
    var notes: String?
}
