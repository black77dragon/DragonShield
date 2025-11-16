// DragonShield/Views/SettingsView.swift

// MARK: - Version 1.5 (UI Refactor)

import SwiftUI
#if os(macOS)
    import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var runner: HealthCheckRunner

    @AppStorage(UserDefaultsKeys.enableParsingCheckpoints) private var enableParsingCheckpoints: Bool = false
    @AppStorage("coingeckoPreferFree") private var coingeckoPreferFree: Bool = false
    @AppStorage(UserDefaultsKeys.dashboardShowIncomingDeadlinesEveryVisit) private var showIncomingDeadlinesEveryVisit: Bool = true

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
    @State private var fxLastSummary: String = ""

    // iOS snapshot settings
    @State private var iosTargetPath: String = ""
    @State private var iosStatus: String = ""

    var body: some View {
        ZStack {
            Color.gray.opacity(0.06).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
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
                                    value: Binding(get: { dbManager.decimalPrecision }, set: { _ = dbManager.updateConfiguration(key: "decimal_precision", value: "\($0)") }), in: 0 ... 8)
                            Divider().padding(.vertical, 2)
                            Toggle("Show \"Incoming Deadlines\" pop-up every time Dashboard opens", isOn: $showIncomingDeadlinesEveryVisit)
                            HStack {
                                Text("Last Result").frame(width: 160, alignment: .leading)
                                Text("\(okCount) ok / \(warningCount) warning / \(errorCount) error")
                                Spacer()
                                NavigationLink("Detailed Report", destination: HealthCheckResultsView())
                            }
                        }
                        .frame(maxWidth: .infinity)

                        CardSection(title: "Table Display Settings") {
                            Stepper("Row Spacing: \(String(format: "%.1f", dbManager.tableRowSpacing)) pts",
                                    value: Binding(get: { dbManager.tableRowSpacing }, set: { _ = dbManager.updateConfiguration(key: "table_row_spacing", value: String(format: "%.1f", $0)) }), in: 0.0 ... 10.0, step: 0.5)
                            Stepper("Row Padding: \(String(format: "%.1f", dbManager.tableRowPadding)) pts",
                                    value: Binding(get: { dbManager.tableRowPadding }, set: { _ = dbManager.updateConfiguration(key: "table_row_padding", value: String(format: "%.1f", $0)) }), in: 0.0 ... 20.0, step: 1.0)
                        }
                        .frame(maxWidth: .infinity)
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

                    HStack(alignment: .top, spacing: 16) {
                        CardSection(title: "FX Updates") {
                            Toggle("Auto-update on Launch", isOn: Binding(
                                get: { dbManager.fxAutoUpdateEnabled },
                                set: { newValue in
                                    guard dbManager.fxAutoUpdateEnabled != newValue else { return }
                                    dbManager.fxAutoUpdateEnabled = newValue
                                    _ = dbManager.upsertConfiguration(key: "fx_auto_update_enabled", value: newValue ? "true" : "false", dataType: "boolean", description: "Auto-update exchange rates on app launch")
                                    updateFxStatus()
                                }
                            ))
                            .toggleStyle(.switch)
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("Frequency").frame(width: 160, alignment: .leading)
                                Picker("", selection: Binding(
                                    get: { dbManager.fxUpdateFrequency },
                                    set: { newValue in
                                        let value = (newValue == "weekly") ? "weekly" : "daily"
                                        guard dbManager.fxUpdateFrequency != value else { return }
                                        dbManager.fxUpdateFrequency = value
                                        _ = dbManager.upsertConfiguration(key: "fx_update_frequency", value: value, dataType: "string", description: "FX auto-update frequency (daily|weekly)")
                                        updateFxStatus()
                                    }
                                )) { Text("Daily").tag("daily"); Text("Weekly").tag("weekly") }
                                    .pickerStyle(.segmented)
                                    .frame(width: 240)
                                Spacer()
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("Status").frame(width: 160, alignment: .leading)
                                Text(fxLastSummary.isEmpty ? "No updates yet" : fxLastSummary).foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)

                        CardSection(title: "iOS Snapshot (DB Copy for iPhone app)") {
                            Toggle("Create iOS DB Snapshot", isOn: Binding(
                                get: { dbManager.iosSnapshotAutoEnabled },
                                set: { newValue in
                                    guard dbManager.iosSnapshotAutoEnabled != newValue else { return }
                                    dbManager.iosSnapshotAutoEnabled = newValue
                                    _ = dbManager.upsertConfiguration(key: "ios_snapshot_auto_enabled", value: newValue ? "true" : "false", dataType: "boolean", description: "Auto-export iOS snapshot on launch")
                                    updateIOSStatus()
                                }
                            ))
                            .toggleStyle(.switch)
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("Frequency").frame(width: 160, alignment: .leading)
                                Picker("", selection: Binding(
                                    get: { dbManager.iosSnapshotFrequency },
                                    set: { newValue in
                                        let value = (newValue == "weekly") ? "weekly" : "daily"
                                        guard dbManager.iosSnapshotFrequency != value else { return }
                                        dbManager.iosSnapshotFrequency = value
                                        _ = dbManager.upsertConfiguration(key: "ios_snapshot_frequency", value: value, dataType: "string", description: "iOS snapshot export frequency (daily|weekly)")
                                        updateIOSStatus()
                                    }
                                )) { Text("Daily").tag("daily"); Text("Weekly").tag("weekly") }
                                    .pickerStyle(.segmented)
                                    .frame(width: 240)
                                Spacer()
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("Destination").frame(width: 160, alignment: .leading)
                                TextField("~/Library/Mobile Documents/com~apple~CloudDocs/...", text: $iosTargetPath)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 300)
                                    .onSubmit {
                                        let trimmed = iosTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
                                        let previous = dbManager.iosSnapshotTargetPath
                                        iosTargetPath = trimmed
                                        dbManager.iosSnapshotTargetPath = trimmed
                                        _ = dbManager.upsertConfiguration(key: "ios_snapshot_target_path", value: trimmed, dataType: "string", description: "Destination folder for iOS snapshot export")
                                        #if os(macOS)
                                            if trimmed != previous { dbManager.clearIOSSnapshotBookmark() }
                                        #endif
                                        updateIOSStatus()
                                    }
                                #if os(macOS)
                                    Button("Select Path…") { selectIOSSnapshotDestination() }
                                #endif
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
                        .frame(maxWidth: .infinity)
                    }

                    #if DEBUG
                        CardSection(title: "Development / Debug Options") {
                            Toggle("Bank Statement (ZKB, CS) File import. Enable Parsing Checkpoints", isOn: $enableParsingCheckpoints)
                        }
                    #endif

                    CardSection(title: "About") {
                        HStack(alignment: .top, spacing: 12) {
                            Text("App Version").frame(width: 160, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("VERSION")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(AppVersionProvider.version)
                                        .font(.callout)
                                }
                                if let lastChange = GitInfoProvider.lastChangeSummary, !lastChange.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("VERSION_LAST_CHANGE")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(lastChange)
                                            .font(.callout)
                                    }
                                }
                                if let branch = GitInfoProvider.branch, !branch.isEmpty {
                                    Text("Branch: \(branch)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
            updateFxStatus()
            iosTargetPath = dbManager.iosSnapshotTargetPath
            updateIOSStatus()
            #if DEBUG
                GitInfoProvider.debugDump()
            #endif
        }
        .onChange(of: dbManager.fxAutoUpdateEnabled) { _, _ in
            updateFxStatus()
        }
        .onChange(of: dbManager.fxUpdateFrequency) { _, _ in
            updateFxStatus()
        }
        .onChange(of: dbManager.iosSnapshotAutoEnabled) { _, _ in
            updateIOSStatus()
        }
        .onChange(of: dbManager.iosSnapshotFrequency) { _, _ in
            updateIOSStatus()
        }
        .onChange(of: dbManager.iosSnapshotTargetPath) { _, newValue in
            if iosTargetPath != newValue {
                iosTargetPath = newValue
            }
        }
        .sheet(isPresented: $showLogs) { LogViewerView().environmentObject(dbManager) }
        .alert("CoinGecko Test", isPresented: $showCGResult) {
            Button("OK", role: .cancel) {}
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
    #if os(macOS)
        private func selectIOSSnapshotDestination() {
            let panel = NSOpenPanel()
            panel.prompt = "Select"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            if !iosTargetPath.isEmpty {
                panel.directoryURL = URL(fileURLWithPath: iosTargetPath, isDirectory: true)
            } else {
                let svc = IOSSnapshotExportService(dbManager: dbManager)
                panel.directoryURL = svc.defaultTargetFolder()
            }
            if panel.runModal() == .OK, let url = panel.url {
                _ = dbManager.setIOSSnapshotTargetFolder(url)
                iosTargetPath = url.path
                updateIOSStatus()
            }
        }
    #endif

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
            let freq = dbManager.fxUpdateFrequency.lowercased()
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
            fxLastSummary = "Never (auto-update \(dbManager.fxAutoUpdateEnabled ? "enabled" : "disabled"))"
        } else {
            fxLastSummary = parts.joined(separator: " — ")
        }
    }

    private func updateIOSStatus() {
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
        #if os(macOS)
            let trimmed = dbManager.iosSnapshotTargetPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, dbManager.iosSnapshotTargetBookmark == nil {
                let advisory = "Select Path to authorise folder access"
                iosStatus = iosStatus.isEmpty ? advisory : iosStatus + " — " + advisory
            }
        #endif
    }

    private func exportIOSNow() {
        let svc = IOSSnapshotExportService(dbManager: dbManager)
        do {
            _ = try svc.exportNow()
            iosTargetPath = svc.resolvedTargetFolder().path
            _ = dbManager.upsertConfiguration(key: "ios_snapshot_target_path", value: iosTargetPath, dataType: "string")
            updateIOSStatus()
        } catch {
            updateIOSStatus()
        }
    }
}
