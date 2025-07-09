// DragonShield/Views/SidebarView.swift
// MARK: - Version 1.9
// MARK: - History
// - 1.5 -> 1.6: Enabled "Load Documents" navigation link to point to new ImportStatementView.
// - 1.4 -> 1.5: Added "Edit Account Types" navigation link.
// - 1.6 -> 1.7: Added "Positions" navigation link.
// - 1.7 -> 1.8: Added "Edit Institutions" navigation link.
// - 1.8 -> 1.9: Converted Load Documents action back to NavigationLink with error alert support.
// - (Previous history)

import SwiftUI
import AppKit

// Access to the import parser
private let importManager = ImportManager.shared

struct SidebarView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    var body: some View {
        List {
            // MARK: - Key Features Section
            Section("Key Features") {
                NavigationLink(destination: DashboardView()) {
                    Label("Portfolio Overview", systemImage: "chart.pie.fill")
                }
                
                NavigationLink(destination: DashboardView()) {
                    Label("Asset Dashboard", systemImage: "chart.bar.fill")
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
            }
            
            // MARK: - Maintenance Functions Section
            Section("Maintenance Functions") {
                NavigationLink(destination: ImportStatementView()) {
                    Label("Load Documents", systemImage: "doc.text.fill")
                }
                
                NavigationLink(destination: CurrenciesView()) {
                    Label("Edit Currencies", systemImage: "dollarsign.circle.fill")
                }

                NavigationLink(destination: InstitutionsView()) {
                    Label("Edit Institutions", systemImage: "building.2.fill")
                }
                
                HStack {
                    Label("Edit FX History", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("(coming soon)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .italic()
                }
                .onTapGesture {}

                NavigationLink(destination: AccountTypesView()) {
                    Label("Edit Account Types", systemImage: "creditcard.circle.fill")
                }

                NavigationLink(destination: AssetClassesView()) {
                    Label("Edit Asset Classes", systemImage: "folder")
                }

                NavigationLink(destination: AssetSubClassesView()) {
                    Label("Edit Asset SubClasses", systemImage: "folder.fill")
                }

                NavigationLink(destination: TargetAllocationMaintenanceView(viewModel: TargetAllocationViewModel(dbManager: dbManager, portfolioId: 1))) {
                    Label("Edit Target Allocation", systemImage: "chart.pie")
                }
                
                NavigationLink(destination: TransactionTypesView()) {
                    Label("Edit Transaction Types", systemImage: "tag.circle.fill")
                }
                
                NavigationLink(destination: PortfolioView()) {
                    Label("Edit Instruments", systemImage: "pencil.and.list.clipboard")
                }
                
                NavigationLink(destination: CustodyAccountsView()) {
                    Label("Edit Custody Accounts", systemImage: "building.columns.fill")
                }
            }
            
            // MARK: - System Section
            Section("System") {
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                }
                
                HStack {
                    Label("Data Import/Export", systemImage: "square.and.arrow.up.on.square")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("(coming soon)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .italic()
                }
                .onTapGesture {}
                
                HStack {
                    Label("Backup & Restore", systemImage: "externaldrive.badge.timemachine")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("(coming soon)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .italic()
                }
                .onTapGesture {}
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
