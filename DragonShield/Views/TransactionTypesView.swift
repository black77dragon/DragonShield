import SwiftUI

// MARK: - Version 1.0
// MARK: - History: Initial creation - transaction types management with CRUD operations

struct TransactionTypesView: View {
    @State private var transactionTypes: [(id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)] = []
    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false
    @State private var selectedType: (id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)? = nil
    @State private var showingDeleteAlert = false
    @State private var typeToDelete: (id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)? = nil
    @State private var searchText = ""
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    // Filtered types based on search
    var filteredTypes: [(id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)] {
        if searchText.isEmpty {
            return transactionTypes.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            return transactionTypes.filter { type in
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
            TransactionTypesParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                typesContent
                modernActionBar
            }
        }
        .onAppear {
            loadTransactionTypes()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTransactionTypes"))) { _ in
            loadTransactionTypes()
        }
        .sheet(isPresented: $showAddTypeSheet) {
            AddTransactionTypeView()
        }
        .sheet(isPresented: $showEditTypeSheet) {
            if let type = selectedType {
                EditTransactionTypeView(typeId: type.id)
            }
        }
        .alert("Delete Transaction Type", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let type = typeToDelete {
                    confirmDelete(type)
                }
            }
        } message: {
            if let type = typeToDelete {
                Text("Are you sure you want to delete '\(type.name)'?")
            }
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Transaction Types")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text("Manage your transaction categories and classifications")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(transactionTypes.count)",
                    icon: "number.circle.fill",
                    color: .orange
                )
                
                modernStatCard(
                    title: "Position",
                    value: "\(transactionTypes.filter { $0.affectsPosition }.count)",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: .blue
                )
                
