// DragonShield/Views/AccountTypesView.swift
// MARK: - Version 1.4
// MARK: - History
// - 1.3 -> 1.4: Implemented Edit functionality for account types.
// - 1.2 -> 1.3: Corrected .alert modifier logic to resolve compiler errors.
// - 1.1 -> 1.2: Re-included helper structs to fix scope issues.
// - 1.0 -> 1.1: Implemented Add and Delete functionality.

import SwiftUI

struct AccountTypesView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var accountTypes: [DatabaseManager.AccountTypeData] = []
    @State private var selectedType: DatabaseManager.AccountTypeData? = nil
    @State private var searchText = ""

    @State private var showAddTypeSheet = false
    @State private var showEditTypeSheet = false // Added for edit sheet
    
    @State private var showingDeleteAlert = false
    @State private var typeToDelete: DatabaseManager.AccountTypeData? = nil

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    var filteredTypes: [DatabaseManager.AccountTypeData] {
        if searchText.isEmpty {
            return accountTypes
        } else {
            return accountTypes.filter { type in
                type.name.localizedCaseInsensitiveContains(searchText) ||
                type.code.localizedCaseInsensitiveContains(searchText) ||
                (type.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.93, green: 0.95, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            AccountTypesParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                typesContent
                modernActionBar
            }
        }
        .onAppear {
            loadAccountTypes()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshAccountTypes"))) { _ in
            loadAccountTypes()
        }
        .sheet(isPresented: $showAddTypeSheet) {
            AddAccountTypeView().environmentObject(dbManager)
        }
        // NEW: Sheet for editing an account type
        .sheet(isPresented: $showEditTypeSheet) {
            if let type = selectedType {
                EditAccountTypeView(accountTypeId: type.id).environmentObject(dbManager)
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            guard let type = typeToDelete else {
                return Alert(title: Text("Error"), message: Text("No type selected for deletion."), dismissButton: .default(Text("OK")))
            }

            let deleteCheckResult = dbManager.canDeleteAccountType(id: type.id)

            if deleteCheckResult.canDelete {
                return Alert(
                    title: Text("Delete Account Type"),
                    message: Text("Are you sure you want to delete '\(type.name)'? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        performDelete(type)
                    },
                    secondaryButton: .cancel {
                        typeToDelete = nil
                    }
                )
            } else {
                return Alert(
                    title: Text("Cannot Delete Account Type"),
                    message: Text(deleteCheckResult.message),
                    dismissButton: .default(Text("OK")) {
                        typeToDelete = nil
                    }
                )
            }
        }
    }
    
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color.indigo)
                    Text("Account Types")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
                }
                Text("Manage types for your accounts")
                    .font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(accountTypes.count)", icon: "number.circle.fill", color: .indigo)
                modernStatCard(title: "Active", value: "\(accountTypes.filter { $0.isActive }.count)", icon: "checkmark.circle.fill", color: .green)
            }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search account types (name, code, description...)", text: $searchText).textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty { Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle()) }
            }.padding(.horizontal, 16).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1)))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            if !searchText.isEmpty && !filteredTypes.isEmpty { HStack { Text("Found \(filteredTypes.count) of \(accountTypes.count) types").font(.caption).foregroundColor(.gray); Spacer() } }
        }.padding(.horizontal, 24).offset(y: contentOffset)
    }
    
    private var typesContent: some View {
        VStack(spacing: 16) {
            if accountTypes.isEmpty && searchText.isEmpty { emptyStateView }
            else if filteredTypes.isEmpty && !searchText.isEmpty { emptyStateView }
            else { typesTable }
        }.padding(.horizontal, 24).padding(.top, 16).offset(y: contentOffset)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty && accountTypes.isEmpty ? "doc.plaintext.fill" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 8) {
                    Text(searchText.isEmpty && accountTypes.isEmpty ? "No account types found" : "No matching account types")
                        .font(.title2).fontWeight(.semibold).foregroundColor(.gray)
                    Text(searchText.isEmpty && accountTypes.isEmpty ? "Add your first account type using the button below." : "Try adjusting your search terms.")
                        .font(.body).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                if searchText.isEmpty && accountTypes.isEmpty {
                    Button { showAddTypeSheet = true } label: {
                        Label("Add Account Type", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                }
            }
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var typesTable: some View {
        VStack(spacing: 0) {
            modernTableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(filteredTypes) { type in
                        ModernAccountTypeRowView(
                            type: type, isSelected: selectedType?.id == type.id,
                            rowPadding: CGFloat(dbManager.tableRowPadding),
                            onTap: { selectedType = type },
                            onEdit: { // Added onEdit closure
                                selectedType = type
                                showEditTypeSheet = true
                            }
                        )
                    }
                }
            }.background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    private var modernTableHeader: some View {
        HStack {
            Text("Name").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 200, alignment: .leading)
            Text("Code").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 100, alignment: .leading)
            Text("Description").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .center)
        }.padding(.horizontal, CGFloat(dbManager.tableRowPadding))
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))).padding(.bottom, 1)
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
            HStack(spacing: 16) {
                Button { showAddTypeSheet = true } label: {
                    Label("Add Account Type", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.67, green: 0.89, blue: 0.67))
                .foregroundColor(.black)

                if selectedType != nil {
                     // MODIFIED: Edit button is now enabled
                     Button {
                         showEditTypeSheet = true
                     } label: {
                        HStack(spacing: 6) { Image(systemName: "pencil"); Text("Edit") }
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.blue)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(ScaleButtonStyle())

                    Button {
                        if let type = selectedType {
                            self.typeToDelete = type
                            self.showingDeleteAlert = true
                        }
                    } label: {
                        HStack(spacing: 6) { Image(systemName: "trash"); Text("Delete") }
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.red)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.red.opacity(0.1)).clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }.buttonStyle(ScaleButtonStyle())
                }
                Spacer()
                if let type = selectedType {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.indigo)
                        Text("Selected: \(type.name)").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                    }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.indigo.opacity(0.05)).clipShape(Capsule())
                }
            }.padding(.horizontal, 24).padding(.vertical, 16).background(.regularMaterial)
        }.opacity(buttonsOpacity)
    }

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) { Image(systemName: icon).font(.system(size: 12)).foregroundColor(color); Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.gray) }
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
        }.padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1)))
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
    }

    func loadAccountTypes() {
         accountTypes = dbManager.fetchAccountTypes(activeOnly: false)
    }

    private func performDelete(_ type: DatabaseManager.AccountTypeData) {
        let success = dbManager.deleteAccountType(id: type.id)
        if success {
            loadAccountTypes()
            selectedType = nil
            typeToDelete = nil
        }
    }
}

