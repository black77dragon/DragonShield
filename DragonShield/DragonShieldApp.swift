// DragonShield/DragonShieldApp.swift
import SwiftUI

@main
struct DragonShieldApp: App {
    @StateObject private var databaseManager: DatabaseManager
    @StateObject private var assetManager: AssetManager
    @StateObject private var healthRunner: HealthCheckRunner
    @StateObject private var ichimokuSettingsService: IchimokuSettingsService
    @StateObject private var ichimokuViewModel: IchimokuDragonViewModel
    @StateObject private var ichimokuScheduler: IchimokuScheduler

    init() {
        UserDefaults.standard.removeObject(forKey: "portfolioAttachmentsEnabled")
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.dashboardIncomingPopupShownThisLaunch)
        let dbManager = DatabaseManager()
        _databaseManager = StateObject(wrappedValue: dbManager)
        _assetManager = StateObject(wrappedValue: AssetManager())
        HealthCheckRegistry.register(DatabaseFileHealthCheck(pathProvider: { dbManager.dbFilePath }))
        // Register FX health check to display last/next FX update info
        HealthCheckRegistry.register(FXStatusHealthCheck(dbManager: dbManager))
        _healthRunner = StateObject(wrappedValue: HealthCheckRunner(enabledNames: AppConfiguration.enabledHealthChecks()))
        // Register price providers
        PriceProviderRegistry.shared.register(MockPriceProvider())
        PriceProviderRegistry.shared.register(CoinGeckoProvider())
        PriceProviderRegistry.shared.register(FinnhubProvider())
        PriceProviderRegistry.shared.register(YahooFinanceProvider())
        let settingsService = IchimokuSettingsService(dbManager: dbManager)
        let ichimokuVM = IchimokuDragonViewModel(dbManager: dbManager, settingsService: settingsService)
        _ichimokuSettingsService = StateObject(wrappedValue: settingsService)
        _ichimokuViewModel = StateObject(wrappedValue: ichimokuVM)
        _ichimokuScheduler = StateObject(wrappedValue: IchimokuScheduler(settingsService: settingsService, viewModel: ichimokuVM))
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
            .environmentObject(ichimokuSettingsService)
            .environmentObject(ichimokuViewModel)
            .environmentObject(ichimokuScheduler)
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
                // Auto-update FX on launch if enabled and stale (Option 2)
                if databaseManager.fxAutoUpdateEnabled {
                    let fxService = FXUpdateService(dbManager: databaseManager)
                    await fxService.autoUpdateOnLaunchIfStale(thresholdHours: 24, base: databaseManager.baseCurrency)
                }

                // Export iOS snapshot if the auto-export toggle is enabled and run is due
                let iosSnapshotService = IOSSnapshotExportService(dbManager: databaseManager)
                iosSnapshotService.autoExportOnLaunchIfDue()
                ichimokuScheduler.start()
            }
        }
        WindowGroup(id: "accountDetail", for: Int.self) { $accountId in
            if let id = accountId,
               let account = databaseManager.fetchAccountDetails(id: id)
            {
                AccountDetailWindowView(account: account)
                    .environmentObject(databaseManager)
                    .environmentObject(ichimokuSettingsService)
                    .environmentObject(ichimokuViewModel)
                    .environmentObject(ichimokuScheduler)
            } else {
                Text("Account not found")
            }
        }
        WindowGroup(id: "targetEdit", for: Int.self) { $classId in
            if let cid = classId {
                TargetEditPanel(classId: cid)
                    .environmentObject(databaseManager)
                    .environmentObject(ichimokuSettingsService)
                    .environmentObject(ichimokuViewModel)
                    .environmentObject(ichimokuScheduler)
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
                    .environmentObject(ichimokuSettingsService)
                    .environmentObject(ichimokuViewModel)
                    .environmentObject(ichimokuScheduler)
            } else {
                Text("Instrument not found")
            }
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(.contentSize)

        WindowGroup(id: "todoBoard") {
            TodoKanbanBoardView()
                .environmentObject(databaseManager)
        }
        .defaultSize(width: 1120, height: 720)
        .windowResizability(.contentSize)

        WindowGroup(id: "themeWorkspace", for: Int.self) { $themeId in
            if let tid = themeId {
                PortfolioThemeWorkspaceView(themeId: tid, origin: "window")
                    .environmentObject(databaseManager)
                    .environmentObject(ichimokuSettingsService)
                    .environmentObject(ichimokuViewModel)
                    .environmentObject(ichimokuScheduler)
            } else {
                Text("Theme not found")
            }
        }
        .defaultSize(width: 1750, height: 900)
        .windowResizability(.contentSize)
    }
}
