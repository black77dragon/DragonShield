import SwiftUI

// MARK: - Version 1.0
// MARK: - History: Initial creation - asset class management with CRUD operations

struct AssetClassesView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var assetClasses: [DatabaseManager.AssetClassData] = []
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    // Holds the selected asset class id for Table single selection
    @State private var selectedClassId: DatabaseManager.AssetClassData.ID? = nil
    // Currently selected asset class when invoking context actions
    @State private var selectedClass: DatabaseManager.AssetClassData? = nil
    @State private var showingDeleteAlert = false
    @State private var classToDelete: DatabaseManager.AssetClassData? = nil
    @State private var searchText = ""

    var filteredClasses: [DatabaseManager.AssetClassData] {
        if searchText.isEmpty { return assetClasses }
        return assetClasses.filter { ac in
            ac.name.localizedCaseInsensitiveContains(searchText) ||
            ac.code.localizedCaseInsensitiveContains(searchText) ||
            (ac.description ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack {
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Spacer()
                Button("Add") { showAddSheet = true }
            }.padding()

            Table(filteredClasses, selection: $selectedClassId) {
                TableColumn("Code") { Text($0.code) }
                TableColumn("Name") { Text($0.name) }
                TableColumn("Description") { Text($0.description ?? "") }
                TableColumn("Sort") { Text(String($0.sortOrder)) }
            }
            .onDeleteCommand {
                if let selId = selectedClassId,
                   let ac = assetClasses.first(where: { $0.id == selId }) {
                    classToDelete = ac
                    showingDeleteAlert = true
                }
            }
            .contextMenu(forSelectionType: DatabaseManager.AssetClassData.self) { items in
                if let item = items.first {
                    Button("Edit") {
                        selectedClassId = item.id
                        selectedClass = item
                        showEditSheet = true
                    }
                    Button("Delete") {
                        classToDelete = item
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .onAppear(perform: loadData)
        .onChange(of: selectedClassId) { newId in
            selectedClass = assetClasses.first(where: { $0.id == newId })
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAssetClasses"))) { _ in
            loadData()
        }
        .sheet(isPresented: $showAddSheet) { AddAssetClassView().environmentObject(dbManager) }
        .sheet(isPresented: $showEditSheet) {
            if let ac = selectedClass { EditAssetClassView(classId: ac.id).environmentObject(dbManager) }
        }
        .alert("Delete Asset Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            if let ac = classToDelete {
                Text("Delete \(ac.name)?")
            } else { Text("") }
        }
    }

    private func loadData() {
        assetClasses = dbManager.fetchAssetClassesDetailed()
    }

    private func deleteSelected() {
        guard let ac = classToDelete else { return }
        let info = dbManager.canDeleteAssetClass(id: ac.id)
        if info.canDelete {
            if dbManager.deleteAssetClass(id: ac.id) {
                loadData()
            }
        } else {
            // simple alert with message about dependencies
            // For brevity we reuse the same alert
            classToDelete = nil
            showingDeleteAlert = false
        }
    }
}

struct AddAssetClassView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var code = ""
    @State private var name = ""
    @State private var description = ""
    @State private var sortOrder = "0"
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var isValid: Bool { !code.isEmpty && !name.isEmpty && Int(sortOrder) != nil }

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                TextField("Code", text: $code)
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                TextField("Sort Order", text: $sortOrder)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack {
                Spacer()
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .frame(width: 400)
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func save() {
        let ok = dbManager.addAssetClass(code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                                         name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                         description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                         sortOrder: Int(sortOrder) ?? 0)
        if ok {
            alertMessage = "✅ Added asset class"
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
        } else {
            alertMessage = "❌ Failed to add asset class"
        }
        showingAlert = true
    }
}

struct EditAssetClassView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let classId: Int

    @State private var code = ""
    @State private var name = ""
    @State private var description = ""
    @State private var sortOrder = "0"
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var isValid: Bool { !code.isEmpty && !name.isEmpty && Int(sortOrder) != nil }

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                TextField("Code", text: $code)
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                TextField("Sort Order", text: $sortOrder)
            }
            HStack {
                Spacer()
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .frame(width: 400)
        .onAppear(perform: loadData)
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func loadData() {
        if let data = dbManager.fetchAssetClassDetails(id: classId) {
            code = data.code
            name = data.name
            description = data.description ?? ""
            sortOrder = String(data.sortOrder)
        }
    }

    private func save() {
        let ok = dbManager.updateAssetClass(id: classId,
                                            code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                            sortOrder: Int(sortOrder) ?? 0)
        if ok {
            alertMessage = "✅ Updated asset class"
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
        } else {
            alertMessage = "❌ Failed to update asset class"
        }
        showingAlert = true
    }
}

