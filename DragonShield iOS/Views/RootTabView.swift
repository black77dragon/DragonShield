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
            NavigationStack { TodoBoardView() }
                .tabItem { Label("To-Dos", systemImage: "checklist") }
            NavigationStack { ThemesListView() }
                .tabItem { Label("Portfolios", systemImage: "square.grid.2x2") }
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

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(DatabaseManager())
    }
}
#endif
