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
                }
            }

            DisclosureGroup("Management", isExpanded: $showManagement) {
                NavigationLink(destination: AllocationDashboardView()) {
                    Label("Asset Allocation", systemImage: "chart.pie")
                }

                NavigationLink(destination: TargetAllocationMaintenanceView()) {
                    Label("Legacy Asset Allocation", systemImage: "clock.arrow.circlepath")
                }

                NavigationLink(destination: RebalancingView()) {
                    Label("Rebalancing", systemImage: "arrow.left.arrow.right")
                }

                NavigationLink(destination: ToDoKanbanView()) {
                    Label("To-Do Board", systemImage: "checklist")
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
