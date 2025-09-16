// DragonShield/Repositories/AlertRepository.swift

import Foundation

enum AlertSeverity: String, CaseIterable, Identifiable {
    case info, warning, critical
    var id: String { rawValue }
}

enum AlertSubjectType: String, CaseIterable, Identifiable {
    case Instrument, PortfolioTheme, AssetClass, Portfolio, Account
    case Global, MarketEvent, EconomicSeries, CustomGroup, NotApplicable
    var id: String { rawValue }
}

extension AlertSubjectType {
    var requiresNumericScope: Bool {
        switch self {
        case .Instrument, .PortfolioTheme, .AssetClass, .Portfolio, .Account:
            return true
        default:
            return false
        }
    }

    var storageScopeTypeValue: String {
        switch self {
        case .NotApplicable:
            return AlertSubjectType.Instrument.rawValue
        default:
            return rawValue
        }
    }

    func storageScopeIdValue(_ scopeId: Int) -> Int {
        requiresNumericScope ? scopeId : 0
    }
}

struct AlertRow: Identifiable, Hashable {
    let id: Int
    var name: String
    var enabled: Bool
    var severity: AlertSeverity
    var scopeType: AlertSubjectType
    var scopeId: Int
    var subjectReference: String?
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
