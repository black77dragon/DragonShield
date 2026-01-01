// DragonShield/Utils/UserDefaultsKeys.swift

// MARK: - Version 1.0 (2025-05-31)

// MARK: - History

// - Initial creation: Defines keys for UserDefaults.

import Foundation

enum UserDefaultsKeys {
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
    /// Persist selected segment in Currencies & FX maintenance view.
    static let currenciesFxSegment = "currenciesFxSegment"
    /// Remember last-used tab in the new Portfolio Theme Workspace.
    static let portfolioThemeWorkspaceLastTab = "portfolioThemeWorkspaceLastTab"
    /// Visible columns in Workspace Holdings table (comma-separated list of column ids)
    static let portfolioThemeWorkspaceHoldingsColumns = "portfolioThemeWorkspaceHoldingsColumns"
    /// Column widths for Workspace Holdings table (csv: col:width,...)
    static let portfolioThemeWorkspaceHoldingsColWidths = "portfolioThemeWorkspaceHoldingsColWidths"
    /// Sort for Workspace Holdings table: e.g. "instrument|asc"
    static let portfolioThemeWorkspaceHoldingsSort = "portfolioThemeWorkspaceHoldingsSort"
    /// Preferred font size for Workspace Holdings table.
    static let portfolioThemeWorkspaceHoldingsFontSize = "portfolioThemeWorkspaceHoldingsFontSize"
    /// Persist window frame for import value report.
    static let importReportWindowFrame = "importReport.windowFrame"
    /// Toggle for showing the incoming deadlines popup on each dashboard visit.
    static let dashboardShowIncomingDeadlinesEveryVisit = "dashboardShowIncomingDeadlinesEveryVisit"
    /// Tracks whether the incoming deadline popup has been shown during the current launch.
    static let dashboardIncomingPopupShownThisLaunch = "dashboardIncomingPopupShownThisLaunch"
    /// Persist Kanban board to-do items (JSON encoded).
    static let kanbanTodos = "kanbanTodos"
    /// Tracks migrations applied to the new Dashboard tile layout (three fixed panels).
    static let newDashboardLayoutVersion = "newDashboardLayoutVersion"
    /// Persist tile order for the new Dashboard's three panels.
    static let newDashboardColumnsLayout = "newDashboardColumnsLayout"
    /// Per-tile category overrides for the dashboard (tileID -> DashboardCategory.rawValue).
    static let dashboardTileCategoryOverrides = "dashboardTileCategoryOverrides"
    /// Tracks migrations applied to the categorized Dashboard layout.
    static let categorizedDashboardLayoutVersion = "categorizedDashboardLayoutVersion"
    /// Persist tile order for the categorized Dashboard (non-warning columns).
    static let categorizedDashboardMainLayout = "categorizedDashboardMainLayout"
    /// Persist pinned warning tile order for the categorized Dashboard.
    static let categorizedDashboardWarningsLayout = "categorizedDashboardWarningsLayout"
}
