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

    @AppStorage(UserDefaultsKeys.forceOverwriteDatabaseOnDebug)
    private var forceOverwriteDatabaseOnDebug: Bool = false

    @AppStorage(UserDefaultsKeys.enableParsingCheckpoints)
    private var enableParsingCheckpoints: Bool = false

    @AppStorage("runStartupHealthChecks")
    private var runStartupHealthChecks: Bool = true

    @AppStorage(UserDefaultsKeys.portfolioAttachmentsEnabled)
    private var portfolioAttachmentsEnabled: Bool = false
    @AppStorage(UserDefaultsKeys.instrumentNotesEnabled)
    private var instrumentNotesEnabled: Bool = false


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
    @State private var tempDefaultTimeZone: String = ""
    // For steppers/pickers, we can often bind directly to dbManager's @Published vars

    var body: some View {
        Form {
            Section(header: Text("General Application Settings")) {
                HStack {
                    Text("Base Currency")
                    Spacer()
                    TextField("e.g., CHF", text: $tempBaseCurrency)
                        .frame(width: 80)
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
                }

                Stepper("Decimal Precision: \(dbManager.decimalPrecision)",
                        value: Binding(
                            get: { dbManager.decimalPrecision },
                            set: { newValue in
                                _ = dbManager.updateConfiguration(key: "decimal_precision", value: "\(newValue)")
                            }
                        ),
                        in: 0...8)
                
                Toggle("Auto FX Update", isOn: Binding(
                    get: { dbManager.autoFxUpdate },
                    set: { newValue in
                        _ = dbManager.updateConfiguration(key: "auto_fx_update", value: newValue ? "true" : "false")
                    }
                ))

                HStack {
                    Text("Default Timezone")
                    Spacer()
                    TextField("e.g., Europe/Zurich", text: $tempDefaultTimeZone)
                        .frame(minWidth: 150)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            let newZone = tempDefaultTimeZone.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !newZone.isEmpty { // Basic validation
                                _ = dbManager.updateConfiguration(key: "default_timezone", value: newZone)
                            } else {
                                tempDefaultTimeZone = dbManager.defaultTimeZone
                            }
                        }
                }
            }
            
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
                HStack {
                    Text("Last Result")
                    Spacer()
                    Text("\(okCount) ok / \(warningCount) warning / \(errorCount) error")
                }
                NavigationLink("Detailed Report", destination: HealthCheckResultsView())
            }

            Section(header: Text("Feature Flags")) {
                Toggle("Enable Attachments for Theme Updates", isOn: $portfolioAttachmentsEnabled)
                Toggle("Enable Instrument Notes", isOn: $instrumentNotesEnabled)
            }

            Section(header: Text("Portfolio Management")) {
                NavigationLink("Theme Statuses", destination: ThemeStatusSettingsView().environmentObject(dbManager))
            }

            #if DEBUG
            Section(header: Text("Development / Debug Options")) {
                VStack(alignment: .leading) {
                    Toggle("Force Re-copy Database on Next Launch", isOn: $forceOverwriteDatabaseOnDebug)
                    Text("Enable this to delete the current database and copy a fresh version from the bundle on next app start. Only for Debug builds.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Toggle("Enable Parsing Checkpoints", isOn: $enableParsingCheckpoints)
                        .padding(.top, 4)
                }
            }
            #endif


            Section(header: Text("About")) {
                HStack {
                    Text("App Version")
                    Spacer()
                    // Use the new, reliable AppVersionProvider
                    Text(AppVersionProvider.fullVersion)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 450, idealWidth: 550, minHeight: 400)
        .onAppear {
            // Initialize temp states from dbManager's @Published properties
            tempBaseCurrency = dbManager.baseCurrency
            tempDefaultTimeZone = dbManager.defaultTimeZone
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // NOTE: You must have a `UserDefaultsKeys` struct with the appropriate key defined for this preview to work.
        UserDefaults.standard.set(true, forKey: "forceOverwriteDatabaseOnDebug")
        UserDefaults.standard.set(false, forKey: "enableParsingCheckpoints")
        let dbManager = DatabaseManager() // Create a preview instance
        let runner = HealthCheckRunner()

        return SettingsView()
            .environmentObject(dbManager)
            .environmentObject(runner)
    }
}
