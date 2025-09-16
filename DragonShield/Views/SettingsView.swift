// DragonShield/Views/SettingsView.swift
// MARK: - Version 1.5 (UI Refactor)
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var runner: HealthCheckRunner

    @AppStorage(UserDefaultsKeys.enableParsingCheckpoints) private var enableParsingCheckpoints: Bool = false
    @AppStorage("runStartupHealthChecks") private var runStartupHealthChecks: Bool = true
    @AppStorage("coingeckoPreferFree") private var coingeckoPreferFree: Bool = false

    private var okCount: Int { runner.reports.filter { if case .ok = $0.result { true } else { false } }.count }
    private var warningCount: Int { runner.reports.filter { if case .warning = $0.result { true } else { false } }.count }
    private var errorCount: Int { runner.reports.filter { if case .error = $0.result { true } else { false } }.count }

    // Local state
    @State private var tempBaseCurrency: String = ""
    @State private var showLogs: Bool = false
    @State private var isTestingCG: Bool = false
    @State private var showCGResult: Bool = false
    @State private var cgResultMessage: String = ""

    // FX auto-update settings
    @State private var fxAutoEnabled: Bool = true
    @State private var fxFrequency: String = "daily"
    @State private var fxLastSummary: String = ""

    // iOS snapshot settings
    @State private var iosAutoEnabled: Bool = true
    @State private var iosFrequency: String = "daily"
    @State private var iosTargetPath: String = ""
    @State private var iosStatus: String = ""

    var body: some View {
        ZStack {
            Color.gray.opacity(0.06).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    CardSection(title: "App Basics") {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Base Currency").frame(width: 160, alignment: .leading)
                            TextField("", text: $tempBaseCurrency)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                                .onSubmit {
                                    let v = tempBaseCurrency.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    if v.count == 3 && v.allSatisfy({ $0.isLetter }) { _ = dbManager.updateConfiguration(key: "base_currency", value: v) }
                                    else { tempBaseCurrency = dbManager.baseCurrency }
                                }
                            Spacer()
                        }
                        Stepper("Decimal Precision: \(dbManager.decimalPrecision)",
                                value: Binding(get: { dbManager.decimalPrecision }, set: { _ = dbManager.updateConfiguration(key: "decimal_precision", value: "\($0)") }), in: 0...8)
                        Divider().padding(.vertical, 2)
                        Toggle("Run Health Checks on Startup", isOn: $runStartupHealthChecks)
                        HStack {
                            Text("Last Result").frame(width: 160, alignment: .leading)
                            Text("\(okCount) ok / \(warningCount) warning / \(errorCount) error")
                            Spacer()
                            NavigationLink("Detailed Report", destination: HealthCheckResultsView())
                        }
                    }

                    CardSection(title: "Table Display Settings") {
                        Stepper("Row Spacing: \(String(format: "%.1f", dbManager.tableRowSpacing)) pts",
                                value: Binding(get: { dbManager.tableRowSpacing }, set: { _ = dbManager.updateConfiguration(key: "table_row_spacing", value: String(format: "%.1f", $0)) }), in: 0.0...10.0, step: 0.5)
                        Stepper("Row Padding: \(String(format: "%.1f", dbManager.tableRowPadding)) pts",
                                value: Binding(get: { dbManager.tableRowPadding }, set: { _ = dbManager.updateConfiguration(key: "table_row_padding", value: String(format: "%.1f", $0)) }), in: 0.0...20.0, step: 1.0)
                    }

                    CardSection(title: "Price Providers") {
                        ProviderKeyRow(label: "CoinGecko API Key", account: "coingecko", placeholder: "Enter CoinGecko key")
                        ProviderKeyRow(label: "Finnhub API Key", account: "finnhub", placeholder: "Enter Finnhub key")
                        ProviderKeyRow(label: "Alpha Vantage API Key", account: "alphavantage", placeholder: "Enter Alpha Vantage key")
                        Text("Keys are stored securely in your macOS Keychain. Env vars also supported.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Toggle("Prefer Free CoinGecko (don’t use API key)", isOn: $coingeckoPreferFree)
                            .help("Skips Keychain access and always uses api.coingecko.com.")
                        HStack { Spacer(); Button(action: testCoinGecko) { isTestingCG ? AnyView(AnyView(ProgressView())) : AnyView(Text("Test CoinGecko")) }; Button("View Logs") { showLogs = true } }
                    }

                    CardSection(title: "FX Updates") {
                        Toggle("Auto-update on Launch", isOn: $fxAutoEnabled)
                            .onChange(of: fxAutoEnabled) { _, newValue in
                                _ = dbManager.upsertConfiguration(key: "fx_auto_update_enabled", value: newValue ? "true" : "false", dataType: "boolean", description: "Auto-update exchange rates on app launch")
                            }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Frequency").frame(width: 160, alignment: .leading)
                            Picker("", selection: $fxFrequency) { Text("Daily").tag("daily"); Text("Weekly").tag("weekly") }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                .onChange(of: fxFrequency) { _, newValue in
                                    let v = (newValue == "weekly") ? "weekly" : "daily"
                                    _ = dbManager.upsertConfiguration(key: "fx_update_frequency", value: v, dataType: "string", description: "FX auto-update frequency (daily|weekly)")
                                    updateFxStatus()
                                }
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Status").frame(width: 160, alignment: .leading)
                            Text(fxLastSummary.isEmpty ? "No updates yet" : fxLastSummary).foregroundColor(.secondary)
                            Spacer()
                        }
                    }

                    CardSection(title: "iOS Snapshot (DB Copy for iPhone app)") {
                        Toggle("Auto-export on Launch", isOn: $iosAutoEnabled)
                            .onChange(of: iosAutoEnabled) { _, newValue in
                                _ = dbManager.upsertConfiguration(key: "ios_snapshot_auto_enabled", value: newValue ? "true" : "false", dataType: "boolean", description: "Auto-export iOS snapshot on launch")
                            }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Frequency").frame(width: 160, alignment: .leading)
                            Picker("", selection: $iosFrequency) { Text("Daily").tag("daily"); Text("Weekly").tag("weekly") }
                                .pickerStyle(.segmented)
                                .frame(width: 240)
                                .onChange(of: iosFrequency) { _, newValue in
                                    let v = (newValue == "weekly") ? "weekly" : "daily"
                                    _ = dbManager.upsertConfiguration(key: "ios_snapshot_frequency", value: v, dataType: "string", description: "iOS snapshot export frequency (daily|weekly)")
                                    updateIOSStatus()
                                }
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Destination").frame(width: 160, alignment: .leading)
                            TextField("~/Library/Mobile Documents/com~apple~CloudDocs/...", text: $iosTargetPath)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 300)
                                .onSubmit {
                                    _ = dbManager.upsertConfiguration(key: "ios_snapshot_target_path", value: iosTargetPath, dataType: "string", description: "Destination folder for iOS snapshot export")
                                    updateIOSStatus()
                                }
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Status").frame(width: 160, alignment: .leading)
                            Text(iosStatus.isEmpty ? "Unknown" : iosStatus).foregroundColor(.secondary)
                            Spacer()
                            Button("Export Now") { exportIOSNow() }
                            #if os(macOS)
                            Button("Export to iCloud Drive…") { dbManager.presentExportSnapshotPanel() }
                            #endif
                        }
                    }

                    CardSection(title: "Portfolio Management") {
                        NavigationLink("Theme Statuses", destination: ThemeStatusSettingsView().environmentObject(dbManager))
                        NavigationLink("News Types", destination: NewsTypeSettingsView().environmentObject(dbManager))
                        NavigationLink("Alert Trigger Types", destination: AlertTriggerTypeSettingsView().environmentObject(dbManager))
                        NavigationLink("Tags", destination: TagSettingsView().environmentObject(dbManager))
                    }

                    #if DEBUG
                    CardSection(title: "Development / Debug Options") {
                        Toggle("Bank Statement (ZKB, CS) File import. Enable Parsing Checkpoints", isOn: $enableParsingCheckpoints)
                    }
                    #endif

                    CardSection(title: "About") {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("App Version").frame(width: 160, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(GitInfoProvider.displayVersion).foregroundColor(.secondary)
                                if let branch = GitInfoProvider.branch, !branch.isEmpty {
                                    Text("Branch: \(branch)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Settings")
        .frame(minWidth: 600, idealWidth: 760, minHeight: 520)
        .onAppear {
            tempBaseCurrency = dbManager.baseCurrency
            fxAutoEnabled = dbManager.fxAutoUpdateEnabled
            fxFrequency = dbManager.fxUpdateFrequency
            updateFxStatus()
            iosAutoEnabled = dbManager.iosSnapshotAutoEnabled
            iosFrequency = dbManager.iosSnapshotFrequency
            iosTargetPath = dbManager.iosSnapshotTargetPath
            updateIOSStatus()
            #if DEBUG
            GitInfoProvider.debugDump()
            #endif
        }
        .sheet(isPresented: $showLogs) { LogViewerView().environmentObject(dbManager) }
        .alert("CoinGecko Test", isPresented: $showCGResult) {
            Button("OK", role: .cancel) { }
        } message: { Text(cgResultMessage) }
    }
}

// MARK: - ProviderKeyRow
private struct ProviderKeyRow: View {
    let label: String
    let account: String
    let placeholder: String
    @State private var temp: String = ""
    @State private var saved: Bool = false
    @State private var storeInUserDefaults: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).frame(width: 160, alignment: .leading)
            SecureField(placeholder, text: $temp)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onAppear {
                    if let v = UserDefaults.standard.string(forKey: defaultsKey), !v.isEmpty { temp = v }
                    else { temp = KeychainService.get(account: account) ?? (ProcessInfo.processInfo.environment[envKey] ?? "") }
                }
            Toggle("Store locally (UserDefaults)", isOn: $storeInUserDefaults)
                .toggleStyle(.switch)
                .help("Stores the key in app preferences (less secure, avoids Keychain prompts)")
                .frame(width: 260)
            Button(saved ? "Saved" : "Save") {
                guard !temp.isEmpty else { return }
                if storeInUserDefaults { UserDefaults.standard.set(temp, forKey: defaultsKey); saved = true }
                else { saved = KeychainService.set(temp, account: account) }
            }
            .disabled(temp.isEmpty)
            Spacer(minLength: 0)
        }
    }

    private var envKey: String {
        switch account.lowercased() {
        case "coingecko": return "COINGECKO_API_KEY"
        case "alphavantage": return "ALPHAVANTAGE_API_KEY"
        default: return account.uppercased() + "_API_KEY"
        }
    }
    private var defaultsKey: String { "api_key.\(account)" }
}

