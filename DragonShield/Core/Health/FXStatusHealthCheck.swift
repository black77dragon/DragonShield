import Foundation

struct FXStatusHealthCheck: HealthCheck {
    let name: String = "FX Update"
    private let dbManager: DatabaseManager

    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }

    func run() async -> HealthCheckResult {
        // Determine schedule
        let enabled = dbManager.preferences.fxAutoUpdateEnabled
        let freq = dbManager.preferences.fxUpdateFrequency.lowercased()
        let days = (freq == "weekly") ? 7 : 1

        guard let last = dbManager.fetchLastFxRateUpdate() else {
            let msg = enabled
                ? "No FX update recorded yet. Next due: today (\(freq))."
                : "No FX update recorded and auto-update disabled."
            return .warning(message: msg)
        }

        // Compute next due date
        let cal = Calendar.current
        let nextDue = cal.date(byAdding: .day, value: days, to: last.updateDate) ?? Date()
        let today = Date()
        let fmt = DateFormatter.iso8601DateOnly

        // Parse optional breakdown from error_message if PARTIAL
        var failedCount: Int? = nil
        var skippedCount: Int? = nil
        if last.status == "PARTIAL", let s = last.errorMessage, let data = s.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            if let arr = obj["failed"] as? [Any] { failedCount = arr.count }
            if let arr = obj["skipped"] as? [Any] { skippedCount = arr.count }
        }

        let statusStr = last.status
        let base = dbManager.preferences.baseCurrency
        var parts: [String] = []
        parts.append("Last FX: \(fmt.string(from: last.updateDate)) status=\(statusStr) updated=\(last.ratesCount) via \(last.apiProvider) (base=\(base))")
        if let f = failedCount { parts.append("failed=\(f)") }
        if let s = skippedCount { parts.append("skipped=\(s)") }
        parts.append("next due=\(fmt.string(from: nextDue)) (\(freq))")
        let message = parts.joined(separator: ", ")

        if today > nextDue {
            let overdueDays = cal.dateComponents([.day], from: nextDue, to: today).day ?? 0
            return .warning(message: message + ", overdue by \(overdueDays)d")
        } else {
            return .ok(message: message)
        }
    }
}
