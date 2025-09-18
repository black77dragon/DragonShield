// DragonShield/Views/AssetSubClassesView.swift
// MARK: - Version 1.2
// MARK: - History
// - 1.1 -> 1.2: Renamed Instrument Types screen to Asset SubClasses and added
//   asset class description column.
// - 1.0 -> 1.1: Updated deprecated onChange modifiers to new syntax for macOS 14.0+.
// - Initial creation - instrument types management with CRUD operations

import SwiftUI

// MARK: - Version 1.0
// MARK: - History: Initial creation - instrument types management with CRUD operations

struct AssetSubClassesView: View {
    @State private var subClasses: [(id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)] = []
    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false
    @State private var selectedSubClass: (id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)? = nil
    @State private var showDeleteResultAlert = false
    @State private var deleteResultMessage = ""
    @State private var showDeleteSuccessToast = false
    @State private var searchText = ""
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    // Filtered subclasses based on search
    var filteredSubClasses: [(id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)] {
        if searchText.isEmpty {
            return subClasses.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            return subClasses.filter { type in
                type.name.localizedCaseInsensitiveContains(searchText) ||
                type.code.localizedCaseInsensitiveContains(searchText) ||
                type.description.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
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
            
            // Subtle animated background elements
            TypesParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                typesContent
                modernActionBar
            }
        }
        .onAppear {
            loadSubClasses()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAssetSubClasses"))) { _ in
            loadSubClasses()
        }
        .sheet(isPresented: $showAddTypeSheet) {
            AddAssetSubClassView()
        }
        .sheet(isPresented: $showEditTypeSheet) {
            if let type = selectedSubClass {
                EditAssetSubClassView(typeId: type.id)
            }
        }
        .alert("Delete Failed", isPresented: $showDeleteResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteResultMessage)
        }
        .toast(isPresented: $showDeleteSuccessToast, message: "Asset subclass deleted")
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)
                    
                    Text("Asset SubClasses")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text("Manage your asset categories and classifications")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(subClasses.count)",
                    icon: "number.circle.fill",
                    color: .purple
                )
                
                modernStatCard(
                    title: "Active",
                    value: "\(subClasses.filter { $0.isActive }.count)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                modernStatCard(
                    title: "Inactive",
                    value: "\(subClasses.filter { !$0.isActive }.count)",
                    icon: "pause.circle.fill",
                    color: .orange
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Search and Stats
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search asset subclasses...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
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
            
            // Results indicator
            if !searchText.isEmpty {
                HStack {
                    Text("Found \(filteredSubClasses.count) of \(subClasses.count) subclasses")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }
    
    // MARK: - Types Content
    private var typesContent: some View {
        VStack(spacing: 16) {
            if filteredSubClasses.isEmpty {
                emptyStateView
            } else {
                typesTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .offset(y: contentOffset)
    }
    
    // MARK: - Empty State
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
                    Text(searchText.isEmpty ? "No asset subclasses yet" : "No matching subclasses")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(searchText.isEmpty ?
                         "Create your first asset subclass to categorize your assets" :
                         "Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if searchText.isEmpty {
                    Button { showAddTypeSheet = true } label: {
                        Label("Add Instrument Type", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Types Table
    private var typesTable: some View {
        VStack(spacing: 0) {
            // Table header
            modernTableHeader
            
            // Table content
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredSubClasses, id: \.id) { type in
                        ModernTypeRowView(
                            type: type,
                            isSelected: selectedSubClass?.id == type.id,
                            onTap: {
                                selectedSubClass = type
                            },
                            onEdit: {
                                selectedSubClass = type
                                showEditTypeSheet = true
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
    
    // MARK: - Modern Table Header
    private var modernTableHeader: some View {
        HStack {
            Text("Name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Asset Class")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .leading)

            Text("Code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            Text("Description")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 200, alignment: .leading)
            
            Text("Order")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .center)
            
            Text("Status")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.bottom, 1)
    }
    
    // MARK: - Modern Action Bar
    private var modernActionBar: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 16) {
                // Primary action
                Button { showAddTypeSheet = true } label: {
                    Label("Add Instrument Type", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                
                // Secondary actions
                if selectedSubClass != nil {
                    Button {
                        showEditTypeSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button {
                        if let type = selectedSubClass {
                            handleDelete(type)
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
                
                // Selection indicator
                if let type = selectedSubClass {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                        Text("Selected: \(type.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.05))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }
    
    // MARK: - Helper Views
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
    
    // MARK: - Animations
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
    
    // MARK: - Functions
    func loadSubClasses() {
        let dbManager = DatabaseManager()
        subClasses = dbManager.fetchInstrumentTypes()
    }

    func handleDelete(_ type: (id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)) {
        let dbManager = DatabaseManager()
        let result = dbManager.deleteInstrumentType(id: type.id)

        if result.success {
            loadSubClasses()
            selectedSubClass = nil
            showDeleteSuccessToast = true
        } else {
            if !result.usage.isEmpty {
                let detail = result.usage
                    .map { "\($0.count) row(s) in \($0.table).\($0.field)" }
                    .joined(separator: ", ")
                deleteResultMessage = "Cannot delete — referenced by " + detail
            } else {
                deleteResultMessage = "Failed to delete asset subclass."
            }
            showDeleteResultAlert = true
        }
    }
}

// MARK: - Modern Type Row
struct ModernTypeRowView: View {
    let type: (id: Int, classId: Int, classDescription: String, code: String, name: String, description: String, sortOrder: Int, isActive: Bool)
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Text(type.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(type.classDescription)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            
            Text(type.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 100, alignment: .leading)
            
            Text(type.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(width: 200, alignment: .leading)
            
            Text("\(type.sortOrder)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .center)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(type.isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(type.isActive ? "Active" : "Inactive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(type.isActive ? .green : .orange)
            }
            .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.purple.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button("Edit SubClass") {
                onEdit()
            }
            Button("Select SubClass") {
                onTap()
            }
            Divider()
            Button("Copy Name") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(type.name, forType: .string)
            }
            Button("Copy Code") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(type.code, forType: .string)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Add Asset SubClass View
struct AddAssetSubClassView: View {
    @Environment(\.presentationMode) private var presentationMode

    @State private var assetClasses: [(id: Int, name: String)] = []
    @State private var selectedClassId: Int = 0
    
    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var sortOrder = "0"
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    
    var isValid: Bool {
        !assetClasses.isEmpty && selectedClassId != 0 &&
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(sortOrder) != nil
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
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
            
            // Main content
            VStack(spacing: 0) {
                addModernHeader
                addModernContent
            }
        }
        .frame(width: 600, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadAssetClasses()
            animateAddEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("✅") {
                    animateAddExit()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Add Modern Header
    private var addModernHeader: some View {
        HStack {
            Button {
                animateAddExit()
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
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
                
                Text("Add Asset SubClass")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            Button {
                saveInstrumentType()
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
                .foregroundColor(.white)
                .frame(height: 32)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if isValid && !isLoading {
                            Color.purple
                        } else {
                            Color.gray.opacity(0.4)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isValid ? .purple.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Add Modern Content
    private var addModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                addFormSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Add Form Section
    private var addFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                
                Text("Type Information")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Asset Class selection
                HStack {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Text("Asset Class*")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))

                    Spacer()
                }

                Menu {
                    ForEach(assetClasses, id: \.id) { cls in
                        Button(cls.name) { selectedClassId = cls.id }
                    }
                } label: {
                    HStack {
                        Text(assetClasses.first(where: { $0.id == selectedClassId })?.name ?? "Select Asset Class")
                            .foregroundColor(.black)
                            .font(.system(size: 16))

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }

                addModernTextField(
                    title: "Type Name",
                    text: $typeName,
                    placeholder: "e.g., Exchange Traded Funds",
                    icon: "textformat",
                    isRequired: true
                )
                
                addModernTextField(
                    title: "Type Code",
                    text: $typeCode,
                    placeholder: "e.g., ETF",
                    icon: "number",
                    isRequired: true,
                    autoUppercase: true
                )
                
                addModernTextField(
                    title: "Description",
                    text: $typeDescription,
                    placeholder: "Brief description of this asset type",
                    icon: "text.alignleft",
                    isRequired: false
                )
                
                HStack(spacing: 16) {
                    addModernTextField(
                        title: "Sort Order",
                        text: $sortOrder,
                        placeholder: "0",
                        icon: "arrow.up.arrow.down",
                        isRequired: true
                    )

                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Active", isOn: $isActive)
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .purple.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Add Helper Views
    private func addModernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool,
        autoUppercase: Bool = false
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
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }
    
    // MARK: - Add Animations
    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            formScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            sectionsOffset = 0
        }
    }
    
    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Add Functions
    func saveInstrumentType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let dbManager = DatabaseManager()
        let success = dbManager.addInstrumentType(
            classId: selectedClassId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: Int(sortOrder) ?? 0,
            isActive: isActive
        )
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetSubClasses"), object: nil)
                self.alertMessage = "✅ Asset SubClass added successfully."
                self.showingAlert = true
            } else {
                self.alertMessage = "❌ Failed to add asset subclass. Please try again."
                self.showingAlert = true
            }
        }
    }

    func loadAssetClasses() {
        let dbManager = DatabaseManager()
        let classes = dbManager.fetchAssetClasses()
        assetClasses = classes
        if let first = classes.first {
            selectedClassId = first.id
        }
    }
}

// MARK: - Edit Asset SubClass View
struct EditAssetSubClassView: View {
    @Environment(\.presentationMode) private var presentationMode
    let typeId: Int

    @State private var assetClasses: [(id: Int, name: String)] = []
    @State private var selectedClassId: Int = 0
    
    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var sortOrder = "0"
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false
    
    // Store original values
    @State private var originalName = ""
    @State private var originalCode = ""
    @State private var originalDescription = ""
    @State private var originalSortOrder = "0"
    @State private var originalIsActive = true
    @State private var originalClassId = 0
    
    var isValid: Bool {
        !assetClasses.isEmpty && selectedClassId != 0 &&
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(sortOrder) != nil
    }
    
    private func detectChanges() {
        hasChanges = typeName != originalName ||
                     typeCode != originalCode ||
                     typeDescription != originalDescription ||
                     sortOrder != originalSortOrder ||
                     isActive != originalIsActive ||
                     selectedClassId != originalClassId
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.94, green: 0.96, blue: 0.99),
                    Color(red: 0.91, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                editModernHeader
                editChangeIndicator
                editModernContent
            }
        }
        .frame(width: 600, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadAssetClasses()
            loadTypeData()
            animateEditEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                showingAlert = false
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Edit Modern Header
    private var editModernHeader: some View {
        HStack {
            Button {
                if hasChanges {
                    showUnsavedChangesAlert()
                } else {
                    animateEditExit()
                }
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
                
                Text("Edit Asset SubClass")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            Button {
                saveEditInstrumentType()
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
                .foregroundColor(.white)
                .frame(height: 32)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if isValid && hasChanges && !isLoading {
                            Color.orange
                        } else {
                            Color.gray.opacity(0.4)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isValid && hasChanges ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid || !hasChanges)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Edit Change Indicator
    private var editChangeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }
    
    // MARK: - Edit Modern Content
    private var editModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                editFormSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Edit Form Section
    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("Type Information")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.black.opacity(0.8))
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Asset Class selection
                HStack {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Text("Asset Class*")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))

                    Spacer()
                }

                Menu {
                    ForEach(assetClasses, id: \.id) { cls in
                        Button(cls.name) { selectedClassId = cls.id; detectChanges() }
                    }
                } label: {
                    HStack {
                        Text(assetClasses.first(where: { $0.id == selectedClassId })?.name ?? "Select Asset Class")
                            .foregroundColor(.black)
                            .font(.system(size: 16))

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }

                editModernTextField(
                    title: "Type Name",
                    text: $typeName,
                    placeholder: "e.g., Exchange Traded Funds",
                    icon: "textformat",
                    isRequired: true
                )
                .onChange(of: typeName) { _, _ in detectChanges() }
                
                editModernTextField(
                    title: "Type Code",
                    text: $typeCode,
                    placeholder: "e.g., ETF",
                    icon: "number",
                    isRequired: true,
                    autoUppercase: true
                )
                .onChange(of: typeCode) { _, _ in detectChanges() }
                
                editModernTextField(
                    title: "Description",
                    text: $typeDescription,
                    placeholder: "Brief description of this asset type",
                    icon: "text.alignleft",
                    isRequired: false
                )
                .onChange(of: typeDescription) { _, _ in detectChanges() }
                
                HStack(spacing: 16) {
                    editModernTextField(
                        title: "Sort Order",
                        text: $sortOrder,
                        placeholder: "0",
                        icon: "arrow.up.arrow.down",
                        isRequired: true
                    )
                    .onChange(of: sortOrder) { _, _ in detectChanges() }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Active", isOn: $isActive)
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .onChange(of: isActive) { _, _ in detectChanges() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Edit Helper Views
    private func editModernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool,
        autoUppercase: Bool = false
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
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }
    
    // MARK: - Edit Animations
    private func animateEditEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            formScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            sectionsOffset = 0
        }
    }
    
    private func animateEditExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Edit Functions
    func loadTypeData() {
        let dbManager = DatabaseManager()
        if let details = dbManager.fetchInstrumentTypeDetails(id: typeId) {
            typeName = details.name
            typeCode = details.code
            typeDescription = details.description
            sortOrder = "\(details.sortOrder)"
            isActive = details.isActive
            selectedClassId = details.classId

            // Store original values
            originalName = typeName
            originalCode = typeCode
            originalDescription = typeDescription
            originalSortOrder = sortOrder
            originalIsActive = isActive
            originalClassId = details.classId
        }
    }
    
    private func showUnsavedChangesAlert() {
        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "You have unsaved changes. Are you sure you want to close without saving?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save & Close")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Save & Close
            saveEditInstrumentType()
        case .alertSecondButtonReturn: // Discard Changes
            animateEditExit()
        default: // Cancel
            break
        }
    }
    
    func saveEditInstrumentType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let dbManager = DatabaseManager()
        let success = dbManager.updateInstrumentType(
            id: typeId,
            classId: selectedClassId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: Int(sortOrder) ?? 0,
            isActive: isActive
        )
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                // Update original values to reflect saved state
                self.originalName = self.typeName
                self.originalCode = self.typeCode
                self.originalDescription = self.typeDescription
                self.originalSortOrder = self.sortOrder
                self.originalIsActive = self.isActive
                self.originalClassId = self.selectedClassId
                self.detectChanges()
                
                NotificationCenter.default.post(name: NSNotification.Name("RefreshAssetSubClasses"), object: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.animateEditExit()
                }
            } else {
                self.alertMessage = "❌ Failed to update asset subclass. Please try again."
                self.showingAlert = true
            }
        }
    }

    func loadAssetClasses() {
        let dbManager = DatabaseManager()
        assetClasses = dbManager.fetchAssetClasses()
        if assetClasses.isEmpty { return }
        if selectedClassId == 0 { selectedClassId = assetClasses.first!.id }
    }
}

// MARK: - Background Particles
struct TypesParticleBackground: View {
    @State private var particles: [TypesParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.purple.opacity(0.03))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<15).map { _ in
            TypesParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1200),
                    y: CGFloat.random(in: 0...800)
                ),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct TypesParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}
