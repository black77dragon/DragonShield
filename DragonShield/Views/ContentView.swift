import SwiftUI

struct ContentView: View {
    @State private var instruments: [SimpleInstrument] = []

    var body: some View {
        VStack {
            HStack {
                Text("Assets: \(instruments.count)")
                    .padding()
                    .background(Color.yellow.opacity(0.3))

                Spacer()

                Button("Load from DB") {
                    loadFromDatabase()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Force Reload DB") {
                    reloadDatabase()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            if instruments.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "briefcase")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No instruments")
                    Button("Load Sample Data") {
                        reloadDatabase()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                List(instruments) { instrument in
                    HStack {
                        Text(instrument.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text(instrument.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(instrument.currency)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            loadFromDatabase()
        }
    }

    func loadFromDatabase() {
        let db = DatabaseManager()
        let dbInstruments = db.fetchAssets()
        let dbTypes = db.fetchAssetTypes()

        print("DB: \(dbInstruments.count) instruments, \(dbTypes.count) types")

        let typeLookup = Dictionary(uniqueKeysWithValues: dbTypes.map { ($0.id, $0.name) })

        instruments = dbInstruments.map { instrument in
            SimpleInstrument(
                name: instrument.name,
                type: typeLookup[instrument.subClassId] ?? "Unknown",
                currency: instrument.currency
            )
        }

        print("Loaded \(instruments.count) instruments")
    }

    func reloadDatabase() {
        let db = DatabaseManager()
        db.forceReloadData()
        loadFromDatabase()
    }
}

struct SimpleInstrument: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let currency: String
}

#Preview {
    ContentView()
}
