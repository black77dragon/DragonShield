// DragonShield/Views/SettingsView.swift
// MARK: - Version 1.4
// MARK: - History
// - 1.3 -> 1.4: Added database information section (path, created, updated).
// - 1.2 -> 1.3: Replaced script-based versioning with a 100% Swift solution (AppVersionProvider) to fix build errors.
// - 1.1 -> 1.2: Removed redundant .onChange modifiers that were causing a state update crash loop.
// - 1.0 -> 1.1: Added editable fields for Configuration settings (base_currency, decimal_precision, etc.).

import SwiftUI

struct SettingsView: View {
    // Inject DatabaseManager to access @Published config properties
    @EnvironmentObject var dbManager: DatabaseManager
    @EnvironmentObject var runner: HealthCheckRunner

    @AppStorage(UserDefaultsKeys.enableParsingCheckpoints)
    private var enableParsingCheckpoints: Bool = false

    @AppStorage("runStartupHealthChecks")
    private var runStartupHealthChecks: Bool = true
    @AppStorage("coingeckoPreferFree")
    private var coingeckoPreferFree: Bool = false
    // Removed: legacy feature flag for instrument updates column


    private var okCount: Int {
        runner.reports.filter { if case .ok = $0.result { return true } else { return false } }.count
    }
    private var warningCount: Int {
        runner.reports.filter { if case .warning = $0.result { return true } else { return false } }.count
    }
    private var errorCount: Int {
        runner.reports.filter { if case .error = $0.result { return true } else { return false } }.count
    }

    // Local state for text fields to allow temporary editing before committing
    @State private var tempBaseCurrency: String = ""
    @State private var showLogs: Bool = false
    @State private var isTestingCG: Bool = false
    @State private var showCGResult: Bool = false
    @State private var cgResultMessage: String = ""
    // For steppers/pickers, we can often bind directly to dbManager's @Published vars

    var body: some View {
        Form {
            #if os(macOS)
            Section(header: Text("Data Export (iOS Snapshot)")) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Export Snapshot").frame(width: 160, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create a consistent, read-only SQLite snapshot for importing into the iOS app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Export to iCloud Drive…") {
                            dbManager.presentExportSnapshotPanel()
                        }
                    }
                    Spacer()
                }
            }
            #endif
            Section(header: Text("Price Providers")) {
                ProviderKeyRow(label: "CoinGecko API Key", account: "coingecko", placeholder: "Enter CoinGecko key")
                ProviderKeyRow(label: "Finnhub API Key", account: "finnhub", placeholder: "Enter Finnhub key")
                ProviderKeyRow(label: "Alpha Vantage API Key", account: "alphavantage", placeholder: "Enter Alpha Vantage key")
                Text("Keys are stored securely in your macOS Keychain. You can also set environment variables COINGECKO_API_KEY / ALPHAVANTAGE_API_KEY for development.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Prefer Free CoinGecko (don’t use API key)", isOn: $coingeckoPreferFree)
                    .help("Skips Keychain access and always uses api.coingecko.com. Good for demo/free tier.")
                Text("Tip: For convenience, keys are cached in-memory and can be stored in UserDefaults (less secure) to avoid repeated Keychain prompts.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack {
                    Spacer()
                    Button(action: testCoinGecko) {
                        if isTestingCG { ProgressView() } else { Text("Test CoinGecko") }
                    }
                    Button("View Logs") { showLogs = true }
                }
            }
            Section(header: Text("General Application Settings")) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Base Currency").frame(width: 160, alignment: .leading)
                    TextField("", text: $tempBaseCurrency)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            // Validate and save
                            let newCurrency = tempBaseCurrency.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            if newCurrency.count == 3 && newCurrency.allSatisfy({$0.isLetter}) {
                                _ = dbManager.updateConfiguration(key: "base_currency", value: newCurrency)
                            } else {
                                // Revert or show error
                                tempBaseCurrency = dbManager.baseCurrency
                            }
                        }
                    Spacer()
                }

                Stepper("Decimal Precision: \(dbManager.decimalPrecision)",
                        value: Binding(
                            get: { dbManager.decimalPrecision },
                            set: { newValue in
                                _ = dbManager.updateConfiguration(key: "decimal_precision", value: "\(newValue)")
                            }
                        ),
                        in: 0...8)
            }

            // Workspace toggle removed; new Workspace is default
            
            Section(header: Text("Table Display Settings")) {
                Stepper("Row Spacing: \(String(format: "%.1f", dbManager.tableRowSpacing)) pts",
                        value: Binding(
                            get: { dbManager.tableRowSpacing },
                            set: { newValue in
                                _ = dbManager.updateConfiguration(key: "table_row_spacing", value: String(format: "%.1f", newValue))
                            }
                        ),
                        in: 0.0...10.0, step: 0.5)
                
                Stepper("Row Padding: \(String(format: "%.1f", dbManager.tableRowPadding)) pts",
                        value: Binding(
                            get: { dbManager.tableRowPadding },
                            set: { newValue in
                                _ = dbManager.updateConfiguration(key: "table_row_padding", value: String(format: "%.1f", newValue))
                            }
                        ),
                        in: 0.0...20.0, step: 1.0)
            }

            Section(header: Text("Health Checks")) {
                Toggle("Run on Startup", isOn: $runStartupHealthChecks)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Last Result").frame(width: 160, alignment: .leading)
                    Text("\(okCount) ok / \(warningCount) warning / \(errorCount) error")
                    Spacer()
                }
                NavigationLink("Detailed Report", destination: HealthCheckResultsView())
            }

            Section(header: Text("Portfolio Management")) {
                NavigationLink("Theme Statuses", destination: ThemeStatusSettingsView().environmentObject(dbManager))
                NavigationLink("News Types", destination: NewsTypeSettingsView().environmentObject(dbManager))
                NavigationLink("Alert Trigger Types", destination: AlertTriggerTypeSettingsView().environmentObject(dbManager))
                NavigationLink("Tags", destination: TagSettingsView().environmentObject(dbManager))
            }

            #if DEBUG
            Section(header: Text("Development / Debug Options")) {
                Toggle("Bank Statement (ZKB, CS) File import. Enable Parsing Checkpoints", isOn: $enableParsingCheckpoints)
            }
            #endif


            Section(header: Text("About")) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("App Version").frame(width: 160, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        // Prefer Git tag when available; fall back to Info.plist
                        Text(GitInfoProvider.displayVersion)
                            .foregroundColor(.secondary)
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
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 450, idealWidth: 550, minHeight: 400)
        .onAppear {
            // Initialize temp states from dbManager's @Published properties
            tempBaseCurrency = dbManager.baseCurrency
            #if DEBUG
            GitInfoProvider.debugDump()
            #endif
        }
        .sheet(isPresented: $showLogs) { LogViewerView().environmentObject(dbManager) }
        .alert("CoinGecko Test", isPresented: $showCGResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cgResultMessage)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // NOTE: You must have a `UserDefaultsKeys` struct with the appropriate key defined for this preview to work.
        UserDefaults.standard.set(false, forKey: "enableParsingCheckpoints")
        let dbManager = DatabaseManager() // Create a preview instance
        let runner = HealthCheckRunner()

        return SettingsView()
            .environmentObject(dbManager)
            .environmentObject(runner)
    }
}

