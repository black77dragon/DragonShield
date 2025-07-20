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

    var body: some View {
        List {
            // MARK: - Key Features Section
            Section("Key Features") {
                NavigationLink(destination: DashboardView()) {
                    Label("Portfolio Overview", systemImage: "chart.pie.fill")
                }
                
                NavigationLink(destination: TransactionsView()) {
                    Label("Transactions", systemImage: "list.bullet.rectangle.portrait")
                }
                
                NavigationLink(destination: TransactionHistoryView()) {
                    Label("Transaction History", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink(destination: PositionsView()) {
                    Label("Positions", systemImage: "tablecells")
                }

                NavigationLink(destination: TargetAllocationMaintenanceView()) {
                    Label("Target Asset Allocation", systemImage: "chart.pie")
                }

            }
            
            // MARK: - Maintenance Functions Section
            Section("Maintenance Functions") {
                
                NavigationLink(destination: InstitutionsView()) {
                    Label("Edit Institutions", systemImage: "building.2.fill")
                }

                NavigationLink(destination: CurrenciesView()) {
                    Label("Currency Maintenance", systemImage: "dollarsign.circle.fill")
                }

                NavigationLink(destination: ExchangeRatesView()) {
                    Label("Edit FX History", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationLink(destination: AccountTypesView()) {
                    Label("Edit Account Types", systemImage: "creditcard.circle.fill")
                }

                NavigationLink(destination: AssetClassesView()) {
                    Label("Edit Asset Classes", systemImage: "folder")
                }

                NavigationLink(destination: AssetSubClassesView()) {
                    Label("Edit Asset SubClasses", systemImage: "folder.fill")
                }

                NavigationLink(destination: TransactionTypesView()) {
                    Label("Edit Transaction Types", systemImage: "tag.circle.fill")
                }
                
                NavigationLink(destination: PortfolioView()) {
                    Label("Edit Instruments", systemImage: "pencil.and.list.clipboard")
                }
                
                NavigationLink(destination: AccountsView()) {
                    Label("Edit Accounts", systemImage: "building.columns.fill")
                }
            }
            
            // MARK: - System Section
            Section("System") {
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
                
                NavigationLink(destination: DataImportExportView()) {
                    Label("Data Import/Export", systemImage: "square.and.arrow.up.on.square")
                }

                NavigationLink(destination: ImportSessionHistoryView()) {
                    Label("Import Session History", systemImage: "clock.arrow.circlepath")
                }

                NavigationLink(destination: DatabaseManagementView()) {
                    Label("Database Management", systemImage: "externaldrive.badge.timemachine")
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
