// DragonShield/Views/SidebarView.swift
// MARK: - Version 1.9
// MARK: - History
// - 1.4 -> 1.5: Added "Edit Account Types" navigation link.
// - 1.5 -> 1.6: Added "Positions" navigation link.
// - 1.6 -> 1.7: Added "Edit Institutions" navigation link.
// - 1.7 -> 1.8: Added Data Import/Export view to replace the old document loader.
// - (Previous history)

import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @AppStorage("sidebar.showOverview") private var showOverview = true
    @AppStorage("sidebar.showManagement") private var showManagement = true
    @AppStorage("sidebar.showConfiguration") private var showConfiguration = true
    @AppStorage("sidebar.showStaticData") private var showStaticData = true
    @AppStorage("sidebar.showSystem") private var showSystem = true

    private var applicationStartupIconName: String {
        if #available(macOS 13.0, iOS 16.0, *) {
            return "rocket.fill"
        } else {
            return "paperplane.fill"
        }
    }

    var body: some View {
        List {
            DisclosureGroup("Overview", isExpanded: $showOverview) {
                NavigationLink(destination: DashboardView()) {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }

                NavigationLink(destination: IchimokuDragonView()) {
                    Label("Ichimoku Dragon", systemImage: "cloud.sun.rain")
                }

                NavigationLink(destination: PositionsView()) {
                    Label("Positions", systemImage: "tablecells")
                }

                NavigationLink(destination: PerformanceView()) {
                    Label("Performance", systemImage: "chart.bar.fill")
                        .foregroundColor(.gray)
                }
                .disabled(true)
            }

            DisclosureGroup("Management", isExpanded: $showManagement) {
                NavigationLink(destination: AllocationDashboardView()) {
                    Label("Asset Allocation", systemImage: "chart.pie")
                }

                NavigationLink(destination: RebalancingView()) {
                    Label("Rebalancing", systemImage: "arrow.left.arrow.right")
                        .foregroundColor(.gray)
                }
                .disabled(true)
                NavigationLink(destination: PortfolioThemesListView().environmentObject(dbManager)) {
                    Label("Portfolio Themes", systemImage: "list.bullet")
                }

                NavigationLink(destination: InstrumentPricesMaintenanceView().environmentObject(dbManager)) {
                    Label("Prices", systemImage: "dollarsign.circle")
                }

                NavigationLink(destination: AlertsSettingsView().environmentObject(dbManager)) {
                    Label("Alerts & Events", systemImage: "bell")
                }

                NavigationLink(destination: TradesHistoryView().environmentObject(dbManager)) {
                    Label("Transactions", systemImage: "list.bullet.rectangle.portrait")
                }
            }

            DisclosureGroup("Configuration", isExpanded: $showConfiguration) {
                NavigationLink(destination: InstitutionsView()) {
                    Label("Institutions", systemImage: "building.2.fill")
                }

                NavigationLink(destination: CurrenciesView()) {
                    Label("Currencies & FX", systemImage: "dollarsign.circle.fill")
                }

                NavigationLink(destination: AccountsView()) {
                    Label("Accounts", systemImage: "building.columns.fill")
                }

                NavigationLink(destination: PortfolioView()) {
                    Label("Instruments", systemImage: "pencil.and.list.clipboard")
                }
            }

            DisclosureGroup("Static Data", isExpanded: $showStaticData) {
                NavigationLink(destination: ClassManagementView()) {
                    Label("Asset Classes", systemImage: "folder")
                }

                NavigationLink(destination: AccountTypesView().environmentObject(dbManager)) {
                    Label("Account Types", systemImage: "creditcard")
                }

                NavigationLink(destination: TransactionTypesView()) {
                    Label("Transaction Types", systemImage: "tag.circle.fill")
                }

                NavigationLink(destination: ThemeStatusSettingsView().environmentObject(dbManager)) {
                    Label("Theme Statuses", systemImage: "paintpalette")
                }

                NavigationLink(destination: NewsTypeSettingsView().environmentObject(dbManager)) {
                    Label("News Types", systemImage: "newspaper")
                }

                NavigationLink(destination: AlertTriggerTypeSettingsView().environmentObject(dbManager)) {
                    Label("Alert Trigger Types", systemImage: "bell.badge")
                }

                NavigationLink(destination: TagSettingsView().environmentObject(dbManager)) {
                    Label("Tags", systemImage: "tag.fill")
                }
            }

            DisclosureGroup("System", isExpanded: $showSystem) {
                NavigationLink(destination: ApplicationStartupView()) {
                    Label("Application Start Up", systemImage: applicationStartupIconName)
                }

                NavigationLink(destination: DataImportExportView()) {
                    Label("Data Import/Export", systemImage: "square.and.arrow.up.on.square")
                }

                NavigationLink(destination: DatabaseManagementView()) {
                    Label("Database Management", systemImage: "externaldrive.badge.timemachine")
                }


                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Dragon Shield")
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DashboardView()
        }
        .environmentObject(DatabaseManager())
        .environmentObject(AssetManager())
    }
}
