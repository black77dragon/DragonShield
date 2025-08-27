// DragonShield/Models/UpdateType.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Initial model for update type reference table.

import Foundation

/// Represents a category for portfolio and instrument updates.
/// Conforms to `Hashable` so it can be used in SwiftUI pickers and sets.
struct UpdateType: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let code: String
    let name: String
}
