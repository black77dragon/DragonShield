// DragonShield/Views/EditAccountTypeView.swift
// MARK: - Version 1.0
// MARK: - History: Initial creation to support editing Account Types.

import SwiftUI

struct EditAccountTypeView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let accountTypeId: Int
    
    @State private var typeName: String = ""
    @State private var typeCode: String = ""
    @State private var typeDescription: String = ""
    @State private var isActive: Bool = true
    
    @State private var originalData: DatabaseManager.AccountTypeData? = nil
    @State private var hasChanges = false
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    
    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(accountTypeId: Int) {
        self.accountTypeId = accountTypeId
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 0.99)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            // Reusing AddAccountTypeParticleBackground for similar visual effect
            AddAccountTypeParticleBackground()
            
            VStack(spacing: 0) {
                editModernHeader
                changeIndicator
                editModernContent
            }
        }
        .frame(width: 600, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadInitialData()
            animateEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") { showingAlert = false }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: typeName) { _, _ in detectChanges() }
        .onChange(of: typeCode) { _, _ in detectChanges() }
        .onChange(of: typeDescription) { _, _ in detectChanges() }
        .onChange(of: isActive) { _, _ in detectChanges() }
    }
    
    private var editModernHeader: some View {
        HStack {
            Button {
                if hasChanges { showUnsavedChangesAlert() } else { animateExit() }
            } label: {
                Image(systemName: "xmark")
                    .modifier(ModernSubtleButton())
            }
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)
                Text("Edit Account Type")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
            }
            Spacer()
            Button { saveChanges() } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8) }
                    else { Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark").font(.system(size: 14, weight: .bold)) }
                    Text(isLoading ? "Saving..." : "Save Changes")
                        .font(.system(size: 14, weight: .semibold))
                }
                .modifier(ModernPrimaryButton(color: .orange, isDisabled: isLoading || !isValid || !hasChanges))
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }

    private var changeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(.orange)
                    Text("Unsaved changes").font(.caption).foregroundColor(.orange)
                }
                .padding(.horizontal, 12).padding(.vertical, 4).background(Color.orange.opacity(0.1)).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .transition(.opacity.combined(with: .scale))
            }
            Spacer()
        }.padding(.horizontal, 24).animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }

    private var editModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                editFormSection
            }
            .padding(.horizontal, 24).padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }

    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Type Details", icon: "doc.text.image.fill", color: .orange)
            
            VStack(spacing: 16) {
                modernTextField(title: "Type Name*", text: $typeName, placeholder: "e.g., Account", icon: "textformat.abc", isRequired: true)
                modernTextField(title: "Type Code*", text: $typeCode, placeholder: "e.g., CUSTODY (all caps, no spaces)", icon: "number.square", isRequired: true, autoUppercase: true)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft").foregroundColor(.gray)
                        Text("Description").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
                    }
                    TextEditor(text: $typeDescription)
                        .frame(minHeight: 60, maxHeight: 100)
                        .font(.system(size: 16))
                        .padding(10)
                        .background(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                Toggle("Active", isOn: $isActive)
                    .modifier(ModernToggleStyle(tint: .orange))
            }
        }
        .modifier(ModernFormSection(color: .orange))
    }
    
    // MARK: - Reusable Helper Views
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }
    
    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool, autoUppercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray)
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            TextField(placeholder, text: text)
                .font(.system(size: 16)).foregroundColor(.black)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase { text.wrappedValue = newValue.uppercased().filter { !$0.isWhitespace } }
                }
        }
    }
    
    // MARK: - Animation and Navigation
    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    
    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50; }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }
    
    // MARK: - Data Logic
    private func loadInitialData() {
        guard let details = dbManager.fetchAccountTypeDetails(id: accountTypeId) else {
            alertMessage = "❌ Error: Could not load account type details."
            showingAlert = true
            return
        }
        self.originalData = details
        self.typeName = details.name
        self.typeCode = details.code
        self.typeDescription = details.description ?? ""
        self.isActive = details.isActive
        detectChanges() // Should be false initially
    }
    
    private func detectChanges() {
        guard let original = originalData else { return }
        hasChanges = typeName != original.name ||
                     typeCode != original.code ||
                     typeDescription != (original.description ?? "") ||
                     isActive != original.isActive
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
        case .alertFirstButtonReturn: saveChanges()
        case .alertSecondButtonReturn: animateExit()
        default: break
        }
    }
    
    private func saveChanges() {
        guard isValid else {
            alertMessage = "Type Name and Type Code cannot be empty."
            showingAlert = true
            return
        }
        
        isLoading = true
        let success = dbManager.updateAccountType(
            id: accountTypeId,
            code: typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            name: typeName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: typeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : typeDescription,
            isActive: isActive
        )
        
        DispatchQueue.main.async {
            isLoading = false
            if success {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshAccountTypes"), object: nil)
                animateExit()
            } else {
                alertMessage = "❌ Failed to update account type. The code might already be in use."
                showingAlert = true
            }
        }
    }
}
