// DragonShield/DragonShieldApp.swift
import SwiftUI

@main
struct DragonShieldApp: App {
    // Share a single DatabaseManager across the app and asset manager
    @StateObject private var databaseManager: DatabaseManager
    @StateObject private var assetManager: AssetManager

    init() {
        let dbManager = DatabaseManager()
        _databaseManager = StateObject(wrappedValue: dbManager)
        _assetManager = StateObject(wrappedValue: AssetManager(dbManager: dbManager))
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
