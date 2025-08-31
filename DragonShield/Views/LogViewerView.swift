import SwiftUI

struct LogViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var logText: String = ""
    @State private var isLoading: Bool = false
    @State private var updates: [UpdateItem] = []

    struct UpdateItem: Identifiable {
        let id = UUID()
        let instrumentId: Int
        let name: String
        let price: Double
        let currency: String
        let asOf: String
        let source: String
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Application Logs").font(.title3).bold()
                Spacer()
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                Button(action: loadLogs) { if isLoading { ProgressView() } else { Text("Refresh") } }
                Button("Clear") { clearLogs() }
                Spacer()
            }

            if !updates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Successful Price Updates (parsed)").font(.headline)
                    HStack {
                        Text("Instrument").frame(width: 320, alignment: .leading)
                        Text("Price").frame(width: 140, alignment: .trailing)
                        Text("Curr").frame(width: 70, alignment: .leading)
                        Text("As Of").frame(width: 320, alignment: .leading)
                        Text("Source").frame(width: 160, alignment: .leading)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(updates) { u in
                                HStack {
                                    Text("\(u.name) (#\(u.instrumentId))").frame(width: 320, alignment: .leading)
                                    Text(String(format: "%.4f", u.price)).frame(width: 140, alignment: .trailing).monospacedDigit()
                                    Text(u.currency).frame(width: 70, alignment: .leading)
                                    Text(u.asOf).frame(width: 320, alignment: .leading)
                                    Text(u.source).frame(width: 160, alignment: .leading)
                                    Spacer()
                                }
                                .font(.system(size: 12))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 180)
                }
                .padding(8)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            TextEditor(text: $logText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 320)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
        }
        .padding(16)
        .frame(minWidth: 1100, minHeight: 650)
        .onAppear(perform: loadLogs)
    }

    private func loadLogs() {
        isLoading = true
        DispatchQueue.global().async {
            let text = LoggingService.shared.readLog()
            DispatchQueue.main.async {
                self.logText = text
                self.updates = self.parseUpdates(from: text)
                self.isLoading = false
            }
        }
    }

    private func clearLogs() {
        LoggingService.shared.clearLog()
        loadLogs()
    }

    private func parseUpdates(from text: String) -> [UpdateItem] {
        var items: [UpdateItem] = []
        let pattern = #"\[PriceUpdate\] Updated instrumentId=(\d+) price=([0-9]+(?:\.[0-9]+)?) curr=([A-Za-z]+) asOf=([^ ]+) source=([A-Za-z0-9_\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        for m in matches {
            if m.numberOfRanges == 6,
               let idRange = Range(m.range(at: 1), in: text),
               let priceRange = Range(m.range(at: 2), in: text),
               let currRange = Range(m.range(at: 3), in: text),
               let asOfRange = Range(m.range(at: 4), in: text),
               let sourceRange = Range(m.range(at: 5), in: text) {
                let id = Int(text[idRange]) ?? 0
                let price = Double(text[priceRange]) ?? 0
                let curr = String(text[currRange])
                let asOf = String(text[asOfRange])
                let source = String(text[sourceRange])
                let name = dbManager.getInstrumentName(id: id) ?? "Instrument"
                items.append(UpdateItem(instrumentId: id, name: name, price: price, currency: curr, asOf: asOf, source: source))
            }
        }
        return items
    }
}

#if DEBUG
struct LogViewerView_Previews: PreviewProvider {
    static var previews: some View {
        LogViewerView()
    }
}
#endif
