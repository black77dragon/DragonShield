import Foundation

public typealias AssetSubClassItem = (id: Int, name: String)

private func normalized(_ string: String) -> String {
    string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
}

public func sortAssetSubClasses(_ items: [AssetSubClassItem]) -> [AssetSubClassItem] {
    items.sorted { normalized($0.name) < normalized($1.name) }
}

public func filterAssetSubClasses(_ items: [AssetSubClassItem], query: String) -> [AssetSubClassItem] {
    guard !query.isEmpty else { return items }
    let needle = normalized(query)
    return items.filter { normalized($0.name).contains(needle) }
}
