// DragonShield/Models/PortfolioUpdateType.swift

import Foundation

enum PortfolioUpdateType: String, CaseIterable, Codable {
    case General
    case Research
    case Rebalance
    case Risk
}

extension PortfolioUpdateType {
    static var allowedSQLList: String {
        allCases.map { "'\($0.rawValue)'" }.joined(separator: ",")
    }
}

