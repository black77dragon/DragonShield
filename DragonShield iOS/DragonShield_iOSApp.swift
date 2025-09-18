#if os(iOS)
import SwiftUI

@main
struct DragonShield_iOSApp: App {
    @StateObject private var dbManager = DatabaseManager()

    init() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.dashboardIncomingPopupShownThisLaunch)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dbManager)
        }
    }
}
#endif
