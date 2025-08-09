import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct ValidationDetailsView: View {
    let findings: [DatabaseManager.ValidationFinding]
    @State private var filter: SeverityFilter = .all

    enum SeverityFilter { case all, errors, warnings }

    private var filtered: [DatabaseManager.ValidationFinding] {
        switch filter {
        case .all: return findings
        case .errors: return findings.filter { $0.severity == "error" }
        case .warnings: return findings.filter { $0.severity == "warning" }
        }
    }

    private var grouped: [(String, [DatabaseManager.ValidationFinding])] {
        let groups = Dictionary(grouping: filtered, by: { $0.entityType })
        return groups.keys.sorted().map { ($0, groups[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Validation Details")
                    .font(.headline)
                Spacer()
                Picker("", selection: $filter) {
                    Text("All").tag(SeverityFilter.all)
                    Text("Errors").tag(SeverityFilter.errors)
                    Text("Warnings").tag(SeverityFilter.warnings)
                }
                .pickerStyle(.segmented)
                Button("Copy") {
                    copyToClipboard()
                }
            }
            if findings.isEmpty {
                Text("No validation findings at this time.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(grouped, id: \.0) { group, items in
                        Section(header: Text(label(for: group))) {
                            ForEach(items) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(item.severity.uppercased())
                                        .font(.caption2)
                                        .padding(4)
                                        .background(item.severity == "error" ? Color.red : Color.orange)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.code).bold()
                                        Text(item.message)
                                        Text(dateString(item.computedAt))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private func label(for group: String) -> String {
        switch group {
        case "portfolio": return "Portfolio-level"
        case "class": return "Asset Classes"
        case "subclass": return "Sub-Classes"
        default: return group
        }
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func copyToClipboard() {
        let text = filtered.map { "\($0.severity.uppercased()) \($0.code): \($0.message)" }.joined(separator: "\n")
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
