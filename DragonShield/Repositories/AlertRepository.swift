// DragonShield/Repositories/AlertRepository.swift

import Foundation

enum AlertSeverity: String, CaseIterable, Identifiable {
    case info, warning, critical
    var id: String { rawValue }
}

enum AlertScopeType: String, CaseIterable, Identifiable {
    case Instrument, PortfolioTheme, AssetClass, Portfolio, Account
    var id: String { rawValue }
}

struct AlertRow: Identifiable, Hashable {
    let id: Int
    var name: String
    var enabled: Bool
    var severity: AlertSeverity
    var scopeType: AlertScopeType
    var scopeId: Int
    var triggerTypeCode: String
    var paramsJson: String
    var nearValue: Double?
    var nearUnit: String? // 'pct' | 'abs'
    var hysteresisValue: Double?
    var hysteresisUnit: String? // 'pct' | 'abs'
    var cooldownSeconds: Int?
    var muteUntil: String?
    var scheduleStart: String?
    var scheduleEnd: String?
    var notes: String?
    var createdAt: String
    var updatedAt: String
}

