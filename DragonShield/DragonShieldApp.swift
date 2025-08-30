// DragonShield/DragonShieldApp.swift
import SwiftUI

@main
struct DragonShieldApp: App {
    @StateObject private var databaseManager: DatabaseManager
    @StateObject private var assetManager: AssetManager
    @StateObject private var healthRunner: HealthCheckRunner

    init() {
        UserDefaults.standard.removeObject(forKey: "portfolioAttachmentsEnabled")
        let dbManager = DatabaseManager()
        _databaseManager = StateObject(wrappedValue: dbManager)
        _assetManager = StateObject(wrappedValue: AssetManager())
        HealthCheckRegistry.register(DatabaseFileHealthCheck(pathProvider: { dbManager.dbFilePath }))
        _healthRunner = StateObject(wrappedValue: HealthCheckRunner(enabledNames: AppConfiguration.enabledHealthChecks()))
        // Register price providers
        PriceProviderRegistry.shared.register(MockPriceProvider())
        PriceProviderRegistry.shared.register(CoinGeckoProvider())
        PriceProviderRegistry.shared.register(FinnhubProvider())
    }

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView()
            } detail: {
                DashboardView()
            }
            .environmentObject(assetManager) // Your existing one
            .environmentObject(databaseManager) // <<<< ADD THIS LINE
            .environmentObject(healthRunner)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ModeBadge()
                        .environmentObject(databaseManager)
                }
            }
            .task {
                if AppConfiguration.runStartupHealthChecks() {
                    await healthRunner.runAll()
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