// MARK: - Card Section helper
private struct CardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Helpers
extension SettingsView {
    private func testCoinGecko() {
        guard !isTestingCG else { return }
        isTestingCG = true
        cgResultMessage = ""
        Task {
            defer { isTestingCG = false }
            guard let provider = PriceProviderRegistry.shared.provider(for: "coingecko") else {
                cgResultMessage = "Provider not found"; showCGResult = true; return
            }
            do {
                let start = Date()
                let quote = try await provider.fetchLatest(externalId: "bitcoin", expectedCurrency: "USD")
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                cgResultMessage = "Success: price=\(quote.price) \(quote.currency) asOf=\(ISO8601DateFormatter().string(from: quote.asOf)) in \(ms) ms."
            } catch let e as PriceProviderError {
                cgResultMessage = "Error: \(String(describing: e)). Check logs for details."
            } catch {
                cgResultMessage = "Error: \(error.localizedDescription). Check logs for details."
            }
            showCGResult = true
        }
    }

    private func updateFxStatus() {
        let fmtDate = DateFormatter.iso8601DateOnly
        let fmtTime = DateFormatter(); fmtTime.dateFormat = "HH:mm"
        var parts: [String] = []

        if let job = dbManager.fetchLastSystemJobRun(jobKey: .fxUpdate) {
            let timestamp = job.finishedOrStarted
            parts.append("Last: \(fmtDate.string(from: timestamp)) \(fmtTime.string(from: timestamp)) (\(job.status.displayName))")
            if let message = job.message, !message.isEmpty { parts.append(message) }
        }

        if let last = dbManager.fetchLastFxRateUpdate() {
            let freq = fxFrequency.lowercased()
            let days = (freq == "weekly") ? 7 : 1
            let next = Calendar.current.date(byAdding: .day, value: days, to: last.updateDate) ?? Date()
            var breakdown: [String] = []
            if last.status == "PARTIAL", let s = last.errorMessage, let data = s.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let arr = obj["failed"] as? [Any] { breakdown.append("failed=\(arr.count)") }
                if let arr = obj["skipped"] as? [Any] { breakdown.append("skipped=\(arr.count)") }
            }
            var statusPart = "asOf=\(fmtDate.string(from: last.updateDate)) status=\(last.status.lowercased()) updated=\(last.ratesCount)"
            if !breakdown.isEmpty { statusPart += " (\(breakdown.joined(separator: ", ")))" }
            statusPart += " via \(last.apiProvider)"
            parts.append(statusPart)
            parts.append("Next due: \(fmtDate.string(from: next)) (\(freq))")
        }

