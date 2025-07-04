import SwiftUI

struct InstrumentPromptView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State var name: String
    @State var ticker: String
    @State var isin: String
    @State var currency: String
    let completion: (ImportManager.InstrumentPromptResult) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0),
                         Color(red: 0.95, green: 0.97, blue: 0.99)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("🎸 New Instrument")
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
                        modernTextField(title: "Name", text: $name, placeholder: "Instrument Name", icon: "doc.text", isRequired: true)
                        modernTextField(title: "Ticker", text: $ticker, placeholder: "Ticker", icon: "number", isRequired: false)
                        modernTextField(title: "ISIN", text: $isin, placeholder: "ISIN", icon: "barcode", isRequired: false)
                        modernTextField(title: "Currency", text: $currency, placeholder: "Currency", icon: "dollarsign.circle", isRequired: true)
                    }
                    .modifier(ModernFormSection(color: .purple))
                }
                .formStyle(.grouped)
                .padding(.horizontal, 24)

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
                                         ticker: ticker.isEmpty ? nil : ticker,
                                         isin: isin.isEmpty ? nil : isin,
                                         currency: currency))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .padding([.horizontal, .bottom], 24)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
    }

    private func modernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
