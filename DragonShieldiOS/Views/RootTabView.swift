// Scaffolding: Root tab bar for iOS app
#if os(iOS)
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
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
    }
}

// Minimal placeholders
struct DashboardView: View { var body: some View { Text("Dashboard").padding() } }
struct ThemesListView: View { var body: some View { Text("Themes").padding() } }
struct InstrumentsListView: View { var body: some View { Text("Instruments").padding() } }
struct SearchView: View { var body: some View { Text("Search").padding() } }

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View { RootTabView() }
}
#endif

