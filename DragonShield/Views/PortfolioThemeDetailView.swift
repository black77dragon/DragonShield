import SwiftUI

struct PortfolioThemeDetailView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    let themeId: Int
    let origin: String
    @Environment(\.dismiss) private var dismiss

    enum Tab: String { case composition, valuation, updates }

    @AppStorage("PortfolioThemeDetailView.lastTab") private var lastTab: String = Tab.composition.rawValue
    @State private var selectedTab: Tab = .composition

    @State private var theme: PortfolioTheme?
    @State private var valuation: ValuationSnapshot?
    @State private var updates: [PortfolioThemeUpdate] = []
    @State private var showNewUpdate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isArchived {
                    Text("Theme archived — composition locked; updates permitted")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                }
                TabView(selection: $selectedTab) {
                    compositionTab
                        .tag(Tab.composition)
                        .tabItem { Text("Composition") }
                    valuationTab
                        .tag(Tab.valuation)
                        .tabItem { Text("Valuation") }
                    if dbManager.portfolioThemeUpdatesEnabled {
                        updatesTab
                            .tag(Tab.updates)
                            .tabItem { Text("Updates") }
                    }
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding(16)
            }
            .navigationTitle("Portfolio Theme Details: \(theme?.name ?? "")")
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadTheme()
            valuation = PortfolioValuationService(dbManager: dbManager, fxService: FXConversionService(dbManager: dbManager)).snapshot(themeId: themeId)
            if dbManager.portfolioThemeUpdatesEnabled { updates = dbManager.listThemeUpdates(themeId: themeId) }
            if origin == "post_create" {
                selectedTab = .updates
            } else {
                selectedTab = Tab(rawValue: lastTab) ?? .composition
            }
            LoggingService.shared.log("details_open themeId=\(themeId) tab=\(selectedTab.rawValue) source=\(origin)", logger: .database)
        }
        .onChange(of: selectedTab) { _, newVal in lastTab = newVal.rawValue }
        .sheet(isPresented: $showNewUpdate) {
            if let theme = theme {
                NewThemeUpdateView(theme: theme, valuation: valuation) { _ in
                    updates = dbManager.listThemeUpdates(themeId: themeId)
                } onCancel: {}
                .environmentObject(dbManager)
            }
        }
    }

    private var isArchived: Bool { theme?.archivedAt != nil }

    private var compositionTab: some View {
        ScrollView { Text("Composition view unavailable in this preview.") }
            .padding(24)
    }

    private var valuationTab: some View {
        ScrollView { Text("Valuation view unavailable in this preview.") }
            .padding(24)
    }

    private var updatesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button("+ New Update") { showNewUpdate = true }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Create new update")
                ForEach(updates) { update in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(update.createdAt) • \(update.author) • \(update.type.rawValue)")
                            .font(.caption)
                        Text(update.title).font(.headline)
                        Text(update.bodyText)
                        Text("Breadcrumb: Positions \(update.positionsAsOf ?? "—") • Total CHF \(update.totalValueChf.map { String(format: "%.2f", $0) } ?? "—")")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(24)
        }
    }

    private func loadTheme() {
        theme = dbManager.getPortfolioTheme(id: themeId)
    }
}
