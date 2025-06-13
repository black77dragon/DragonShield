// DragonShield/Views/DashboardView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Added sections for Largest Positions, Asset Class Allocation, and Options. Using placeholder data.
// - Initial creation: Basic placeholder dashboard.

import SwiftUI
import Charts // For future bar chart implementation

struct DashboardView: View {
    @EnvironmentObject var dbManager: DatabaseManager // Assuming DatabaseManager is an EnvironmentObject

    @State private var largestPositions: [LargestPositionItem] = []
    @State private var assetAllocations: [AssetClassAllocationItem] = []
    @State private var optionHoldings: [OptionHoldingItem] = []
    
    // For styling, reuse defined paddings if possible
    private let sectionSpacing: CGFloat = 20
    private let tileCornerRadius: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                Text("Dashboard")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .padding(.bottom, 10)

                // Section: Top 5 Positions
                DashboardTileView(title: "Largest Positions", iconName: "star.fill", iconColor: .yellow) {
                    if largestPositions.isEmpty {
                        Text("No position data available.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(largestPositions) { position in
                                HStack {
                                    Text(position.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(position.valueInBaseCurrency, specifier: "%.2f") \(dbManager.baseCurrency)") // Assuming baseCurrency is available
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                }

                // Section: Allocation per Asset Class
                DashboardTileView(title: "Allocation by Asset Class", iconName: "chart.pie.fill", iconColor: .blue) {
                    if assetAllocations.isEmpty {
                        Text("No allocation data available.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(assetAllocations) { allocation in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(allocation.assetClassName)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(allocation.actualPercentage, specifier: "%.1f")%")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    ProgressView(value: allocation.actualPercentage, total: 100)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    // Later: Add target comparison
                                }
                            }
                        }
                        .padding()
                    }
                }

                // Section: List of all Options
                DashboardTileView(title: "Options Holdings", iconName: "arrow.triangle.branch", iconColor: .green) {
                    if optionHoldings.isEmpty {
                        Text("No options holdings found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(optionHoldings) { option in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(option.name).font(.headline)
                                        Text("Expires: \(option.expiryDate, style: .date)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("Qty: \(option.quantity, specifier: "%.0f")")
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Placeholder for the 4th tile from brief (Alerts)
                DashboardTileView(title: "Alerts", iconName: "bell.fill", iconColor: .orange) {
                    Text("Alerts will be shown here (e.g., stale prices > 30 days).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }


            }
            .padding()
        }
        .navigationTitle("Dashboard") // Keeps title in the window frame
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
        )
        .onAppear {
            loadDashboardData()
        }
    }

    func loadDashboardData() {
        self.largestPositions = dbManager.fetchLargestPositions()
        self.assetAllocations = dbManager.fetchAssetClassAllocation()
        self.optionHoldings = dbManager.fetchOptionHoldings()
    }
}

// Helper View for Dashboard Tiles
struct DashboardTileView<Content: View>: View {
    let title: String
    let iconName: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.title2)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding([.top, .leading, .trailing])
            
            content // Embeds the specific content for this tile
        }
        .background(.regularMaterial) // Glassmorphism effect
        .clipShape(RoundedRectangle(cornerRadius: 16)) // Consistent corner radius
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2) // Subtle shadow
    }
}


struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy DatabaseManager with potential config for preview
        let previewDbManager = DatabaseManager()
        // Optionally set baseCurrency if dbManager.baseCurrency is used in previews
        // previewDbManager.baseCurrency = "USD"

        DashboardView()
            .environmentObject(previewDbManager)
    }
}
