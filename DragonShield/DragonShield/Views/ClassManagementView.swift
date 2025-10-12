import SwiftUI

/// Combines asset class and subclass management into one page.
struct ClassManagementView: View {
    var body: some View {
        TabView {
            AssetClassesView()
                .tabItem {
                    Label("Classes", systemImage: "folder")
                }

            AssetSubClassesView()
                .tabItem {
                    Label("Sub Classes", systemImage: "folder.circle")
                }
        }
        .navigationTitle("Class Management")
    }
}

struct ClassManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ClassManagementView()
            .environmentObject(DatabaseManager())
    }
}
