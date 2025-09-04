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
