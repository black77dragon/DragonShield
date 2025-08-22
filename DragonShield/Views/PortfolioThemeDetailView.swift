// DragonShield/Views/PortfolioThemeDetailView.swift
// Simplified detail view with Composition, Valuation, and Updates tabs.

import SwiftUI

struct PortfolioThemeDetailView: View {
    enum Tab: String { case composition, valuation, updates }

    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let origin: String
    var initialTab: Tab
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Tab
    @State private var theme: PortfolioTheme?
    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var showNewUpdate = false

    private static let lastTabKey = "PortfolioThemeDetailView.lastTab"

    init(themeId: Int, origin: String, initialTab: Tab = .composition) {
        self.themeId = themeId
        self.origin = origin
        self.initialTab = initialTab
        let saved = UserDefaults.standard.string(forKey: Self.lastTabKey).flatMap(Tab.init) ?? .composition
        _selectedTab = State(initialValue: initialTab == .composition ? saved : initialTab)
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Tab", selection: $selectedTab) {
                    Text("Composition").tag(Tab.composition)
                    Text("Valuation").tag(Tab.valuation)
                    Text("Updates").tag(Tab.updates)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case .composition:
                    Text("Composition content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                case .valuation:
                    Text("Valuation content")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                case .updates:
                    updatesTab
                }

                Divider()
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                }
                .padding()
            }
            .navigationTitle("Portfolio Theme Details")
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            loadTheme()
            loadUpdates()
            LoggingService.shared.log("details_open themeId=\(themeId) tab=\(selectedTab.rawValue) source=\(origin)", logger: .ui)
        }
        .onChange(of: selectedTab) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.lastTabKey)
        }
        .sheet(isPresented: $showNewUpdate) {
            if let theme = theme {
                NewThemeUpdateView(theme: theme, onSave: { update in
                    updates.insert(update, at: 0)
                }, onCancel: {})
                .environmentObject(dbManager)
            }
        }
    }

    private var updatesTab: some View {
        VStack(alignment: .leading) {
            if let theme = theme, theme.archivedAt != nil {
                Text("Theme archived — composition locked; updates permitted")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
            }
            HStack {
                Button("+ New Update") { showNewUpdate = true }
                    .disabled(theme == nil)
                Spacer()
            }
            List(updates) { upd in
                VStack(alignment: .leading) {
                    Text("\(upd.createdAt) • \(upd.author) • \(upd.type.rawValue)")
                        .font(.caption)
                    Text(upd.title).bold()
                    Text(upd.bodyText).lineLimit(2)
                }
            }
        }
        .padding()
        .onAppear { loadUpdates() }
    }

    private func loadTheme() {
        theme = dbManager.getPortfolioTheme(id: themeId)
    }

    private func loadUpdates() {
        updates = dbManager.listThemeUpdates(themeId: themeId)
    }
}
