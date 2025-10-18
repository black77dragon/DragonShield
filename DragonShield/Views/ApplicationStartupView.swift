import SwiftUI

struct ApplicationStartupView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @AppStorage("runStartupHealthChecks") private var runStartupHealthChecks: Bool = true

    @State private var fxSummary: String = ""
    @State private var iosSummary: String = ""

    private var fxAutoBinding: Binding<Bool> {
        Binding(
            get: { dbManager.fxAutoUpdateEnabled },
            set: { newValue in
                guard dbManager.fxAutoUpdateEnabled != newValue else { return }
                dbManager.fxAutoUpdateEnabled = newValue
                _ = dbManager.upsertConfiguration(
                    key: "fx_auto_update_enabled",
                    value: newValue ? "true" : "false",
                    dataType: "boolean",
                    description: "Auto-update exchange rates on app launch"
                )
                refreshFxSummary()
            }
        )
    }

    private var iosAutoBinding: Binding<Bool> {
        Binding(
            get: { dbManager.iosSnapshotAutoEnabled },
            set: { newValue in
                guard dbManager.iosSnapshotAutoEnabled != newValue else { return }
                dbManager.iosSnapshotAutoEnabled = newValue
                _ = dbManager.upsertConfiguration(
                    key: "ios_snapshot_auto_enabled",
                    value: newValue ? "true" : "false",
                    dataType: "boolean",
                    description: "Auto-export iOS snapshot on launch"
                )
                refreshIosSummary()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                startupTasksCard
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.gray.opacity(0.06).ignoresSafeArea())
        .navigationTitle("Application Start Up")
        .onAppear {
            refreshFxSummary()
            refreshIosSummary()
        }
        .onChange(of: dbManager.fxAutoUpdateEnabled) { _, _ in
            refreshFxSummary()
        }
        .onChange(of: dbManager.fxUpdateFrequency) { _, _ in
            refreshFxSummary()
        }
        .onChange(of: dbManager.iosSnapshotAutoEnabled) { _, _ in
            refreshIosSummary()
        }
        .onChange(of: dbManager.iosSnapshotFrequency) { _, _ in
            refreshIosSummary()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🚀 Application Start Up")
                .font(.system(size: 28, weight: .bold))
            Text("Configure which tasks run automatically whenever DragonShield launches.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var startupTasksCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            StartupTaskRow(
                title: "Run Health Checks on Startup",
                subtitle: "Ensure the data pipeline is healthy before you start working.",
                detail: nil,
                isOn: $runStartupHealthChecks
            )
            Divider()
            StartupTaskRow(
                title: "Auto-update FX Rates",
                subtitle: "Fetch latest FX data if rates are stale when the app opens.",
                detail: fxSummary,
                isOn: fxAutoBinding
            )
            Divider()
            StartupTaskRow(
                title: "Create iOS DB Snapshot",
                subtitle: "Auto-export on Launch for the iOS companion app.",
                detail: iosSummary,
                isOn: iosAutoBinding
            )
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    private func refreshFxSummary() {
        let fmtDate = DateFormatter.iso8601DateOnly
        let fmtTime = DateFormatter(); fmtTime.dateFormat = "HH:mm"
        var parts: [String] = []

        if let job = dbManager.fetchLastSystemJobRun(jobKey: .fxUpdate) {
            let timestamp = job.finishedOrStarted
            parts.append("Last: \(fmtDate.string(from: timestamp)) \(fmtTime.string(from: timestamp)) (\(job.status.displayName))")
            if let message = job.message, !message.isEmpty { parts.append(message) }
        }

        if let last = dbManager.fetchLastFxRateUpdate() {
            let freq = dbManager.fxUpdateFrequency.lowercased()
            let days = (freq == "weekly") ? 7 : 1
            let next = Calendar.current.date(byAdding: .day, value: days, to: last.updateDate) ?? Date()
            parts.append("Next due: \(fmtDate.string(from: next)) (\(freq))")
        }

        if parts.isEmpty {
            fxSummary = "No updates yet — auto-update \(dbManager.fxAutoUpdateEnabled ? "enabled" : "disabled")."
        } else {
            fxSummary = parts.joined(separator: " — ")
        }
    }

    private func refreshIosSummary() {
        let svc = IOSSnapshotExportService(dbManager: dbManager)
        let fmtDate = DateFormatter.iso8601DateOnly
        let fmtTime = DateFormatter(); fmtTime.dateFormat = "HH:mm"
        let freq = dbManager.iosSnapshotFrequency.lowercased()
        let days = (freq == "weekly") ? 7 : 1
        if let job = dbManager.fetchLastSystemJobRun(jobKey: .iosSnapshotExport) {
            let timestamp = job.finishedOrStarted
            var parts: [String] = []
            parts.append("Last: \(fmtDate.string(from: timestamp)) \(fmtTime.string(from: timestamp)) (\(job.status.displayName))")
            if let message = job.message, !message.isEmpty { parts.append(message) }
            let next = Calendar.current.date(byAdding: .day, value: days, to: timestamp) ?? Date()
            parts.append("Next due: \(fmtDate.string(from: next)) (\(freq))")
            iosSummary = parts.joined(separator: " — ")
        } else if let fallback = svc.lastExportDate() {
            let next = Calendar.current.date(byAdding: .day, value: days, to: fallback) ?? Date()
            iosSummary = "Last file: \(fmtDate.string(from: fallback)) \(fmtTime.string(from: fallback)), next due: \(fmtDate.string(from: next)) (\(freq))"
        } else {
            iosSummary = "No export yet — auto-export \(dbManager.iosSnapshotAutoEnabled ? "enabled" : "disabled")."
        }
    }
}

private struct StartupTaskRow: View {
    let title: String
    let subtitle: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
    }
}