                modernStatCard(
                    title: "Income",
                    value: "\(transactionTypes.filter { $0.isIncome }.count)",
                    icon: "plus.circle.fill",
                    color: .green
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
                
                TextField("Search transaction types...", text: $searchText)
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
                    Text("Found \(filteredTypes.count) of \(transactionTypes.count) types")
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
            if filteredTypes.isEmpty {
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
                Image(systemName: searchText.isEmpty ? "tag" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No transaction types yet" : "No matching types")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(searchText.isEmpty ?
                         "Create your first transaction type to categorize your financial activities" :
                         "Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if searchText.isEmpty {
                    Button { showAddTypeSheet = true } label: {
                        Label("Add Transaction Type", systemImage: "plus")
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
                    ForEach(filteredTypes, id: \.id) { type in
                        ModernTransactionTypeRowView(
                            type: type,
                            isSelected: selectedType?.id == type.id,
                            onTap: {
                                selectedType = type
                            },
                            onEdit: {
                                selectedType = type
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
                .frame(width: 120, alignment: .leading)
            
            Text("Code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text("Description")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Position")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .center)
            
            Text("Cash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .center)
            
            Text("Income")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .center)
            
            Text("Order")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .center)
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
                    Label("Add Transaction Type", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)
                
                // Secondary actions
                if selectedType != nil {
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
                        if let type = selectedType {
                            typeToDelete = type
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
                
                // Selection indicator
                if let type = selectedType {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Selected: \(type.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.05))
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
    func loadTransactionTypes() {
        let dbManager = DatabaseManager()
        transactionTypes = dbManager.fetchTransactionTypes()
    }
    
    func confirmDelete(_ type: (id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)) {
        let dbManager = DatabaseManager()
        
        // Check if deletion is safe
        let deleteInfo = dbManager.canDeleteTransactionType(id: type.id)
        
        if deleteInfo.transactionCount > 0 {
            // Show warning dialog for types with transactions
            let alert = NSAlert()
            alert.messageText = "Delete Transaction Type with Data"
            alert.informativeText = "This transaction type '\(type.name)' is used by \(deleteInfo.transactionCount) transaction(s). Deleting it may cause data inconsistencies.\n\nAre you sure you want to proceed?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Delete Anyway")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                performDelete(type)
            }
        } else {
            // Safe to delete - no transactions use this type
            let alert = NSAlert()
            alert.messageText = "Delete Transaction Type"
            alert.informativeText = "Are you sure you want to delete '\(type.name)'?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                performDelete(type)
            }
        }
    }
    
    private func performDelete(_ type: (id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)) {
        let dbManager = DatabaseManager()
        let success = dbManager.deleteTransactionType(id: type.id)
        
        if success {
            loadTransactionTypes()
            selectedType = nil
            typeToDelete = nil
        }
    }
}

// MARK: - Modern Transaction Type Row
struct ModernTransactionTypeRowView: View {
    let type: (id: Int, code: String, name: String, description: String, affectsPosition: Bool, affectsCash: Bool, isIncome: Bool, sortOrder: Int)
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Text(type.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 120, alignment: .leading)
            
            Text(type.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 80, alignment: .leading)
            
            Text(type.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Position indicator
            Circle()
                .fill(type.affectsPosition ? Color.blue : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .frame(width: 70, alignment: .center)
            
            // Cash indicator
            Circle()
                .fill(type.affectsCash ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .frame(width: 50, alignment: .center)
            
            // Income indicator
            Circle()
                .fill(type.isIncome ? Color.purple : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .frame(width: 60, alignment: .center)
            
            Text("\(type.sortOrder)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 50, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.orange.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
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
            Button("Edit Type") {
                onEdit()
            }
            Button("Select Type") {
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

// MARK: - Add Transaction Type View
struct AddTransactionTypeView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var sortOrder = "0"
    @State private var affectsPosition = true
    @State private var affectsCash = true
    @State private var isIncome = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    
    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(sortOrder) != nil
    }
    
    // MARK: - Computed Properties
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 4.0
        
        if !typeName.isEmpty { completed += 1 }
        if !typeCode.isEmpty { completed += 1 }
        if !typeDescription.isEmpty { completed += 1 }
        completed += 1 // Always count settings
        
        return completed / total
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
            AddTransactionTypeParticleBackground()
            
            // Main content
            VStack(spacing: 0) {
                addModernHeader
                addProgressBar
                addModernContent
            }
        }
        .frame(width: 700, height: 650)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
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
                Image(systemName: "tag.circle.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                Text("Add Transaction Type")
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
                saveTransactionType()
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
                .shadow(color: isValid ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Add Progress Bar
    private var addProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(completionPercentage * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Add Modern Content
    private var addModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                addTypeInfoSection
                addBehaviorSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Type Info Section
    private var addTypeInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Type Information", icon: "tag.circle.fill", color: .orange)
            
            VStack(spacing: 16) {
                addModernTextField(
                    title: "Type Name",
                    text: $typeName,
                    placeholder: "e.g., Stock Purchase",
                    icon: "textformat",
                    isRequired: true
                )
                
                addModernTextField(
                    title: "Type Code",
                    text: $typeCode,
                    placeholder: "e.g., BUY_STOCK",
                    icon: "number",
                    isRequired: true,
                    autoUppercase: true
                )
                
                addModernTextField(
                    title: "Description",
                    text: $typeDescription,
                    placeholder: "Brief description of this transaction type",
                    icon: "text.alignleft",
                    isRequired: false
                )
                
                addModernTextField(
                    title: "Sort Order",
                    text: $sortOrder,
                    placeholder: "0",
                    icon: "arrow.up.arrow.down",
                    isRequired: true
                )
            }
        }
        .padding(24)
        .background(addTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Behavior Section
    private var addBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Transaction Behavior", icon: "gearshape.circle.fill", color: .blue)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Affects Position Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Position")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes security holdings", isOn: $affectsPosition)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
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
                    
                    // Affects Cash Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Cash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes cash balance", isOn: $affectsCash)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
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
                
                // Is Income Toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Income Transaction")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        
                        Spacer()
                    }
                    
                    Toggle("This is an income transaction (dividends, interest, etc.)", isOn: $isIncome)
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
            }
        }
        .padding(24)
        .background(addTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Add Glassmorphism Background
    private var addTransactionTypeGlassMorphismBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .white.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            .orange.opacity(0.05),
                            .blue.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Helper Views
    private func addSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
    
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
                .onChange(of: text.wrappedValue) { oldValue, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }
    
    // MARK: - Animations
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
    
    // MARK: - Functions
    func saveTransactionType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let dbManager = DatabaseManager()
        let success = dbManager.addTransactionType(
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            affectsPosition: affectsPosition,
            affectsCash: affectsCash,
            isIncome: isIncome,
            sortOrder: Int(sortOrder) ?? 0
        )
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshTransactionTypes"), object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.animateAddExit()
                }
            } else {
                self.alertMessage = "❌ Failed to add transaction type. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Edit Transaction Type View
struct EditTransactionTypeView: View {
    @Environment(\.presentationMode) private var presentationMode
    let typeId: Int
    
    @State private var typeName = ""
    @State private var typeCode = ""
    @State private var typeDescription = ""
    @State private var sortOrder = "0"
    @State private var affectsPosition = true
    @State private var affectsCash = true
    @State private var isIncome = false
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
    @State private var originalAffectsPosition = true
    @State private var originalAffectsCash = true
    @State private var originalIsIncome = false
    
    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(sortOrder) != nil
    }
    
    private func detectChanges() {
        hasChanges = typeName != originalName ||
                    typeCode != originalCode ||
                    typeDescription != originalDescription ||
                    sortOrder != originalSortOrder ||
                    affectsPosition != originalAffectsPosition ||
                    affectsCash != originalAffectsCash ||
                    isIncome != originalIsIncome
    }
    
    // MARK: - Computed Properties
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 4.0
        
        if !typeName.isEmpty { completed += 1 }
        if !typeCode.isEmpty { completed += 1 }
        if !typeDescription.isEmpty { completed += 1 }
        completed += 1 // Always count settings
        
        return completed / total
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
            
            // Background particles
            EditTransactionTypeParticleBackground()
            
            // Main content
            VStack(spacing: 0) {
                editModernHeader
                editChangeIndicator
                editProgressBar
                editModernContent
            }
        }
        .frame(width: 700, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
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
                Image(systemName: "tag.circle.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                
                Text("Edit Transaction Type")
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
                saveEditTransactionType()
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
    
    // MARK: - Edit Progress Bar
    private var editProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(completionPercentage * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Edit Modern Content
    private var editModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                editTypeInfoSection
                editBehaviorSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Edit Type Info Section
    private var editTypeInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            editSectionHeader(title: "Type Information", icon: "tag.circle.fill", color: .orange)
            
            VStack(spacing: 16) {
                editModernTextField(
                    title: "Type Name",
                    text: $typeName,
                    placeholder: "e.g., Stock Purchase",
                    icon: "textformat",
                    isRequired: true
                )
                .onChange(of: typeName) { oldValue, newValue in detectChanges() }
                
                editModernTextField(
                    title: "Type Code",
                    text: $typeCode,
                    placeholder: "e.g., BUY_STOCK",
                    icon: "number",
                    isRequired: true,
                    autoUppercase: true
                )
                .onChange(of: typeCode) { oldValue, newValue in detectChanges() }
                
                editModernTextField(
                    title: "Description",
                    text: $typeDescription,
                    placeholder: "Brief description of this transaction type",
                    icon: "text.alignleft",
                    isRequired: false
                )
                .onChange(of: typeDescription) { oldValue, newValue in detectChanges() }
                
                editModernTextField(
                    title: "Sort Order",
                    text: $sortOrder,
                    placeholder: "0",
                    icon: "arrow.up.arrow.down",
                    isRequired: true
                )
                .onChange(of: sortOrder) { oldValue, newValue in detectChanges() }
            }
        }
        .padding(24)
        .background(editTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Edit Behavior Section
    private var editBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            editSectionHeader(title: "Transaction Behavior", icon: "gearshape.circle.fill", color: .blue)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Affects Position Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Position")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes security holdings", isOn: $affectsPosition)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .onChange(of: affectsPosition) { oldValue, newValue in detectChanges() }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Affects Cash Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("Affects Cash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                            
                            Spacer()
                        }
                        
                        Toggle("Changes cash balance", isOn: $affectsCash)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .onChange(of: affectsCash) { oldValue, newValue in detectChanges() }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Is Income Toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Income Transaction")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        
                        Spacer()
                    }
                    
                    Toggle("This is an income transaction (dividends, interest, etc.)", isOn: $isIncome)
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
                        .onChange(of: isIncome) { oldValue, newValue in detectChanges() }
                }
            }
        }
        .padding(24)
        .background(editTransactionTypeGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Edit Glassmorphism Background
    private var editTransactionTypeGlassMorphismBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.85),
                            .white.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            .orange.opacity(0.05),
                            .blue.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Helper Views
    private func editSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
    
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
                .onChange(of: text.wrappedValue) { oldValue, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
        }
    }
    
    // MARK: - Animations
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
    
    // MARK: - Functions
    func loadTypeData() {
        let dbManager = DatabaseManager()
        if let details = dbManager.fetchTransactionTypeDetails(id: typeId) {
            typeName = details.name
            typeCode = details.code
            typeDescription = details.description
            sortOrder = "\(details.sortOrder)"
            affectsPosition = details.affectsPosition
            affectsCash = details.affectsCash
            isIncome = details.isIncome
            
            // Store original values
            originalName = typeName
            originalCode = typeCode
            originalDescription = typeDescription
            originalSortOrder = sortOrder
            originalAffectsPosition = affectsPosition
            originalAffectsCash = affectsCash
            originalIsIncome = isIncome
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
            saveEditTransactionType()
        case .alertSecondButtonReturn: // Discard Changes
            animateEditExit()
        default: // Cancel
            break
        }
    }
    
    func saveEditTransactionType() {
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let dbManager = DatabaseManager()
        let success = dbManager.updateTransactionType(
            id: typeId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            affectsPosition: affectsPosition,
            affectsCash: affectsCash,
            isIncome: isIncome,
            sortOrder: Int(sortOrder) ?? 0
        )
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                // Update original values to reflect saved state
                self.originalName = self.typeName
                self.originalCode = self.typeCode
                self.originalDescription = self.typeDescription
                self.originalSortOrder = self.sortOrder
                self.originalAffectsPosition = self.affectsPosition
                self.originalAffectsCash = self.affectsCash
                self.originalIsIncome = self.isIncome
                self.detectChanges()
                
                NotificationCenter.default.post(name: NSNotification.Name("RefreshTransactionTypes"), object: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.animateEditExit()
                }
            } else {
                self.alertMessage = "❌ Failed to update transaction type. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Background Particles for Add/Edit Views
struct AddTransactionTypeParticleBackground: View {
    @State private var particles: [AddTransactionTypeParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.04))
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
        particles = (0..<12).map { _ in
            AddTransactionTypeParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...650)
                ),
                size: CGFloat.random(in: 3...9),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 800
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct EditTransactionTypeParticleBackground: View {
    @State private var particles: [EditTransactionTypeParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.04))
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
        particles = (0..<12).map { _ in
            EditTransactionTypeParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...700)
                ),
                size: CGFloat.random(in: 3...9),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 900
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct AddTransactionTypeParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct EditTransactionTypeParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

// MARK: - Background Particles
struct TransactionTypesParticleBackground: View {
    @State private var particles: [TransactionTypesParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.03))
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
            TransactionTypesParticle(
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

struct TransactionTypesParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}
