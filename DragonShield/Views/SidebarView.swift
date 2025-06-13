// DragonShield/Views/SidebarView.swift
// MARK: - Version 1.5
// MARK: - History
// - 1.4 -> 1.5: Added "Edit Account Types" navigation link.
// - 1.3 -> 1.4: Activated "Transaction History" navigation link.
// - 1.2 -> 1.3: Activated "Edit Custody Accounts" navigation link.
// - (Previous history)

import SwiftUI

struct SidebarView: View {
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
            }
            
            // MARK: - Maintenance Functions Section
            Section("Maintenance Functions") {
                HStack {
                    Label("Load Documents", systemImage: "doc.text.fill")
                        .foregroundColor(.gray)
                    Spacer()
                    Text("(coming soon)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .italic()
                }
                .onTapGesture {}
                
                NavigationLink(destination: CurrenciesView()) {
                    Label("Edit Currencies", systemImage: "dollarsign.circle.fill")
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

                // NEW: NavigationLink for Account Types
                NavigationLink(destination: AccountTypesView()) {
                    Label("Edit Account Types", systemImage: "creditcard.circle.fill")
                }
                
                NavigationLink(destination: InstrumentTypesView()) {
                    Label("Edit Instrument Types", systemImage: "folder.fill")
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
        .environmentObject(DatabaseManager()) // Ensure DBManager is available for previews if needed by linked views
    }
}
