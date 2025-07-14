import SwiftUI

protocol DashboardTile: View {
    init()
    static var tileID: String { get }
    static var tileName: String { get }
    static var iconName: String { get }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct ChartTile: DashboardTile {
    init() {}
    static let tileID = "chart"
    static let tileName = "Chart Tile"
    static let iconName = "chart.bar"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Color.gray.opacity(0.3)
                .frame(height: 120)
                .cornerRadius(4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ListTile: DashboardTile {
    init() {}
    static let tileID = "list"
    static let tileName = "List Tile"
    static let iconName = "list.bullet"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            VStack(alignment: .leading, spacing: 4) {
                Text("First item")
                Text("Second item")
                Text("Third item")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: DashboardTile {
    init() {}
    static let tileID = "metric"
    static let tileName = "Metric Tile"
    static let iconName = "number"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Text("123")
                .font(.system(size: 48, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(Theme.primaryAccent)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TextTile: DashboardTile {
    init() {}
    static let tileID = "text"
    static let tileName = "Text Tile"
    static let iconName = "text.alignleft"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla ut nulla sit amet massa volutpat accumsan.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ImageTile: DashboardTile {
    init() {}
    static let tileID = "image"
    static let tileName = "Image Tile"
    static let iconName = "photo"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Color.gray.opacity(0.3)
                .frame(height: 100)
                .overlay(Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray))
                .cornerRadius(4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MapTile: DashboardTile {
    init() {}
    static let tileID = "map"
    static let tileName = "Map Tile"
    static let iconName = "map"

    var body: some View {
        DashboardCard(title: Self.tileName) {
            Color.gray.opacity(0.3)
                .frame(height: 120)
                .overlay(Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.gray))
                .cornerRadius(4)
        }
        .accessibilityElement(children: .combine)
    }
}

enum TileRegistry {
    static let all: [DashboardTile.Type] = [
        ChartTile.self,
        ListTile.self,
        MetricTile.self,
        TextTile.self,
        ImageTile.self,
        MapTile.self
    ]

    static func view(for id: String) -> AnyView? {
        guard let tile = all.first(where: { $0.tileID == id }) else { return nil }
        return AnyView(tile.init())
    }

    static func info(for id: String) -> (name: String, icon: String) {
        if let tile = all.first(where: { $0.tileID == id }) {
            return (tile.tileName, tile.iconName)
        }
        return ("", "")
    }
}
