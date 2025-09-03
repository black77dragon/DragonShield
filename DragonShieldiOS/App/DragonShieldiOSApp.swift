// Scaffolding for the iOS app target (to be added in Xcode)
#if os(iOS)
import SwiftUI

@main
struct DragonShieldiOSApp: App {
    @StateObject private var dbManager = DatabaseManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dbManager)
        }
    }
}
#endif

