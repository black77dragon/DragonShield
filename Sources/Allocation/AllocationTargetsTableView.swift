import SwiftUI

@MainActor
public final class AllocationTargetsTableViewModel: ObservableObject {
    public struct SubClassItem: Identifiable {
        public let id: Int
        public let name: String
        public var validationStatus: String
    }

    public struct ClassItem: Identifiable {
        public let id: Int
        public let name: String
        public var validationStatus: String
        public var subClasses: [SubClassItem]
    }

    @Published public var classes: [ClassItem]

    public init(classes: [ClassItem]) {
        self.classes = classes
    }

    public func load(using db: DBGateway) {
        let classStatuses = db.fetchClassValidationStatuses()
        let subStatuses = db.fetchSubClassValidationStatuses()
        classes = classes.map { cls in
            var updated = cls
            updated.validationStatus = classStatuses[cls.id] ?? "compliant"
            updated.subClasses = cls.subClasses.map { sub in
                var s = sub
                s.validationStatus = subStatuses[sub.id] ?? "compliant"
                return s
            }
            return updated
        }
    }

    public func details(for scope: ValidationDetailsView.Scope, db: DBGateway) -> [ValidationDetailsView.Item] {
        let findings: [ValidationFinding]
        switch scope {
        case let .class(id, _):
            findings = db.fetchValidationFindingsForClass(id)
        case let .subClass(id, _):
            findings = db.fetchValidationFindingsForSubClass(id)
        }
        guard !findings.isEmpty else {
            downgrade(scope: scope)
            return []
        }
        return findings.map { finding in
            let name: String
            if finding.entityType == "class" {
                name = classes.first { $0.id == finding.entityId }?.name ?? ""
            } else {
                name = nameForSubClass(id: finding.entityId) ?? ""
            }
            return ValidationDetailsView.Item(
                id: finding.id,
                severity: finding.severity,
                code: finding.code,
                message: finding.message,
                scopeName: name,
                computedAt: finding.computedAt
            )
        }
    }

    private func nameForSubClass(id: Int) -> String? {
        for cls in classes {
            if let sub = cls.subClasses.first(where: { $0.id == id }) {
                return sub.name
            }
        }
        return nil
    }

    private func downgrade(scope: ValidationDetailsView.Scope) {
        switch scope {
        case let .class(id, _):
            if let idx = classes.firstIndex(where: { $0.id == id }) {
                classes[idx].validationStatus = "compliant"
            }
        case let .subClass(id, _):
            for cIdx in classes.indices {
                if let sIdx = classes[cIdx].subClasses.firstIndex(where: { $0.id == id }) {
                    classes[cIdx].subClasses[sIdx].validationStatus = "compliant"
                }
            }
        }
    }
}

public struct AllocationTargetsTableView: View {
    @ObservedObject private var viewModel: AllocationTargetsTableViewModel
    private let db: DBGateway
    @State private var presentedScope: ValidationDetailsView.Scope?
    @State private var presentedItems: [ValidationDetailsView.Item] = []

    public init(viewModel: AllocationTargetsTableViewModel, db: DBGateway) {
        self.viewModel = viewModel
        self.db = db
    }

    public var body: some View {
        List {
            ForEach(viewModel.classes) { cls in
                Section(header: headerView(for: cls)) {
                    ForEach(cls.subClasses) { sub in
                        HStack {
                            Text(sub.name)
                            Spacer()
                            StatusBadge(status: sub.validationStatus)
                            if sub.validationStatus != "compliant" {
                                Button("Why?") {
                                    let scope: ValidationDetailsView.Scope = .subClass(id: sub.id, name: sub.name)
                                    let items = viewModel.details(for: scope, db: db)
                                    guard !items.isEmpty else { return }
                                    presentedItems = items
                                    presentedScope = scope
                                }
                                .accessibilityLabel("Why? button for \(sub.name)")
                            }
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.load(using: db) }
        .sheet(item: $presentedScope) { scope in
            ValidationDetailsView(scope: scope, items: presentedItems)
        }
    }

    private func headerView(for cls: AllocationTargetsTableViewModel.ClassItem) -> some View {
        HStack {
            Text(cls.name)
            Spacer()
            StatusBadge(status: cls.validationStatus)
            if cls.validationStatus != "compliant" {
                Button("Why?") {
                    let scope: ValidationDetailsView.Scope = .class(id: cls.id, name: cls.name)
                    let items = viewModel.details(for: scope, db: db)
                    guard !items.isEmpty else { return }
                    presentedItems = items
                    presentedScope = scope
                }
                .accessibilityLabel("Why? button for \(cls.name)")
            }
        }
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .padding(4)
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(4)
    }

    private var color: Color {
        switch status {
        case "error":
            return .red
        case "warning":
            return .yellow
        default:
            return .green
        }
    }
}
