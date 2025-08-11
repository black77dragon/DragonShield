import SwiftUI
import Database

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

    private let findings: [ValidationFinding]
    private let scope: Scope

    public init(scope: Scope, findings: [ValidationFinding]) {
        self.scope = scope
        self.findings = findings
    }

    public var body: some View {
        NavigationView {
            List(findings) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("[\(finding.severity.prefix(1).uppercased())]")
                            .bold()
                        Text(finding.code)
                            .bold()
                        Text(finding.scopeName)
                        Spacer()
                        Text(finding.computedAt)
                            .font(.caption)
                    }
                    Text(finding.message)
                }
            }
            .navigationTitle(scope.title)
        }
    }
}
