#if os(iOS)
import SwiftUI

@main
struct DragonShield_iOSApp: App {
    @StateObject private var dbManager = DatabaseManager()
    @AppStorage("ios.fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.standard.rawValue

    init() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.dashboardIncomingPopupShownThisLaunch)
    }

    private var fontSizePreference: FontSizePreference { FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .standard }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dbManager)
                .dynamicTypeSize(fontSizePreference.dynamicTypeSize)
        }
    }
}
#endif
