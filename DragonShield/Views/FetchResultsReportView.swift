import SwiftUI

struct FetchResultsReportView: View {
    let results: [PriceUpdateService.ResultItem]
    let nameById: [Int: String]
    let providerById: [Int: String]
    let timeZoneId: String

    private var successes: [PriceUpdateService.ResultItem] { results.filter { $0.status == "ok" } }
    private var failures: [PriceUpdateService.ResultItem] { results.filter { $0.status != "ok" } }
    private var providers: [String: Int] {
        var counts: [String: Int] = [:]
        for r in results {
            let p = providerById[r.instrumentId] ?? ""
            counts[p, default: 0] += 1
        }
        return counts
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Fetch Latest Results").font(.title3).bold()
                Spacer()
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }

            contextSection
                .padding(8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Two aligned columns, each with its count above the list
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    summaryTile(title: "Loaded instruments", value: successes.count)
                    Text("Successful").font(.headline)
                    if successes.isEmpty {
                        Text("None").foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(successes, id: \.instrumentId) { r in
                                    Text("• \(nameById[r.instrumentId] ?? "#\(r.instrumentId)")")
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    summaryTile(title: "Failed", value: failures.count)
                    Text("Failed").font(.headline)
                    if failures.isEmpty {
                        Text("None").foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(failures, id: \.instrumentId) { r in
                                    let name = nameById[r.instrumentId] ?? "#\(r.instrumentId)"
                                    let msg = r.message
                                    Text("• \(name), Error: \(msg)")
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Providers:").frame(width: 120, alignment: .leading).foregroundColor(.secondary)
                Text(providerSummary())
            }
            HStack {
                Text("Date & Time:").frame(width: 120, alignment: .leading).foregroundColor(.secondary)
                Text(nowString())
            }
        }
    }

    private func providerSummary() -> String {
        let entries = providers.filter { !$0.key.isEmpty }
        if entries.isEmpty { return "—" }
        if entries.count == 1, let (p, n) = entries.first { return "\(p) (\(n))" }
        return entries.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
    }

    private func nowString() -> String {
        let tz = TimeZone(identifier: timeZoneId) ?? .current
        let df = DateFormatter()
        df.timeZone = tz
        df.dateFormat = "dd.MM.yy HH:mm"
        return df.string(from: Date())
    }

    private func summaryTile(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text("\(value)").font(.title3).bold()
        }
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#if DEBUG
    struct FetchResultsReportView_Previews: PreviewProvider {
        static var previews: some View {
            let sample: [PriceUpdateService.ResultItem] = [
                .init(instrumentId: 1, status: "ok", message: "Updated"),
                .init(instrumentId: 2, status: "error", message: "Invalid id"),
            ]
            FetchResultsReportView(
                results: sample,
                nameById: [1: "Bitcoin", 2: "DeepBook"],
                providerById: [1: "coingecko", 2: "coingecko"],
                timeZoneId: TimeZone.current.identifier
            )
        }
    }
#endif
