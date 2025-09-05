#if os(iOS)
import SwiftUI

@main
struct DragonShield_iOSApp: App {
    @StateObject private var dbManager = DatabaseManager()
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dbManager)
        }
    }
}
#endif
