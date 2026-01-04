import Foundation
import Combine
import SQLite3

final class IchimokuSettingsService: ObservableObject {
    @Published private(set) var state: IchimokuSettingsState = .defaults
    private let dbManager: DatabaseManager

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
        load()
    }

    func load() {
        var current = IchimokuSettingsState.defaults
        current.scheduleEnabled = configurationValue(for: "ichimoku.schedule.enabled")?.lowercased() != "false"
        if let timeString = configurationValue(for: "ichimoku.schedule.time"),
           let components = Self.parseTimeComponents(from: timeString)
        {
            current.scheduleTime = components
        }
        if let tzIdentifier = configurationValue(for: "ichimoku.schedule.timezone"),
           let tz = TimeZone(identifier: tzIdentifier)
        {
            current.scheduleTimeZone = tz
        }
        if let maxCandidates = configurationValue(for: "ichimoku.max_candidates"),
           let value = Int(maxCandidates) { current.maxCandidates = value }
        if let lookback = configurationValue(for: "ichimoku.history.lookback_days"),
           let value = Int(lookback) { current.historyLookbackDays = value }
        if let regression = configurationValue(for: "ichimoku.regression.window"),
           let value = Int(regression) { current.regressionWindow = value }
        if let providers = configurationValue(for: "ichimoku.provider.priority") {
            current.priceProviderPriority = providers
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        }
        DispatchQueue.main.async {
            self.state = current
        }
    }

    func update(_ newState: IchimokuSettingsState) {
        state = newState
        save()
    }

    func save() {
        let state = self.state
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.schedule.enabled",
                                          value: state.scheduleEnabled ? "true" : "false",
                                          dataType: "bool",
                                          description: "Enable or disable the daily Ichimoku Dragon scan")
        let timeString = Self.formatTimeComponents(state.scheduleTime)
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.schedule.time",
                                          value: timeString,
                                          dataType: "string",
                                          description: "Time of day for Ichimoku scan (HH:mm)")
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.schedule.timezone",
                                          value: state.scheduleTimeZone.identifier,
                                          dataType: "string",
                                          description: "Timezone identifier for scheduling")
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.max_candidates",
                                          value: String(state.maxCandidates),
                                          dataType: "int",
                                          description: "Maximum number of daily Ichimoku candidates")
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.history.lookback_days",
                                          value: String(state.historyLookbackDays),
                                          dataType: "int",
                                          description: "Historical lookback window in days for price download")
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.regression.window",
                                          value: String(state.regressionWindow),
                                          dataType: "int",
                                          description: "Window length for slope regression (days)")
        _ = dbManager.configurationStore.upsertConfiguration(key: "ichimoku.provider.priority",
                                          value: state.priceProviderPriority.joined(separator: ","),
                                          dataType: "string",
                                          description: "Preferred data providers in order (comma-separated codes)")
    }

    private func configurationValue(for key: String) -> String? {
        let sql = "SELECT value FROM Configuration WHERE key = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(dbManager.db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let ptr = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: ptr)
    }

    private static func parseTimeComponents(from string: String) -> DateComponents? {
        let parts = string.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }

    private static func formatTimeComponents(_ components: DateComponents) -> String {
        let hour = components.hour ?? 22
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}
