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
    /// Persist window frame for import value report.
    static let importReportWindowFrame = "importReport.windowFrame"
}
