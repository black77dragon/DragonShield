import SwiftUI

struct InstrumentPromptView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State var name: String
    @State var ticker: String
    @State var isin: String
    @State var valorNr: String = ""
    @State var currency: String
    @State var subClassId: Int = 1
    @State var sector: String = ""
    @State private var subClasses: [(id: Int, name: String)] = []
    @State private var currencies: [(code: String, name: String, symbol: String)] = []
    let completion: (ImportManager.InstrumentPromptResult) -> Void

    init(name: String, ticker: String, isin: String, valorNr: String = "", currency: String, subClassId: Int? = nil, completion: @escaping (ImportManager.InstrumentPromptResult) -> Void) {
        _name = State(initialValue: name)
        _ticker = State(initialValue: ticker)
        _isin = State(initialValue: isin)
        _valorNr = State(initialValue: valorNr)
        _currency = State(initialValue: currency)
        _subClassId = State(initialValue: subClassId ?? 1)
        self.completion = completion
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0),
                         Color(red: 0.95, green: 0.97, blue: 0.99)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 6) {
                HStack {
                    Text("🎸 New Instrument")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        completion(.abort)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Form {
                    Section {
                        modernTextField(title: "Name", text: $name, placeholder: "Instrument Name", icon: "doc.text", isRequired: true)
                        pickerField(title: "SubClass", selection: $subClassId, options: subClasses.map { ($0.id, $0.name) }, icon: "folder")
                        pickerField(title: "Currency", selection: $currency, options: currencies.map { ($0.code, $0.code) }, icon: "dollarsign.circle")
                        modernTextField(title: "Ticker", text: $ticker, placeholder: "Ticker", icon: "number", isRequired: false)
                        modernTextField(title: "ISIN", text: $isin, placeholder: "ISIN", icon: "barcode", isRequired: false)
                        modernTextField(title: "Valor", text: $valorNr, placeholder: "Valor", icon: "number", isRequired: false)
                        modernTextField(title: "Sector", text: $sector, placeholder: "Sector", icon: "briefcase", isRequired: false)
                    }
                    .modifier(CompactFormSection(color: .pink))
                }
                .formStyle(.grouped)
                .padding(.horizontal, 16)

                HStack {
                    Button("Ignore") {
                        presentationMode.wrappedValue.dismiss()
                        completion(.ignore)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Save") {
                        presentationMode.wrappedValue.dismiss()
                        completion(.save(name: name,
                                         subClassId: subClassId,
                                         currency: currency,
                                         ticker: ticker.isEmpty ? nil : ticker,
                                         isin: isin.isEmpty ? nil : isin,
                                         valorNr: valorNr.isEmpty ? nil : valorNr,
                                         sector: sector.isEmpty ? nil : sector))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
                .padding([.horizontal, .bottom], 24)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear(perform: loadData)
    }

    private func modernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Text(title + (isRequired ? "*" : ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                Spacer()
            }
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func pickerField<T: Hashable>(title: String, selection: Binding<T>, options: [(T, String)], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                Spacer()
            }
            Picker(title, selection: selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }

    private func loadData() {
        let db = DatabaseManager()
        subClasses = db.fetchAssetTypes()
        if !subClasses.contains(where: { $0.id == subClassId }) {
            if let first = subClasses.first { subClassId = first.id }
        }
        currencies = db.fetchActiveCurrencies()
        if !currencies.contains(where: { $0.code == currency }) {
            if let firstCurr = currencies.first { currency = firstCurr.code }
        }
    }
}
