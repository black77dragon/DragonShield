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
    @State private var fxOverdue: Bool = false

    // iOS snapshot settings
    @State private var iosAutoEnabled: Bool = true
    @State private var iosFrequency: String = "daily"
    @State private var iosStatus: String = ""
    @State private var iosOverdue: Bool = false

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
                                updateFxStatus()
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
                            Text(fxLastSummary.isEmpty ? (fxAutoEnabled ? "Loading status…" : "No FX updates yet. Auto-update disabled.") : fxLastSummary)
                                .foregroundColor(fxOverdue ? .red : .secondary)
                            Spacer()
                            Button("Update FX Now") {
                                Task {
                                    let svc = FXUpdateService(dbManager: dbManager)
                                    LoggingService.shared.log("[FX][UI] Manual update requested from Settings base=\(dbManager.baseCurrency)", logger: .ui)
                                    if let summary = await svc.updateLatestForAll(base: dbManager.baseCurrency) {
                                        LoggingService.shared.log("[FX][UI] Settings update success updated=\(summary.insertedCount) failed=\(summary.failedCount) skipped=\(summary.skippedCount) asOf=\(DateFormatter.iso8601DateOnly.string(from: summary.asOf)) via=\(summary.provider)", logger: .ui)
                                    } else if let err = svc.lastError {
                                        LoggingService.shared.log("[FX][UI] Settings update failed: \(String(describing: err))", type: .error, logger: .ui)
                                    } else {
                                        LoggingService.shared.log("[FX][UI] Settings update failed: unknown error", type: .error, logger: .ui)
                                    }
                                    updateFxStatus()
                                }
                            }
                        }
                    }

                    CardSection(title: "iOS Snapshot (DB Copy for iPhone app)") {
                        Toggle("Auto-export on Launch", isOn: $iosAutoEnabled)
                            .onChange(of: iosAutoEnabled) { _, newValue in
                                _ = dbManager.upsertConfiguration(key: "ios_snapshot_auto_enabled", value: newValue ? "true" : "false", dataType: "boolean", description: "Auto-export iOS snapshot on launch")
                                updateIOSStatus()
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
                            TextField("~/Library/Mobile Documents/com~apple~CloudDocs/...",
                                      text: Binding(
                                        get: { dbManager.iosSnapshotTargetPath },
                                        set: { newValue in
                                            dbManager.iosSnapshotTargetPath = newValue
                                            _ = dbManager.upsertConfiguration(key: "ios_snapshot_target_path", value: newValue, dataType: "string", description: "Destination folder for iOS snapshot export")
                                            updateIOSStatus()
                                        })
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 300)
                            Spacer()
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("Status").frame(width: 160, alignment: .leading)
                            Text(iosStatus.isEmpty ? (iosAutoEnabled ? "Loading status…" : "No successful snapshot yet. Auto-export disabled.") : iosStatus)
                                .foregroundColor(iosOverdue ? .red : .secondary)
                            Spacer()
                            Button("Export Now") { exportIOSNow() }
                            #if os(macOS)
                            Button("Export to iCloud Drive…") { dbManager.presentExportSnapshotPanel() }
                            #endif
                        }
                    }

                    // Row: Static Data Maintenance + Table Display Settings
                    HStack(alignment: .top, spacing: 16) {
                        CardSection(title: "Static Data Maintenance") {
                            HStack(alignment: .top, spacing: 32) {
                                VStack(alignment: .leading, spacing: 8) {
                                    NavigationLink("Theme Status", destination: ThemeStatusSettingsView().environmentObject(dbManager))
                                    NavigationLink("News Types", destination: NewsTypeSettingsView().environmentObject(dbManager))
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    NavigationLink("Alert Trigger Types", destination: AlertTriggerTypeSettingsView().environmentObject(dbManager))
                                    NavigationLink("Tags", destination: TagSettingsView().environmentObject(dbManager))
                                }
                            }
                        }
                        CardSection(title: "Table Display Settings") {
                            Stepper("Row Spacing: \(String(format: "%.1f", dbManager.tableRowSpacing)) pts",
                                    value: Binding(get: { dbManager.tableRowSpacing }, set: { _ = dbManager.updateConfiguration(key: "table_row_spacing", value: String(format: "%.1f", $0)) }), in: 0.0...10.0, step: 0.5)
                            Stepper("Row Padding: \(String(format: "%.1f", dbManager.tableRowPadding)) pts",
                                    value: Binding(get: { dbManager.tableRowPadding }, set: { _ = dbManager.updateConfiguration(key: "table_row_padding", value: String(format: "%.1f", $0)) }), in: 0.0...20.0, step: 1.0)
                        }
                    }

                    #if DEBUG
                    CardSection(title: "Development / Debug Options") {
                        Toggle("Bank Statement (ZKB, CS) File import. Enable Parsing Checkpoints", isOn: $enableParsingCheckpoints)
                    }
                    #endif

                    // About section moved to SidebarView
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
            updateIOSStatus()
            #if DEBUG
            GitInfoProvider.debugDump()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FXRatesUpdated")).receive(on: RunLoop.main)) { _ in
            updateFxStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("IOSSnapshotExported")).receive(on: RunLoop.main)) { _ in
            updateIOSStatus()
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
        let fmt = DateFormatter.iso8601DateOnly
        let freq = fxFrequency.lowercased()
        let days = (freq == "weekly") ? 7 : 1
        if let last = dbManager.fetchLastFxRateUpdate() { // consider PARTIAL as a valid run for scheduling
            // Use createdAt (when the update actually ran) to compute next due
            let cal = Calendar.current
            let start = cal.startOfDay(for: last.createdAt)
            let next = cal.date(byAdding: .day, value: days, to: start) ?? Date()
            let overdue = fxAutoEnabled && Date() > next
            fxOverdue = overdue
            let nextStr = fmt.string(from: next)
            // Show both as-of date (provider) and run date for clarity
            let asOfStr = fmt.string(from: last.updateDate)
            let runStr = DateFormatter.iso8601DateTime.string(from: last.createdAt)
            fxLastSummary = "Latest: asOf=\(asOfStr) (\(last.status)) via \(last.apiProvider), updated=\(last.ratesCount); Run=\(runStr); Next due: \(nextStr) (\(freq))" + (overdue ? " — overdue by \(max(0, cal.dateComponents([.day], from: next, to: Date()).day ?? 0))d" : "")
            LoggingService.shared.log("[FX][Status] \(fxLastSummary)", logger: .ui)
        } else {
            // No updates recorded
            if fxAutoEnabled {
                fxOverdue = true
                fxLastSummary = "No FX updates yet — overdue (\(freq)). Will auto-update on launch."
            } else {
                fxOverdue = false
                fxLastSummary = "No FX updates yet. Auto-update disabled."
            }
            LoggingService.shared.log("[FX][Status] \(fxLastSummary)", logger: .ui)
        }
    }

    private func updateIOSStatus() {
        let svc = IOSSnapshotExportService(dbManager: dbManager)
        let fmtDate = DateFormatter.iso8601DateOnly
        let fmtTime = DateFormatter(); fmtTime.dateFormat = "HH:mm"
        if let last = svc.lastExportDate() {
            let freq = iosFrequency.lowercased()
            let days = (freq == "weekly") ? 7 : 1
            let next = Calendar.current.date(byAdding: .day, value: days, to: last) ?? Date()
            let due = iosAutoEnabled && svc.isDueToday(frequency: freq)
            iosOverdue = due
            var extra = due ? " — overdue" : ""
            if due {
                // Provide how overdue this is, in days
                let comps = Calendar.current.dateComponents([.day], from: next, to: Date())
                if let d = comps.day, d > 0 { extra = " — overdue by \(d)d" }
            }
            iosStatus = "Latest success: \(fmtDate.string(from: last)) \(fmtTime.string(from: last)); Next due: \(fmtDate.string(from: next)) (\(freq))\(extra)"
            LoggingService.shared.log("[iOS Snapshot][Status] \(iosStatus)", logger: .ui)
        } else {
            if iosAutoEnabled {
                iosOverdue = true
                iosStatus = "No successful snapshot yet — overdue (\(iosFrequency)). Will export on next launch."
            } else {
                iosOverdue = false
                iosStatus = "No successful snapshot yet. Auto-export disabled."
            }
            LoggingService.shared.log("[iOS Snapshot][Status] \(iosStatus)", logger: .ui)
        }
    }

    private func exportIOSNow() {
        let svc = IOSSnapshotExportService(dbManager: dbManager)
        do {
            let url = try svc.exportNow()
            dbManager.iosSnapshotTargetPath = svc.resolvedTargetFolder().path
            _ = dbManager.upsertConfiguration(key: "ios_snapshot_target_path", value: dbManager.iosSnapshotTargetPath, dataType: "string")
            iosStatus = "Exported: \(url.lastPathComponent) at \(DateFormatter.iso8601DateTime.string(from: Date()))"
        } catch {
            iosStatus = "Export failed: \(error.localizedDescription)"
        }
    }
}
