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

    @State private var showOverview = true
    @State private var showManagement = true
    @State private var showConfiguration = true
    @State private var showSystem = true

    var body: some View {
        VStack(spacing: 12) {
        List {
            DisclosureGroup("Overview", isExpanded: $showOverview) {
                NavigationLink(destination: DashboardView()) {
                    Label("Dashboard", systemImage: "chart.pie.fill")
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

                // Rebalancing link removed per request
                NavigationLink(destination: PortfolioThemesListView().environmentObject(dbManager)) {
                    Label("Portfolio Themes", systemImage: "list.bullet")
                }

                NavigationLink(destination: InstrumentPricesMaintenanceView().environmentObject(dbManager)) {
                    Label("Prices", systemImage: "dollarsign.circle")
                }

                NavigationLink(destination: AlertsSettingsView().environmentObject(dbManager)) {
                    Label("Alerts", systemImage: "bell")
                }
            }

            DisclosureGroup("Configuration", isExpanded: $showConfiguration) {
                NavigationLink(destination: InstitutionsView()) {
                    Label("Institutions", systemImage: "building.2.fill")
                }

                NavigationLink(destination: CurrenciesView()) {
                    Label("Currencies & FX", systemImage: "dollarsign.circle.fill")
                }

                NavigationLink(destination: ClassManagementView()) {
                    Label("Asset Classes", systemImage: "folder")
                }

                NavigationLink(destination: AccountTypesView().environmentObject(dbManager)) {
                    Label("Account Types", systemImage: "creditcard")
                }

                NavigationLink(destination: AccountsView()) {
                    Label("Accounts", systemImage: "building.columns.fill")
                }

                NavigationLink(destination: TransactionTypesView()) {
                    Label("Transaction Types", systemImage: "tag.circle.fill")
                }

                NavigationLink(destination: PortfolioView()) {
                    Label("Instruments", systemImage: "pencil.and.list.clipboard")
                }
            }

            DisclosureGroup("System", isExpanded: $showSystem) {
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
        aboutCard
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle("Dragon Shield")
    }
}

// MARK: - About Card
private extension SidebarView {
    var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About").font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("App Version").frame(width: 120, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(GitInfoProvider.displayVersion).foregroundColor(.secondary)
                    if let branch = GitInfoProvider.branch, !branch.isEmpty {
                        Text("Branch: \(branch)").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        let db = DatabaseManager()
        return NavigationSplitView {
            SidebarView()
        } detail: {
            DashboardView()
        }
        .environmentObject(db)
        .environmentObject(AssetManager(dbManager: db))
    }
}
