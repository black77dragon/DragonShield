import SwiftUI

public struct ValidationDetailsView: View {
    public enum Scope: Identifiable {
        case `class`(id: Int, name: String)
        case subClass(id: Int, name: String)

        public var id: String {
            switch self {
            case let .class(id, _): return "class-\(id)"
            case let .subClass(id, _): return "subclass-\(id)"
            }
        }

        var title: String {
            switch self {
            case let .class(_, name): return name
            case let .subClass(_, name): return name
            }
        }
    }

    public struct Item: Identifiable {
        public let id: Int
        public let severity: String
        public let code: String
        public let message: String
        public let scopeName: String
        public let computedAt: String
    }

    private let items: [Item]
    private let scope: Scope

    public init(scope: Scope, items: [Item]) {
        self.scope = scope
        self.items = items
    }

    public var body: some View {
        NavigationView {
            List(items) { item in
                HStack(alignment: .top) {
                    Text(symbol(for: item.severity))
                        .bold()
                        .accessibilityLabel(item.severity)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.code).bold()
                        Text(item.message)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.scopeName)
                        Text(item.computedAt)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(scope.title)
        }
    }

    private func symbol(for severity: String) -> String {
        severity == "error" ? "E" : "W"
    }
}