        if parts.isEmpty {
            fxLastSummary = "Never (auto-update \(fxAutoEnabled ? "enabled" : "disabled"))"
        } else {
            fxLastSummary = parts.joined(separator: " — ")
        }
    }

    private func updateIOSStatus() {
        let svc = IOSSnapshotExportService(dbManager: dbManager)
        let fmtDate = DateFormatter.iso8601DateOnly
        let fmtTime = DateFormatter(); fmtTime.dateFormat = "HH:mm"
        let freq = iosFrequency.lowercased()
        let days = (freq == "weekly") ? 7 : 1
        if let job = dbManager.fetchLastSystemJobRun(jobKey: .iosSnapshotExport) {
            let timestamp = job.finishedOrStarted
            var parts: [String] = []
            parts.append("Last: \(fmtDate.string(from: timestamp)) \(fmtTime.string(from: timestamp)) (\(job.status.displayName))")
            if let message = job.message, !message.isEmpty { parts.append(message) }
            if let target = job.metadata?["targetPath"] as? String, !target.isEmpty {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let friendly = target.hasPrefix(home) ? target.replacingOccurrences(of: home, with: "~") : target
                parts.append("Target: \(friendly)")
            }
            let next = Calendar.current.date(byAdding: .day, value: days, to: timestamp) ?? Date()
            parts.append("Next due: \(fmtDate.string(from: next)) (\(freq))")
            iosStatus = parts.joined(separator: " — ")
        } else if let fallback = svc.lastExportDate() {
            let next = Calendar.current.date(byAdding: .day, value: days, to: fallback) ?? Date()
            iosStatus = "Last: \(fmtDate.string(from: fallback)) \(fmtTime.string(from: fallback)), next due: \(fmtDate.string(from: next)) (\(freq))"
        } else {
            iosStatus = "No snapshot found. Will export on next launch if enabled."
        }
    }

    private func exportIOSNow() {
        let svc = IOSSnapshotExportService(dbManager: dbManager)
        do {
            let url = try svc.exportNow()
            iosTargetPath = svc.resolvedTargetFolder().path
            _ = dbManager.upsertConfiguration(key: "ios_snapshot_target_path", value: iosTargetPath, dataType: "string")
            updateIOSStatus()
        } catch {
            updateIOSStatus()
        }
    }
}
