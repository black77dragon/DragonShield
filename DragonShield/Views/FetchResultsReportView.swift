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
        ZStack {
            DSColor.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                header
                summaryRow
                contextSection
                HStack(alignment: .top, spacing: DSLayout.spaceM) {
                    resultColumn(
                        title: "Successful",
                        icon: "checkmark.seal.fill",
                        accent: DSColor.accentSuccess,
                        items: successes,
                        isFailure: false
                    )
                    resultColumn(
                        title: "Failed",
                        icon: "exclamationmark.triangle.fill",
                        accent: DSColor.accentError,
                        items: failures,
                        isFailure: true
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(DSLayout.spaceL)
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                Text("Price Fetch Results")
                    .font(.ds.headerMedium)
                    .foregroundColor(DSColor.textPrimary)
                Text("Summary of the latest provider run")
                    .font(.ds.bodySmall)
                    .foregroundColor(DSColor.textSecondary)
            }
            Spacer()
            Button(role: .cancel) { dismiss() } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(DSButtonStyle(type: .secondary))
            .keyboardShortcut("w", modifiers: .command)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: DSLayout.spaceM) {
            statCard(title: "Total Instruments", value: results.count, icon: "square.grid.2x2.fill", color: DSColor.accentMain)
            statCard(title: "Successful", value: successes.count, icon: "checkmark.circle.fill", color: DSColor.accentSuccess)
            statCard(title: "Failed", value: failures.count, icon: "exclamationmark.triangle.fill", color: DSColor.accentError)
        }
    }

    private func statCard(title: String, value: Int, icon: String, color: Color) -> some View {
        DSCard {
            HStack(spacing: DSLayout.spaceS) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.ds.caption)
                        .foregroundColor(DSColor.textSecondary)
                    Text("\(value)")
                        .font(.ds.headerSmall)
                        .foregroundColor(DSColor.textPrimary)
                }
            }
        }
    }

    private var contextSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                contextRow(icon: "antenna.radiowaves.left.and.right", title: "Providers", value: providerSummary())
                contextRow(icon: "clock.arrow.circlepath", title: "Generated", value: nowString())
                contextRow(icon: "globe", title: "Time Zone", value: timeZoneLabel)
            }
        }
    }

    private func contextRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: DSLayout.spaceS) {
            Image(systemName: icon)
                .foregroundColor(DSColor.accentMain)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ds.caption)
                    .foregroundColor(DSColor.textSecondary)
                Text(value)
                    .font(.ds.body)
                    .foregroundColor(DSColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultColumn(title: String, icon: String, accent: Color, items: [PriceUpdateService.ResultItem], isFailure: Bool) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spaceS) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.ds.headerSmall)
                        .foregroundColor(accent)
                    Spacer()
                    countBadge(items.count, accent: accent)
                }
                Divider()
                if items.isEmpty {
                    emptyState(text: isFailure ? "No failed instruments in this run." : "No successful updates yet.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DSLayout.spaceS) {
                            ForEach(items, id: \.instrumentId) { item in
                                resultRow(item: item, accent: accent, isFailure: isFailure)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func resultRow(item: PriceUpdateService.ResultItem, accent: Color, isFailure: Bool) -> some View {
        let name = nameById[item.instrumentId] ?? "#\(item.instrumentId)"
        let provider = providerById[item.instrumentId] ?? "—"
        let message = item.message.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
            HStack(alignment: .firstTextBaseline, spacing: DSLayout.spaceS) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.ds.body.weight(.semibold))
                    .foregroundColor(DSColor.textPrimary)
                Spacer()
                Text(provider)
                    .font(.ds.caption)
                    .foregroundColor(DSColor.textSecondary)
            }
            if !message.isEmpty {
                Text(isFailure ? "Error: \(message)" : message)
                    .font(.ds.caption)
                    .foregroundColor(isFailure ? DSColor.accentError : DSColor.textSecondary)
            } else if isFailure {
                Text("No error message provided.")
                    .font(.ds.caption)
                    .foregroundColor(DSColor.accentError)
            }
        }
        .padding(DSLayout.spaceS)
        .background(DSColor.surfaceSubtle)
        .cornerRadius(DSLayout.radiusM)
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.ds.bodySmall)
            .foregroundColor(DSColor.textSecondary)
            .padding(.vertical, DSLayout.spaceS)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countBadge(_ count: Int, accent: Color) -> some View {
        Text("\(count)")
            .font(.ds.caption)
            .foregroundColor(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(accent.opacity(0.12))
            .cornerRadius(DSLayout.radiusS)
    }

    private var timeZoneLabel: String {
        TimeZone(identifier: timeZoneId)?.identifier ?? timeZoneId
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
