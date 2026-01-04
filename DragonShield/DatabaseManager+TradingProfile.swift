import Foundation

extension DatabaseManager {
    func fetchTradingProfiles(includeInactive: Bool = true) -> [TradingProfileRow] {
        TradingProfileRepository(connection: databaseConnection)
            .fetchProfiles(includeInactive: includeInactive)
    }

    func fetchDefaultTradingProfile() -> TradingProfileRow? {
        TradingProfileRepository(connection: databaseConnection).fetchDefaultProfile()
    }

    func createTradingProfile(name: String,
                              type: String,
                              primaryObjective: String?,
                              tradingStrategyExecutiveSummary: String?,
                              lastReviewDate: String?,
                              nextReviewText: String?,
                              activeRegime: String?,
                              regimeConfidence: String?,
                              riskState: String?,
                              isDefault: Bool,
                              isActive: Bool) -> TradingProfileRow?
    {
        TradingProfileRepository(connection: databaseConnection).createProfile(
            name: name,
            type: type,
            primaryObjective: primaryObjective,
            tradingStrategyExecutiveSummary: tradingStrategyExecutiveSummary,
            lastReviewDate: lastReviewDate,
            nextReviewText: nextReviewText,
            activeRegime: activeRegime,
            regimeConfidence: regimeConfidence,
            riskState: riskState,
            isDefault: isDefault,
            isActive: isActive
        )
    }

    func updateTradingProfile(id: Int,
                              name: String?,
                              type: String?,
                              primaryObjective: String?,
                              tradingStrategyExecutiveSummary: String?,
                              lastReviewDate: String?,
                              nextReviewText: String?,
                              activeRegime: String?,
                              regimeConfidence: String?,
                              riskState: String?,
                              isDefault: Bool?,
                              isActive: Bool?) -> Bool
    {
        TradingProfileRepository(connection: databaseConnection).updateProfile(
            id: id,
            name: name,
            type: type,
            primaryObjective: primaryObjective,
            tradingStrategyExecutiveSummary: tradingStrategyExecutiveSummary,
            lastReviewDate: lastReviewDate,
            nextReviewText: nextReviewText,
            activeRegime: activeRegime,
            regimeConfidence: regimeConfidence,
            riskState: riskState,
            isDefault: isDefault,
            isActive: isActive
        )
    }

    func setDefaultTradingProfile(id: Int?) -> Bool {
        TradingProfileRepository(connection: databaseConnection).setDefaultProfile(id: id)
    }

    func fetchTradingProfileCoordinates(profileId: Int) -> [TradingProfileCoordinateRow] {
        TradingProfileRepository(connection: databaseConnection).fetchCoordinates(profileId: profileId)
    }

    func updateTradingProfileCoordinate(id: Int,
                                        title: String?,
                                        weightPercent: Double?,
                                        value: Double?,
                                        sortOrder: Int?,
                                        isLocked: Bool?) -> Bool
    {
        TradingProfileRepository(connection: databaseConnection).updateCoordinate(
            id: id,
            title: title,
            weightPercent: weightPercent,
            value: value,
            sortOrder: sortOrder,
            isLocked: isLocked
        )
    }

    func fetchTradingProfileDominance(profileId: Int) -> [TradingProfileDominanceRow] {
        TradingProfileRepository(connection: databaseConnection).fetchDominance(profileId: profileId)
    }

    func replaceTradingProfileDominance(profileId: Int, items: [TradingProfileDominanceInput]) -> Bool {
        TradingProfileRepository(connection: databaseConnection).replaceDominance(profileId: profileId, items: items)
    }

    func fetchTradingProfileRegimeSignals(profileId: Int) -> [TradingProfileRegimeSignalRow] {
        TradingProfileRepository(connection: databaseConnection).fetchRegimeSignals(profileId: profileId)
    }

    func fetchTradingProfileStrategyFits(profileId: Int) -> [TradingProfileStrategyFitRow] {
        TradingProfileRepository(connection: databaseConnection).fetchStrategyFits(profileId: profileId)
    }

    func fetchTradingProfileRiskSignals(profileId: Int) -> [TradingProfileRiskSignalRow] {
        TradingProfileRepository(connection: databaseConnection).fetchRiskSignals(profileId: profileId)
    }

    func fetchTradingProfileRules(profileId: Int) -> [TradingProfileRuleRow] {
        TradingProfileRepository(connection: databaseConnection).fetchRules(profileId: profileId)
    }

    func fetchTradingProfileViolations(profileId: Int) -> [TradingProfileViolationRow] {
        TradingProfileRepository(connection: databaseConnection).fetchViolations(profileId: profileId)
    }

    func fetchTradingProfileReviewLogs(profileId: Int) -> [TradingProfileReviewLogRow] {
        TradingProfileRepository(connection: databaseConnection).fetchReviewLogs(profileId: profileId)
    }
}
