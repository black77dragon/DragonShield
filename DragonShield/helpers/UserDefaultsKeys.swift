// DragonShield/Utils/UserDefaultsKeys.swift
// MARK: - Version 1.0 (2025-05-31)
// MARK: - History
// - Initial creation: Defines keys for UserDefaults.

import Foundation

struct UserDefaultsKeys {
    static let enableParsingCheckpoints = "enableParsingCheckpoints"
    static let automaticBackupsEnabled = "automaticBackupsEnabled"
    static let automaticBackupTime = "automaticBackupTime"
    static let backupLog = "backupLog"
    static let statementImportLog = "statementImportLog"
    static let lastBackupTimestamp = "lastBackupTimestamp"
    static let lastReferenceBackupTimestamp = "lastReferenceBackupTimestamp"
    static let databaseMode = "databaseMode"
    static let backupDirectoryURL = "backupDirectoryURL"
    static let backupDirectoryBookmark = "backupDirectoryBookmark"
    static let positionsVisibleColumns = "positionsVisibleColumns"
    static let positionsFontSize = "positionsFontSize"
    /// Persist selected segment in Currencies & FX maintenance view.
    static let currenciesFxSegment = "currenciesFxSegment"
    /// Remember last-used tab in Portfolio Theme Details.
    static let portfolioThemeDetailLastTab = "portfolioThemeDetailLastTab"
    /// Toggle to use the new Portfolio Theme Workspace (beta).
    static let portfolioThemeWorkspaceEnabled = "portfolioThemeWorkspaceEnabled"
    /// Remember last-used tab in the new Portfolio Theme Workspace.
    static let portfolioThemeWorkspaceLastTab = "portfolioThemeWorkspaceLastTab"
    /// Visible columns in Workspace Holdings table (comma-separated list of column ids)
    static let portfolioThemeWorkspaceHoldingsColumns = "portfolioThemeWorkspaceHoldingsColumns"
    /// Column widths for Workspace Holdings table (csv: col:width,...)
    static let portfolioThemeWorkspaceHoldingsColWidths = "portfolioThemeWorkspaceHoldingsColWidths"
    /// Sort for Workspace Holdings table: e.g. "instrument|asc"
    static let portfolioThemeWorkspaceHoldingsSort = "portfolioThemeWorkspaceHoldingsSort"
    /// Persist window frame for import value report.
    static let importReportWindowFrame = "importReport.windowFrame"
    /// Persist column widths for Portfolio Themes list.
    static let portfolioThemesColumnWidths = "portfolioThemesColumnWidths"
    /// Toggle for showing the incoming deadlines popup on each dashboard visit.
    static let dashboardShowIncomingDeadlinesEveryVisit = "dashboardShowIncomingDeadlinesEveryVisit"
    /// Tracks whether the incoming deadline popup has been shown during the current launch.
    static let dashboardIncomingPopupShownThisLaunch = "dashboardIncomingPopupShownThisLaunch"
    /// Column widths for Instrument Prices Maintenance table (csv: col:width,...)
    static let pricesMaintenanceColWidths = "pricesMaintenanceColWidths"
}
