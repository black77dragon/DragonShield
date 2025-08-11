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

    private let findings: [ValidationFinding]
    private let scope: Scope

    public init(scope: Scope, findings: [ValidationFinding]) {
        self.scope = scope
        self.findings = findings
    }

    public var body: some View {
        NavigationView {
            List(findings) { finding in
                HStack(alignment: .top, spacing: 8) {
                    Text(icon(for: finding.severity))
                        .bold()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.code).bold()
                        Text(finding.message)
                        Text(scopeName(for: finding))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(finding.computedAt)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(scope.title)
        }
    }

    private func icon(for severity: String) -> String {
        switch severity {
        case "error": return "E"
        case "warning": return "W"
        default: return ""
        }
    }

    private func scopeName(for finding: ValidationFinding) -> String {
        if finding.entityType == "subclass" {
            return finding.subClassName ?? ""
        } else {
            return scope.title
        }
    }
}

