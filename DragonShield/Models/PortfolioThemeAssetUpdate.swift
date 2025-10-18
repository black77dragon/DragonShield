import Foundation

/// Backwards compatibility alias. Theme-linked instrument notes now reuse the
/// `InstrumentNote` model; legacy call sites continue referencing
/// `PortfolioThemeAssetUpdate`.
public typealias PortfolioThemeAssetUpdate = InstrumentNote
