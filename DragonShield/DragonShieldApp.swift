// DragonShield/DragonShieldApp.swift
import SwiftUI

@main
struct DragonShieldApp: App {
    // Create single shared instances injected across the app
    @StateObject private var databaseManager: DatabaseManager
    @StateObject private var assetManager: AssetManager

    init() {
        let db = DatabaseManager()
        _databaseManager = StateObject(wrappedValue: db)
        _assetManager = StateObject(wrappedValue: AssetManager(dbManager: db))
    }

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView()
            } detail: {
                DashboardView()
            }
            .environmentObject(assetManager)
            .environmentObject(databaseManager)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ModeBadge()
                        .environmentObject(databaseManager)
                }
            }
        }
        WindowGroup(id: "accountDetail", for: Int.self) { $accountId in
            if let id = accountId,
               let account = databaseManager.fetchAccountDetails(id: id) {
                AccountDetailWindowView(account: account)
                    .environmentObject(databaseManager)
            } else {
                Text("Account not found")
            }
        }
        WindowGroup(id: "targetEdit", for: Int.self) { $classId in
            if let cid = classId {
                TargetEditPanel(classId: cid)
                    .environmentObject(databaseManager)
            } else {
                Text("Asset class not found")
            }
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
    }
}