// MODIFIED: Added onEdit closure
struct ModernAccountTypeRowView: View {
    let type: DatabaseManager.AccountTypeData
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Text(type.name)
                .font(.system(size: 15, weight: .medium)).foregroundColor(.primary)
                .frame(width: 200, alignment: .leading)
            
            Text(type.code)
                .font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 100, alignment: .leading)
            
            Text(type.description ?? "")
                .font(.system(size: 14)).foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 4) {
                Circle().fill(type.isActive ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(type.isActive ? "Active" : "Inactive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(type.isActive ? .green : .orange)
            }.frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, rowPadding)
        .padding(.vertical, rowPadding / 1.5)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.indigo.opacity(0.1) : Color.clear).overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.indigo.opacity(0.3) : Color.clear, lineWidth: 1)))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() } // Double-tap to edit
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contextMenu { // Added Edit to context menu
             Button("Edit '\(type.name)'") {
                onEdit()
            }
            Divider()
            Button("Select") {
                onTap()
            }
        }
    }
}

// Background particle struct and view remain the same
struct AccountTypeParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct AccountTypesParticleBackground: View {
    @State private var particles: [AccountTypeParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.indigo.opacity(0.03))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<15).map { _ in
            AccountTypeParticle(
                position: CGPoint(x: CGFloat.random(in: 0...1200), y: CGFloat.random(in: 0...800)),
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

struct AccountTypesView_Previews: PreviewProvider {
    static var previews: some View {
        AccountTypesView().environmentObject(DatabaseManager())
    }
}
