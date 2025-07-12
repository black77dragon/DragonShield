import SwiftUI

// MARK: - Version 1.1
// MARK: - History
// - 1.0: Initial creation - asset class management with CRUD operations
// - 1.1: Modernized list view with animations, search and action bar

struct AssetClassesView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var assetClasses: [DatabaseManager.AssetClassData] = []
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var selectedClass: DatabaseManager.AssetClassData? = nil
    @State private var classToDelete: DatabaseManager.AssetClassData? = nil
    @State private var showingDeleteAlert = false
    @State private var searchText = ""

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    var filteredClasses: [DatabaseManager.AssetClassData] {
        if searchText.isEmpty {
            return assetClasses.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            return assetClasses.filter { ac in
                ac.name.localizedCaseInsensitiveContains(searchText) ||
                ac.code.localizedCaseInsensitiveContains(searchText) ||
                (ac.description ?? "").localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                classesContent
                modernActionBar
            }
        }
        .onAppear {
            loadData()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAssetClasses"))) { _ in
            loadData()
        }
        .sheet(isPresented: $showAddSheet) {
            AddAssetClassView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditSheet) {
            if let ac = selectedClass {
                EditAssetClassView(classId: ac.id).environmentObject(dbManager)
            }
        }
        .alert("Delete Asset Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let ac = classToDelete { deleteClass(ac) }
            }
        } message: {
            if let ac = classToDelete {
                Text("Are you sure you want to delete '\(ac.name)'?")
            }
        }
    }

    // MARK: - Subviews
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)

                    Text("Asset Classes")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Manage your high-level asset categories")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            modernStatCard(
                title: "Total",
                value: "\(assetClasses.count)",
                icon: "number.circle.fill",
                color: .blue
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search asset classes...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            if !searchText.isEmpty {
                HStack {
                    Text("Found \(filteredClasses.count) of \(assetClasses.count) classes")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }

    private var classesContent: some View {
        VStack(spacing: 16) {
            if filteredClasses.isEmpty {
                emptyStateView
            } else {
                classesTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .offset(y: contentOffset)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No asset classes yet" : "No matching classes")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    Text(searchText.isEmpty ?
                         "Create your first asset class to categorize your assets" :
                         "Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if searchText.isEmpty {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Your First Class")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var classesTable: some View {
        VStack(spacing: 0) {
            modernTableHeader

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredClasses, id: \.id) { ac in
                        ModernClassRowView(
                            assetClass: ac,
                            isSelected: selectedClass?.id == ac.id,
                            onTap: { selectedClass = ac },
                            onEdit: {
                                selectedClass = ac
                                showEditSheet = true
                            }
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    private var modernTableHeader: some View {
        HStack {
            Text("Code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)

            Text("Name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Description")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Order")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.bottom, 1)
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add New Class")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())

                if selectedClass != nil {
                    Button {
                        showEditSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        if let ac = selectedClass {
                            classToDelete = ac
                            showingDeleteAlert = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Spacer()

                if let ac = selectedClass {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(ac.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }

    // MARK: - Functions
    private func loadData() {
        assetClasses = dbManager.fetchAssetClassesDetailed()
    }

    private func deleteClass(_ ac: DatabaseManager.AssetClassData) {
        let info = dbManager.canDeleteAssetClass(id: ac.id)

        if info.canDelete {
            if dbManager.deleteAssetClass(id: ac.id) {
                loadData()
                selectedClass = nil
            }
        }
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            headerOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            contentOffset = 0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            buttonsOpacity = 1.0
        }
    }

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
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

// MARK: - Modern Class Row
struct ModernClassRowView: View {
    let assetClass: DatabaseManager.AssetClassData
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Text(assetClass.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(assetClass.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(assetClass.description ?? "")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(assetClass.sortOrder)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit Class") { onEdit() }
            Button("Select Class") { onTap() }
            Divider()
            Button("Copy Code") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(assetClass.code, forType: .string)
            }
            Button("Copy Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(assetClass.name, forType: .string)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct EditAssetClassView: View {
    @Environment(\.dismiss) private var dismiss
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
            NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetClasses"), object: nil)
            animateExit()
        } else {
            alertMessage = "❌ Failed to update asset class"
            showingAlert = true
        }
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
            dismiss()
        }
    }
}

