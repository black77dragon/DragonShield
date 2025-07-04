import SwiftUI

struct ImportSummaryView: View {
    @Environment(\.presentationMode) private var presentationMode
    let fileName: String
    let accountNumber: String?
    let valueDate: Date?
    let validRows: Int
    let completion: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 1.0),
                                     Color(red: 0.95, green: 0.97, blue: 0.99)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 6) {
                HStack {
                    Text("\u{1F4CA} Import Details")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        completion()
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
                        infoRow(title: "File", value: fileName, icon: "doc")
                        if let account = accountNumber {
                            infoRow(title: "Custody Account", value: account, icon: "number")
                        }
                        if let date = valueDate {
                            infoRow(title: "Value Date", value: DateFormatter.swissDate.string(from: date), icon: "calendar")
                        }
                        infoRow(title: "Valid Rows", value: String(validRows), icon: "list.number")
                    }
                    .modifier(CompactFormSection(color: .blue))
                }
                .formStyle(.grouped)
                .padding(.horizontal, 16)

                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                    completion()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding([.horizontal, .bottom], 24)
            }
        }
        .frame(minWidth: 500, minHeight: 320)
    }

    private func infoRow(title: String, value: String, icon: String) -> some View {
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
            Text(value)
                .font(.system(size: 16))
        }
    }
}
