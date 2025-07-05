import SwiftUI

struct AccountPromptView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State var accountName: String
    @State var accountNumber: String
    @State var institutionId: Int
    @State var accountTypeId: Int
    @State var currencyCode: String

    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var accountTypes: [DatabaseManager.AccountTypeData] = []
    @State private var currencies: [(code: String, name: String, symbol: String)] = []

    let completion: (ImportManager.AccountPromptResult) -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 1.0),
                                    Color(red: 0.95, green: 0.97, blue: 0.99)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                HStack {
                    Text("🏦 New Account")
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
                        textField(title: "Account Name", text: $accountName, icon: "tag")
                        textField(title: "Account Number", text: $accountNumber, icon: "number")
                        pickerField(title: "Institution", selection: $institutionId,
                                   options: institutions.map { ($0.id, $0.name) }, icon: "building")
                        pickerField(title: "Account Type", selection: $accountTypeId,
                                   options: accountTypes.map { ($0.id, $0.name) }, icon: "briefcase")
                        pickerField(title: "Currency", selection: $currencyCode,
                                   options: currencies.map { ($0.code, $0.code) }, icon: "dollarsign.circle")
                    }
                    .modifier(CompactFormSection(color: .blue))
                }
                .formStyle(.grouped)
                .padding(.horizontal, 16)

                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                        completion(.cancel)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Save") {
                        presentationMode.wrappedValue.dismiss()
                        completion(.save(name: accountName,
                                         institutionId: institutionId,
                                         number: accountNumber,
                                         accountTypeId: accountTypeId,
                                         currency: currencyCode))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding([.horizontal, .bottom], 24)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear(perform: loadData)
    }

    private func textField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                Spacer()
            }
            TextField(title, text: text)
                .font(.system(size: 16))
                .textFieldStyle(.roundedBorder)
        }
    }

    private func pickerField<T: Hashable>(title: String, selection: Binding<T>, options: [(T, String)], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
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
        institutions = dbManager.fetchInstitutions(activeOnly: true)
        if let first = institutions.first { institutionId = first.id }
        accountTypes = dbManager.fetchAccountTypes(activeOnly: true)
        if let first = accountTypes.first { accountTypeId = first.id }
        currencies = dbManager.fetchActiveCurrencies()
        if let first = currencies.first { currencyCode = first.code }
    }
}
