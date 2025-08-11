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
        db.syncValidationStatusTables()
    }

    public func setStatus(_ status: String, for scope: ValidationDetailsView.Scope) {
        switch scope {
        case let .class(id, _):
            if let idx = classes.firstIndex(where: { $0.id == id }) {
                classes[idx].validationStatus = status
            }
        case let .subClass(id, _):
            for cIdx in classes.indices {
                if let sIdx = classes[cIdx].subClasses.firstIndex(where: { $0.id == id }) {
                    classes[cIdx].subClasses[sIdx].validationStatus = status
                    break
                }
            }
        }
    }

    public func findings(for scope: ValidationDetailsView.Scope, db: DBGateway) -> [ValidationFinding] {
        switch scope {
        case let .class(id, _):
            return db.fetchValidationFindingsForClass(id)
        case let .subClass(id, _):
            return db.fetchValidationFindingsForSubClass(id)
        }
    }
}

public struct AllocationTargetsTableView: View {
    @ObservedObject private var viewModel: AllocationTargetsTableViewModel
    private let db: DBGateway
    @State private var presentedScope: ValidationDetailsView.Scope?

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
                                    let records = viewModel.findings(for: scope, db: db)
                                    guard !records.isEmpty else {
                                        viewModel.setStatus("compliant", for: scope)
                                        db.syncValidationStatusTables()
                                        return
                                    }
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
            ValidationDetailsView(scope: scope, findings: viewModel.findings(for: scope, db: db))
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
                    let records = viewModel.findings(for: scope, db: db)
                    guard !records.isEmpty else {
                        viewModel.setStatus("compliant", for: scope)
                        db.syncValidationStatusTables()
                        return
                    }
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

