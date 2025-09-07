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
        PriceProviderRegistry.shared.register(YahooFinanceProvider())
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
                // Auto-update FX on launch if stale (Option 2)
                let fxService = FXUpdateService(dbManager: databaseManager)
                await fxService.autoUpdateOnLaunchIfStale(thresholdHours: 24, base: databaseManager.baseCurrency)
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

        WindowGroup(id: "instrumentDashboard", for: Int.self) { $instrumentId in
            if let iid = instrumentId {
                InstrumentDashboardWindowView(instrumentId: iid)
                    .environmentObject(databaseManager)
            } else {
                Text("Instrument not found")
            }
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(.contentSize)

        WindowGroup(id: "themeWorkspace", for: Int.self) { $themeId in
            if let tid = themeId {
                PortfolioThemeWorkspaceView(themeId: tid, origin: "window")
                    .environmentObject(databaseManager)
            } else {
                Text("Theme not found")
            }
        }
        .defaultSize(width: 1750, height: 900)
        .windowResizability(.contentSize)
    }
}