// MARK: - Test helpers
extension SettingsView {
    private func testCoinGecko() {
        guard !isTestingCG else { return }
        isTestingCG = true
        cgResultMessage = ""
        Task {
            defer { isTestingCG = false }
            guard let provider = PriceProviderRegistry.shared.provider(for: "coingecko") else {
                cgResultMessage = "Provider not found"
                showCGResult = true
                return
            }
            do {
                let start = Date()
                let quote = try await provider.fetchLatest(externalId: "bitcoin", expectedCurrency: "USD")
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                cgResultMessage = "Success: price=\(quote.price) \(quote.currency) asOf=\(ISO8601DateFormatter().string(from: quote.asOf)) in \(ms) ms. Check logs for host/pro/ratelimit details."
            } catch let e as PriceProviderError {
                cgResultMessage = "Error: \(String(describing: e)). Check logs for details."
            } catch {
                cgResultMessage = "Error: \(error.localizedDescription). Check logs for details."
            }
            showCGResult = true
        }
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
                    // Prefer lightweight sources to avoid prompts; KeychainService.get also caches
                    if let v = UserDefaults.standard.string(forKey: defaultsKey), !v.isEmpty {
                        temp = v
                    } else {
                        temp = KeychainService.get(account: account) ?? (ProcessInfo.processInfo.environment[envKey] ?? "")
                    }
                }
            Toggle("Store locally (UserDefaults)", isOn: $storeInUserDefaults)
                .toggleStyle(.switch)
                .help("Stores the key in app preferences (less secure, avoids Keychain prompts)")
                .frame(width: 260)
            Button(saved ? "Saved" : "Save") {
                guard !temp.isEmpty else { return }
                if storeInUserDefaults {
                    UserDefaults.standard.set(temp, forKey: defaultsKey)
                    saved = true
                } else {
                    saved = KeychainService.set(temp, account: account)
                }
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
