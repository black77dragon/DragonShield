// DragonShield/DragonShieldApp.swift
import SwiftUI

@main
struct DragonShieldApp: App {
    // Create a single instance of DatabaseManager to be used throughout the app
    @StateObject private var databaseManager = DatabaseManager()
    @StateObject private var assetManager = AssetManager() // Assuming you also have this

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView()
            } detail: {
                DashboardView()
            }
            .environmentObject(assetManager) // Your existing one
            .environmentObject(databaseManager) // <<<< ADD THIS LINE
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ModeBadge()
                        .environmentObject(databaseManager)
                }
            }
        }
    }
}
