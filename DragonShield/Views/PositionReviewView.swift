import SwiftUI

struct PositionReviewView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State var record: ParsedPositionRecord
    let completion: (ImportManager.RecordPromptResult) -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 1.0),
                                    Color(red: 0.95, green: 0.97, blue: 0.99)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                HStack {
                    Text("📝 Confirm Instrument Position Upload")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        completion(.abort)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
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
                        modernTextField(title: "Account No", text: $record.accountNumber, placeholder: "", icon: "number", isRequired: true)
                        modernTextField(title: "Account Name", text: $record.accountName, placeholder: "", icon: "person", isRequired: true)
                        modernTextField(title: "Instrument", text: $record.instrumentName, placeholder: "", icon: "doc.text", isRequired: true)
                        modernTextField(title: "Ticker", text: Binding($record.tickerSymbol, replacingNilWith: ""), placeholder: "", icon: "number", isRequired: false)
                        modernTextField(title: "ISIN", text: Binding($record.isin, replacingNilWith: ""), placeholder: "", icon: "barcode", isRequired: false)
                        modernTextField(title: "Currency", text: $record.currency, placeholder: "", icon: "dollarsign.circle", isRequired: true)
                        modernTextField(title: "Quantity", text: Binding(get: { String(record.quantity) }, set: { record.quantity = Double($0) ?? record.quantity }), placeholder: "", icon: "number", isRequired: true)
                    }
                    .modifier(CompactFormSection(color: .orange))
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
                        completion(.save(record))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding([.horizontal, .bottom], 24)
            }
        }
        .frame(minWidth: 600, minHeight: 550)
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
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(title + (isRequired ? "*" : ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                Spacer()
            }
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .textFieldStyle(.roundedBorder)
        }
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith nilReplacement: String) {
        self.init(get: { source.wrappedValue ?? nilReplacement },
                  set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
