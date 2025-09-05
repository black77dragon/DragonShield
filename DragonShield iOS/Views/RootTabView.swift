// Scaffolding: Root tab bar for iOS app
#if os(iOS)
import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var showSnapshotGate = false
    var body: some View {
        TabView {
            NavigationStack { IOSDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2") }
            NavigationStack { ThemesListView() }
                .tabItem { Label("Themes", systemImage: "square.grid.2x2") }
            NavigationStack { InstrumentsListView() }
                .tabItem { Label("Instruments", systemImage: "list.bullet") }
            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            NavigationStack { IOSSettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear { showSnapshotGate = dbManager.dbFilePath.isEmpty }
        .sheet(isPresented: $showSnapshotGate) {
            SnapshotGateView(onContinue: { showSnapshotGate = false })
                .environmentObject(dbManager)
        }
    }
}

// Minimal placeholders
struct DashboardView: View { var body: some View { Text("Welcome to DragonShield iOS").padding() } }
struct SearchView: View { @State private var q = ""; var body: some View { VStack { TextField("Search", text: $q).textFieldStyle(.roundedBorder).padding(); Spacer() } .navigationTitle("Search") } }

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View { RootTabView() }
}
#endif
