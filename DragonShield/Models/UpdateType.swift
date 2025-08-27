// DragonShield/Models/UpdateType.swift
// MARK: - Version 1.0
// MARK: - History
// - 1.0: Initial model for update type reference table.

import Foundation

struct UpdateType: Identifiable, Codable, Hashable {
    let id: Int
    let code: String
    let name: String
}
