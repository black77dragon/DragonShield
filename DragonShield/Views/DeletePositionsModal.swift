import SwiftUI

struct DeletePositionsModal: View {
    @EnvironmentObject var dbManager: DatabaseManager

    let institutions: [DatabaseManager.InstitutionData]
    let accountTypes: [DatabaseManager.AccountTypeData]
    @Binding var selectedInstitutionIds: Set<Int>
    @Binding var selectedAccountTypeIds: Set<Int>
    @Binding var isPresented: Bool
    var completion: (Int) -> Void

    @State private var tempInstitutionIds: Set<Int> = []
    @State private var tempAccountTypeIds: Set<Int> = []
    @State private var matchCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Delete Positions")
                    .font(.title2.bold())
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Institutions").font(.headline)
                    ForEach(institutions) { inst in
                        Toggle(inst.name, isOn: Binding(
                            get: { tempInstitutionIds.contains(inst.id) },
                            set: { val in
                                if val { tempInstitutionIds.insert(inst.id) } else { tempInstitutionIds.remove(inst.id) }
                                updateCount()
                            })
                        )
                        .toggleStyle(.checkbox)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Types").font(.headline)
                    ForEach(accountTypes) { type in
                        Toggle("\(type.code) - \(type.name)", isOn: Binding(
                            get: { tempAccountTypeIds.contains(type.id) },
                            set: { val in
                                if val { tempAccountTypeIds.insert(type.id) } else { tempAccountTypeIds.remove(type.id) }
                                updateCount()
                            })
                        )
                        .toggleStyle(.checkbox)
                    }
                }
            }
            Text("Matching positions: \(matchCount)")
                .font(.headline)
                .padding(.top, 8)

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Confirm") {
                    let deleted = dbManager.deletePositionReports(institutionIds: Array(tempInstitutionIds),
                                                                 accountTypeIds: Array(tempAccountTypeIds))
                    selectedInstitutionIds = []
                    selectedAccountTypeIds = tempAccountTypeIds
                    completion(deleted)
                    isPresented = false
                }
                    .buttonStyle(DestructiveButtonStyle())
                    .disabled(tempInstitutionIds.isEmpty || tempAccountTypeIds.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 340)
        .onAppear {
            tempInstitutionIds = selectedInstitutionIds
            tempAccountTypeIds = selectedAccountTypeIds.isEmpty ? Set(accountTypes.map { $0.id }) : selectedAccountTypeIds
            updateCount()
        }
    }

    private func updateCount() {
        matchCount = dbManager.countPositionReports(institutionIds: Array(tempInstitutionIds),
                                                    accountTypeIds: Array(tempAccountTypeIds))
    }
}

struct DeletePositionsModal_Previews: PreviewProvider {
    static var previews: some View {
        DeletePositionsModal(institutions: [], accountTypes: [], selectedInstitutionIds: .constant([]), selectedAccountTypeIds: .constant([]), isPresented: .constant(true)) { _ in }
            .environmentObject(DatabaseManager())
    }
}
