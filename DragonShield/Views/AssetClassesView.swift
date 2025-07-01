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
    @State private var isLoading = false

    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    var isValid: Bool { !code.isEmpty && !name.isEmpty && Int(sortOrder) != nil }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0),
                         Color(red: 0.95, green: 0.97, blue: 0.99),
                         Color(red: 0.93, green: 0.95, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                addHeader
                addContent
            }
        }
        .frame(width: 500, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear { animateEntrance() }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.hasPrefix("✅") { animateExit() }
            }
        } message: { Text(alertMessage) }
    }

    private var addHeader: some View {
        HStack {
            Button { animateExit() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)

                Text("Add Asset Class")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
            }

            Spacer()

            Button {
                save()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(isLoading ? "Saving..." : "Save")
                        .font(.system(size: 14, weight: .semibold))
                }
                .modifier(ModernPrimaryButton(color: .purple, isDisabled: !isValid || isLoading))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    private var addContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                addInfoSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 80)
        }
        .offset(y: sectionsOffset)
    }

    private var addInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Class Information", icon: "folder.fill", color: .purple)
            VStack(spacing: 16) {
                modernTextField(title: "Class Code", text: $code, placeholder: "e.g., EQTY", icon: "number", isRequired: true, autoUppercase: true)
                modernTextField(title: "Class Name", text: $name, placeholder: "e.g., Equity", icon: "textformat", isRequired: true)
                modernTextField(title: "Description", text: $description, placeholder: "", icon: "text.justify")
                modernTextField(title: "Sort Order", text: $sortOrder, placeholder: "0", icon: "arrow.up.arrow.down", isRequired: true)
            }
        }
        .modifier(ModernFormSection(color: .purple))
    }

    private func save() {
        guard isValid else { return }
        isLoading = true
        let ok = dbManager.addAssetClass(code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                                         name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                         description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                         sortOrder: Int(sortOrder) ?? 0)
        isLoading = false
        if ok {
            alertMessage = "✅ Added asset class"
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
        } else {
            alertMessage = "❌ Failed to add asset class"
        }
        showingAlert = true
    }

    // MARK: - Helpers
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }

    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, autoUppercase: Bool = false) -> some View {
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
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase { text.wrappedValue = newValue.uppercased() }
                }
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
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
    @State private var isLoading = false

    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false
    @State private var originalCode = ""
    @State private var originalName = ""
    @State private var originalDescription = ""
    @State private var originalSortOrder = "0"

    var isValid: Bool { !code.isEmpty && !name.isEmpty && Int(sortOrder) != nil }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0),
                         Color(red: 0.94, green: 0.96, blue: 0.99),
                         Color(red: 0.91, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                editHeader
                editContent
            }
        }
        .frame(width: 500, height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadData()
            animateEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") { showingAlert = false }
        } message: { Text(alertMessage) }
        .onChange(of: code) { _, _ in detectChanges() }
        .onChange(of: name) { _, _ in detectChanges() }
        .onChange(of: description) { _, _ in detectChanges() }
        .onChange(of: sortOrder) { _, _ in detectChanges() }
    }

    private var editHeader: some View {
        HStack {
            Button {
                if hasChanges { animateExit() } else { animateExit() }
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

            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)

                Text("Edit Asset Class")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
            }

            Spacer()

            Button {
                save()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text(isLoading ? "Saving..." : "Save Changes")
                        .font(.system(size: 14, weight: .semibold))
                }
                .modifier(ModernPrimaryButton(color: .orange, isDisabled: !isValid || !hasChanges || isLoading))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    private var editContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                editInfoSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 80)
        }
        .offset(y: sectionsOffset)
    }

    private var editInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Class Information", icon: "folder.fill", color: .orange)
            VStack(spacing: 16) {
                modernTextField(title: "Class Code", text: $code, placeholder: "e.g., EQTY", icon: "number", isRequired: true, autoUppercase: true)
                modernTextField(title: "Class Name", text: $name, placeholder: "e.g., Equity", icon: "textformat", isRequired: true)
                modernTextField(title: "Description", text: $description, placeholder: "", icon: "text.justify")
                modernTextField(title: "Sort Order", text: $sortOrder, placeholder: "0", icon: "arrow.up.arrow.down", isRequired: true)
            }
        }
        .modifier(ModernFormSection(color: .orange))
    }

    private func loadData() {
        if let data = dbManager.fetchAssetClassDetails(id: classId) {
            code = data.code
            name = data.name
            description = data.description ?? ""
            sortOrder = String(data.sortOrder)
            originalCode = data.code
            originalName = data.name
            originalDescription = data.description ?? ""
            originalSortOrder = String(data.sortOrder)
            detectChanges()
        }
    }

    private func detectChanges() {
        hasChanges = code != originalCode ||
                     name != originalName ||
                     description != originalDescription ||
                     sortOrder != originalSortOrder
    }

    private func save() {
        guard isValid && hasChanges else { return }
        isLoading = true
        let ok = dbManager.updateAssetClass(id: classId,
                                            code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                                            sortOrder: Int(sortOrder) ?? 0)
        isLoading = false
        if ok {
            alertMessage = "✅ Updated asset class"
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
        } else {
            alertMessage = "❌ Failed to update asset class"
        }
        showingAlert = true
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }

    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, autoUppercase: Bool = false) -> some View {
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
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase { text.wrappedValue = newValue.uppercased() }
                }
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

