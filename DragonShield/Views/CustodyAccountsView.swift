// DragonShield/Views/CustodyAccountsView.swift
// MARK: - Version 1.6
// MARK: - History
// - 1.4 -> 1.5: Accounts now reference Institutions. Added picker fields.
// - 1.5 -> 1.6: Added institution picker to Edit view to resolve compile error.
// - 1.3 -> 1.4: Updated deprecated onChange modifiers to new syntax for macOS 14.0+.
// - 1.2 -> 1.3: Updated Add/Edit views to use Picker for AccountType based on normalized schema.
// - 1.2 (Corrected - Full): Ensured all helper views like accountsContent, emptyStateView, accountsTable are fully defined within CustodyAccountsView. Provided full implementations for helper functions in Add/Edit views and fixed animation function signatures.
// - 1.1 -> 1.2: Updated Add/Edit views to include institutionBic, optional openingDate, and optional closingDate.
// - 1.0 -> 1.1: Fixed EditCustodyAccountView initializer access level and incorrect String.trim() calls. Corrected onChange usage in text fields.

import SwiftUI

// Main View for Custody Accounts
struct CustodyAccountsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var accounts: [DatabaseManager.AccountData] = []
    @State private var showAddAccountSheet = false
    @State private var showEditAccountSheet = false
    @State private var selectedAccount: DatabaseManager.AccountData? = nil
    @State private var showingDeleteAlert = false
    @State private var accountToDelete: DatabaseManager.AccountData? = nil
    @State private var searchText = ""

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    var filteredAccounts: [DatabaseManager.AccountData] {
        if searchText.isEmpty {
            return accounts.sorted { $0.accountName.localizedCaseInsensitiveCompare($1.accountName) == .orderedAscending }
        } else {
            return accounts.filter { account in
                account.accountName.localizedCaseInsensitiveContains(searchText) ||
                account.institutionName.localizedCaseInsensitiveContains(searchText) ||
                (account.institutionBic?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                account.accountNumber.localizedCaseInsensitiveContains(searchText) ||
                account.accountType.localizedCaseInsensitiveContains(searchText) // Search by type name
            }.sorted { $0.accountName.localizedCaseInsensitiveCompare($1.accountName) == .orderedAscending }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.93, green: 0.95, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                accountsContent
                modernActionBar
            }
        }
        .onAppear {
            loadAccounts()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCustodyAccounts"))) { _ in
            loadAccounts()
        }
        .onChange(of: dbManager.tableRowSpacing) { _, _ in }
        .onChange(of: dbManager.tableRowPadding) { _, _ in }
        .sheet(isPresented: $showAddAccountSheet) {
            AddCustodyAccountView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditAccountSheet) {
            if let account = selectedAccount {
                EditCustodyAccountView(accountId: account.id).environmentObject(dbManager)
            }
        }
        .confirmationDialog("Account Action", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("Disable Account", role: .destructive) {
                if let account = accountToDelete { confirmDisable(account) }
            }
            Button("Delete Account", role: .destructive) {
                if let account = accountToDelete { confirmDelete(account) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let account = accountToDelete {
                Text("Choose whether to disable or permanently delete '\(account.accountName)' (\(account.accountNumber)). Accounts can only be modified if no instruments are linked.")
            }
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns.fill").font(.system(size: 32)).foregroundColor(.blue)
                    Text("Custody Accounts").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
                }
                Text("Manage your brokerage, bank, and exchange accounts").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(accounts.count)", icon: "number.circle.fill", color: .blue)
                modernStatCard(title: "Active", value: "\(accounts.filter { $0.isActive }.count)", icon: "checkmark.circle.fill", color: .green)
            }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }

    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search accounts...", text: $searchText).textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty { Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle()) }
            }.padding(.horizontal, 16).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1)))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            if !searchText.isEmpty && !filteredAccounts.isEmpty { HStack { Text("Found \(filteredAccounts.count) of \(accounts.count) accounts").font(.caption).foregroundColor(.gray); Spacer() } }
        }.padding(.horizontal, 24).offset(y: contentOffset)
    }
    
    private var accountsContent: some View {
        VStack(spacing: 16) {
            if filteredAccounts.isEmpty && accounts.isEmpty && searchText.isEmpty { // Show if DB is empty and no search
                emptyStateView
            } else if filteredAccounts.isEmpty && !searchText.isEmpty { // Show if search yields no results
                 emptyStateView
            }
            else {
                accountsTable
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
                Image(systemName: searchText.isEmpty && accounts.isEmpty ? "building.columns" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 8) {
                    Text(searchText.isEmpty && accounts.isEmpty ? "No custody accounts yet" : "No matching accounts")
                        .font(.title2).fontWeight(.semibold).foregroundColor(.gray)
                    Text(searchText.isEmpty && accounts.isEmpty ? "Add your first custody account to get started." : "Try adjusting your search terms.")
                        .font(.body).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                if searchText.isEmpty && accounts.isEmpty {
                    Button { showAddAccountSheet = true } label: {
                        HStack(spacing: 8) { Image(systemName: "plus"); Text("Add First Account") }
                        .font(.headline).foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.blue).clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, 8)
                }
            }
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accountsTable: some View {
        VStack(spacing: 0) {
            modernTableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(filteredAccounts) { account in
                        ModernCustodyAccountRowView(
                            account: account,
                            isSelected: selectedAccount?.id == account.id,
                            rowPadding: CGFloat(dbManager.tableRowPadding),
                            onTap: { selectedAccount = account },
                            onEdit: { selectedAccount = account; showEditAccountSheet = true }
                        )
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    private var modernTableHeader: some View {
        HStack {
            Text("Account Name").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text("Institution").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 150, alignment: .leading)
            Text("Type").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 100, alignment: .leading) // Adjusted width for type name
            Text("Currency").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .center)
            Text("In Portfolio").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .center)
            Text("Status").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .center)
        }.padding(.horizontal, CGFloat(dbManager.tableRowPadding)).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))).padding(.bottom, 1)
    }

    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
            HStack(spacing: 16) {
                Button { showAddAccountSheet = true } label: { HStack(spacing: 8) { Image(systemName: "plus"); Text("Add New Account") }.font(.system(size: 16, weight: .semibold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12).background(Color.blue).clipShape(Capsule()) .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3) }.buttonStyle(ScaleButtonStyle())
                if selectedAccount != nil {
                    Button { showEditAccountSheet = true } label: { HStack(spacing: 6) { Image(systemName: "pencil"); Text("Edit") }.font(.system(size: 14, weight: .medium)).foregroundColor(.orange) .padding(.horizontal, 16).padding(.vertical, 10).background(Color.orange.opacity(0.1)).clipShape(Capsule()).overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1)) }.buttonStyle(ScaleButtonStyle())
                    Button { if let acc = selectedAccount { accountToDelete = acc; showingDeleteAlert = true } } label: { HStack(spacing: 6) { Image(systemName: "trash"); Text("Delete") }.font(.system(size: 14, weight: .medium)).foregroundColor(.red).padding(.horizontal, 16).padding(.vertical, 10).background(Color.red.opacity(0.1)).clipShape(Capsule()).overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1)) }.buttonStyle(ScaleButtonStyle())
                }
                Spacer()
                if let account = selectedAccount { HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundColor(.blue); Text("Selected: \(account.accountName.prefix(20))\(account.accountName.count > 20 ? "..." : "")").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary) }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.05)).clipShape(Capsule()) }
            }.padding(.horizontal, 24).padding(.vertical, 16).background(.regularMaterial)
        }.opacity(buttonsOpacity)
    }

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) { Image(systemName: icon).font(.system(size: 12)).foregroundColor(color); Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.gray) }
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
        }.padding(.horizontal, 12).padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))).shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
    }
    
    func loadAccounts() {
        accounts = self.dbManager.fetchAccounts()
    }

    func confirmDisable(_ account: DatabaseManager.AccountData) {
        let result = dbManager.canDeleteAccount(id: account.id)
        if result.canDelete {
            let alert = NSAlert()
            alert.messageText = "Disable Account"
            alert.informativeText = "Are you sure you want to disable '\(account.accountName)'?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Disable")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                if dbManager.disableAccount(id: account.id) {
                    loadAccounts()
                    selectedAccount = nil
                    accountToDelete = nil
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Cannot Disable Account"
            alert.informativeText = result.message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func confirmDelete(_ account: DatabaseManager.AccountData) {
        let result = dbManager.canDeleteAccount(id: account.id)
        if result.canDelete {
            let alert = NSAlert()
            alert.messageText = "Delete Account"
            alert.informativeText = "Are you sure you want to permanently delete '\(account.accountName)'?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                if dbManager.deleteAccount(id: account.id) {
                    loadAccounts()
                    selectedAccount = nil
                    accountToDelete = nil
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Cannot Delete Account"
            alert.informativeText = result.message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

struct ModernCustodyAccountRowView: View {
    let account: DatabaseManager.AccountData // No change needed here as accountType is already the name
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void

    private static var displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                Text("Number: \(account.accountNumber)").font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
                if let bic = account.institutionBic, !bic.isEmpty { Text("BIC: \(bic)").font(.caption2).foregroundColor(.gray.opacity(0.8)) }
                if let openingDate = account.openingDate { Text("Opened: \(openingDate, formatter: Self.displayDateFormatter)").font(.caption2).foregroundColor(.gray.opacity(0.8)) }
                if let closingDate = account.closingDate { Text("Closed: \(closingDate, formatter: Self.displayDateFormatter)").font(.caption2).foregroundColor(account.isActive ? .gray.opacity(0.8) : .orange) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(account.institutionName).font(.system(size: 14)).foregroundColor(.secondary).frame(width: 150, alignment: .leading)
            Text(account.accountType).font(.system(size: 14)).foregroundColor(.secondary).frame(width: 100, alignment: .leading) // Will display type name
            Text(account.currencyCode).font(.system(size: 14, weight: .medium)).foregroundColor(.blue).frame(width: 80, alignment: .center)
            Image(systemName: account.includeInPortfolio ? "largecircle.fill.circle" : "circle").foregroundColor(account.includeInPortfolio ? .green : .gray).frame(width: 80, alignment: .center)
            HStack(spacing: 4) {
                Circle().fill(account.isActive ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(account.isActive ? "Active" : "Inactive").font(.system(size: 12, weight: .medium)).foregroundColor(account.isActive ? .green : .orange)
            }.frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16).padding(.vertical, rowPadding)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.blue.opacity(0.1) : Color.clear).overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)))
        .contentShape(Rectangle()).onTapGesture { onTap() }.onTapGesture(count: 2) { onEdit() }
        .contextMenu { Button("Edit Account") { onEdit() }; Button("Select Account") { onTap() } }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// Add Custody Account View - MODIFIED
struct AddCustodyAccountView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    
    @State private var accountName: String = ""
    @State private var selectedInstitutionId: Int? = nil
    @State private var availableInstitutions: [DatabaseManager.InstitutionData] = []
    @State private var accountNumber: String = ""
    // MODIFIED: Use selectedAccountTypeId and availableAccountTypes
    @State private var selectedAccountTypeId: Int? = nil
    @State private var availableAccountTypes: [DatabaseManager.AccountTypeData] = []
    
    @State private var currencyCode: String = ""
    @State private var setOpeningDate: Bool = false
    @State private var openingDateInput: Date = Date()
    @State private var setClosingDate: Bool = false
    @State private var closingDateInput: Date = Date()
    @State private var includeInPortfolio: Bool = true
    @State private var isActive: Bool = true
    @State private var notes: String = ""
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedInstitutionId != nil &&
        !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedAccountTypeId != nil &&
        !currencyCode.isEmpty &&
        (setClosingDate ? (setOpeningDate ? closingDateInput >= openingDateInput : true) : true)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) { addModernHeader; addModernContent; }
        }.frame(width: 650, height: 820).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale).onAppear { loadInitialData(); animateAddEntrance(); }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.contains("✅") { animateAddExit() } else { showingAlert = false } } } message: { Text(alertMessage) }
    }

    private var addModernHeader: some View {
        HStack {
            Button { animateAddExit() } label: { Image(systemName: "xmark").modifier(ModernSubtleButton()) }; Spacer()
            HStack(spacing: 12) { Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(.blue); Text("Add Custody Account").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)) }; Spacer()
            Button { saveAccount() } label: { HStack(spacing: 8) { if isLoading { ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8) } else { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }; Text(isLoading ? "Saving..." : "Save") .font(.system(size: 14, weight: .semibold)) }.modifier(ModernPrimaryButton(color: .blue, isDisabled: isLoading || !isValid)) }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    
    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50; }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }

    private func addModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(.gray)
                Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            TextField(placeholder, text: text)
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }

    // MODIFIED: Replaced accountType TextField with a Picker
private var accountTypePickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill").foregroundColor(.gray)
                Text("Account Type*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            Picker("Account Type*", selection: $selectedAccountTypeId) {
                Text("Select Account Type...").tag(nil as Int?) // Optional tag for placeholder
                ForEach(availableAccountTypes) { type in
                    Text(type.name).tag(type.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedAccountTypeId == nil && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if selectedAccountTypeId == nil && !isValid && showingAlert {
                Text("Account Type is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }


    // Picker for selecting the associated institution - used in Add/Edit forms
    private var institutionPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill").foregroundColor(.gray)
                Text("Institution*")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
            }
            Picker("Institution*", selection: $selectedInstitutionId) {
                Text("Select Institution...").tag(nil as Int?)
                ForEach(availableInstitutions) { inst in
                    Text(inst.name).tag(inst.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedInstitutionId == nil && !isValid && showingAlert ?
                            Color.red.opacity(0.6) : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
            if selectedInstitutionId == nil && !isValid && showingAlert {
                Text("Institution is required.")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }

    
    private var addModernContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Account Details", icon: "pencil.and.scribble", color: .blue)
                    addModernTextField(title: "Account Name*", text: $accountName, placeholder: "e.g., Main Trading Account", icon: "tag.fill", isRequired: true)
                    institutionPickerField
                    addModernTextField(title: "Account Number*", text: $accountNumber, placeholder: "e.g., U1234567", icon: "number.square.fill", isRequired: true)
                    accountTypePickerField // MODIFIED: Using Picker
                }.modifier(ModernFormSection(color: .blue))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Financial & Dates", icon: "calendar.badge.clock", color: .green)
                    currencyPickerField
                    Toggle(isOn: $setOpeningDate.animation()) { Text("Set Opening Date") }.modifier(ModernToggleStyle(tint: .green))
                    if setOpeningDate {
                        DatePicker(selection: $openingDateInput, displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.plus").foregroundColor(.gray); Text("Opening Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                    }
                    Toggle(isOn: $setClosingDate.animation()) { Text("Set Closing Date") }.modifier(ModernToggleStyle(tint: .orange))
                    if setClosingDate {
                        DatePicker(selection: $closingDateInput, in: (setOpeningDate ? openingDateInput... : Date.distantPast...), displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.minus").foregroundColor(.gray); Text("Closing Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                        if setOpeningDate && closingDateInput < openingDateInput && setClosingDate { Text("Closing date must be on or after opening date.").font(.caption).foregroundColor(.red).padding(.leading, 16) }
                    }
                }.modifier(ModernFormSection(color: .green))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Settings & Notes", icon: "gearshape.fill", color: .purple)
                    Toggle(isOn: $includeInPortfolio) { Text("Include in Portfolio Calculations") }.modifier(ModernToggleStyle(tint: .purple))
                    Toggle(isOn: $isActive) { Text("Account is Active") }.modifier(ModernToggleStyle(tint: .green))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "note.text").foregroundColor(.gray); Text("Notes").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
                        TextEditor(text: $notes).frame(minHeight: 80, maxHeight: 150).font(.system(size: 16)).padding(12)
                            .background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }.modifier(ModernFormSection(color: .purple))
            }.padding(.horizontal, 24).padding(.bottom, 100)
        }.offset(y: sectionsOffset)
    }
    private var currencyPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "dollarsign.circle.fill").foregroundColor(.gray); Text("Default Currency*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
            Picker("Default Currency*", selection: $currencyCode) { Text("Select Currency...").tag(""); ForEach(availableCurrencies, id: \.code) { curr in Text("\(curr.name) (\(curr.code))").tag(curr.code) } }
            .pickerStyle(MenuPickerStyle()).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(currencyCode.isEmpty && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if currencyCode.isEmpty && !isValid && showingAlert { Text("Currency is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }
    private func loadInitialData() {
        availableCurrencies = dbManager.fetchActiveCurrencies()
        availableAccountTypes = dbManager.fetchAccountTypes(activeOnly: true)
        availableInstitutions = dbManager.fetchInstitutions(activeOnly: true)
        if let chfCurrency = availableCurrencies.first(where: {$0.code == "CHF"}) { currencyCode = chfCurrency.code } else if let firstCurrency = availableCurrencies.first { currencyCode = firstCurrency.code }
        if let firstInst = availableInstitutions.first { selectedInstitutionId = firstInst.id }
        // Optionally set a default account type if desired, e.g., the first one
        // if !availableAccountTypes.isEmpty { selectedAccountTypeId = availableAccountTypes[0].id }
        setOpeningDate = false; openingDateInput = Date(); setClosingDate = false; closingDateInput = Date();
    }
    private func saveAccount() {
        guard isValid, let typeId = selectedAccountTypeId, let instId = selectedInstitutionId else {
            var errorMsg = "Please fill all mandatory fields (*)."; if setClosingDate && setOpeningDate && closingDateInput < openingDateInput { errorMsg += "\nClosing date cannot be before opening date." }; if selectedAccountTypeId == nil { errorMsg += "\nAccount Type is required."}
            alertMessage = errorMsg; showingAlert = true; return
        }
        isLoading = true
        let finalOpeningDate: Date? = setOpeningDate ? openingDateInput : nil; let finalClosingDate: Date? = setClosingDate ? closingDateInput : nil
        let success = dbManager.addAccount(
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionId: instId,
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: typeId, // Pass selected ID
            currencyCode: currencyCode,
            openingDate: finalOpeningDate,
            closingDate: finalClosingDate,
            includeInPortfolio: includeInPortfolio,
            isActive: isActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if success { alertMessage = "✅ Account '\(accountName)' added successfully!"; NotificationCenter.default.post(name: NSNotification.Name("RefreshCustodyAccounts"), object: nil);
        } else { alertMessage = "❌ Failed to add account. Please try again."; if alertMessage.contains("UNIQUE constraint failed: Accounts.account_number") { alertMessage = "❌ Failed to add account: Account Number must be unique."} }
        showingAlert = true
    }
}

// Edit Custody Account View - MODIFIED
struct EditCustodyAccountView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let accountId: Int
    
    @State private var accountName: String = ""
    @State private var selectedInstitutionId: Int? = nil
    @State private var availableInstitutions: [DatabaseManager.InstitutionData] = []
    @State private var accountNumber: String = ""
    // MODIFIED: Use selectedAccountTypeId and availableAccountTypes
    @State private var selectedAccountTypeId: Int? = nil
    @State private var availableAccountTypes: [DatabaseManager.AccountTypeData] = []
    
    @State private var currencyCode: String = "";
    @State private var setOpeningDate: Bool = false; @State private var openingDateInput: Date = Date(); @State private var setClosingDate: Bool = false; @State private var closingDateInput: Date = Date();
    @State private var includeInPortfolio: Bool = true; @State private var isActive: Bool = true; @State private var notes: String = "";
    @State private var originalData: DatabaseManager.AccountData? = nil; @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = [];
    @State private var originalSetOpeningDate: Bool = false; @State private var originalOpeningDateInput: Date = Date(); @State private var originalSetClosingDate: Bool = false; @State private var originalClosingDateInput: Date = Date();
    @State private var showingAlert = false; @State private var alertMessage = ""; @State private var isLoading = false; @State private var hasChanges = false;
    @State private var formScale: CGFloat = 0.9; @State private var headerOpacity: Double = 0; @State private var sectionsOffset: CGFloat = 50;

    init(accountId: Int) { self.accountId = accountId }
    var isValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedInstitutionId != nil &&
        !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedAccountTypeId != nil &&
        !currencyCode.isEmpty &&
        (setClosingDate ? (setOpeningDate ? closingDateInput >= openingDateInput : true) : true)
    }
    private func detectChanges() {
        guard let original = originalData, let originalAccTypeId = original.accountTypeId as Int? else { hasChanges = true; return } // Ensure originalData and ID are valid
        let co: Date? = setOpeningDate ? openingDateInput : nil; let oo: Date? = originalSetOpeningDate ? originalOpeningDateInput : nil;
        let cc: Date? = setClosingDate ? closingDateInput : nil; let oc: Date? = originalSetClosingDate ? originalClosingDateInput : nil;
        hasChanges = accountName != original.accountName ||
                         selectedInstitutionId != original.institutionId ||
                         accountNumber != original.accountNumber ||
                         selectedAccountTypeId != originalAccTypeId || // MODIFIED
                         currencyCode != original.currencyCode ||
                         co != oo ||
                         cc != oc ||
                         includeInPortfolio != original.includeInPortfolio ||
                         isActive != original.isActive ||
                         notes != (original.notes ?? "")
    }

    var body: some View {
       ZStack {
            LinearGradient(colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) { editModernHeader; changeIndicator; editModernContent; }
        }.frame(width: 650, height: 820).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale).onAppear { loadAccountData(); animateEditEntrance(); }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { showingAlert = false } } message: { Text(alertMessage) }
        .onChange(of: accountName) { _,_ in detectChanges() }.onChange(of: selectedInstitutionId) { _,_ in detectChanges() }.onChange(of: accountNumber) { _,_ in detectChanges() }
        .onChange(of: selectedAccountTypeId) { _,_ in detectChanges() } // MODIFIED
        .onChange(of: currencyCode) { _,_ in detectChanges() }
        .onChange(of: setOpeningDate) { _,_ in detectChanges() }.onChange(of: openingDateInput) { _,_ in detectChanges() }.onChange(of: setClosingDate) { _,_ in detectChanges() }.onChange(of: closingDateInput) { _,_ in detectChanges() }
        .onChange(of: includeInPortfolio) { _,_ in detectChanges() }.onChange(of: isActive) { _,_ in detectChanges() }.onChange(of: notes) { _,_ in detectChanges() }
    }

    private var editModernHeader: some View {
        HStack {
            Button { if hasChanges { showUnsavedChangesAlert() } else { animateEditExit() } } label: { Image(systemName: "xmark").modifier(ModernSubtleButton()) }; Spacer()
            HStack(spacing: 12) { Image(systemName: "pencil.line").font(.system(size: 24)).foregroundColor(.orange); Text("Edit Custody Account").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)) }; Spacer()
            Button { saveAccountChanges() } label: { HStack(spacing: 8) { if isLoading { ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8) } else { Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark").font(.system(size: 14, weight: .bold)) }; Text(isLoading ? "Saving..." : "Save Changes").font(.system(size: 14, weight: .semibold)) }.modifier(ModernPrimaryButton(color: .orange, isDisabled: isLoading || !isValid || !hasChanges)) }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    private var changeIndicator: some View {
        HStack { if hasChanges { HStack(spacing: 8) { Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(.orange); Text("Unsaved changes").font(.caption).foregroundColor(.orange) }.padding(.horizontal, 12).padding(.vertical, 4).background(Color.orange.opacity(0.1)).clipShape(Capsule()).overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1)).transition(.opacity.combined(with: .scale)) }; Spacer() }.padding(.horizontal, 24).animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }

    private func animateEditEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    private func animateEditExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50; }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }
    
    private func editModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(.gray)
                Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            TextField(placeholder, text: text)
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isRequired && !isValid && showingAlert {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }
    
    // MODIFIED: Replaced accountType TextField with a Picker
    private var accountTypePickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "briefcase.fill").foregroundColor(.gray)
                Text("Account Type*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
            }
            Picker("Account Type*", selection: $selectedAccountTypeId) {
                Text("Select Account Type...").tag(nil as Int?)
                ForEach(availableAccountTypes) { type in
                    Text(type.name).tag(type.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedAccountTypeId == nil && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if selectedAccountTypeId == nil && !isValid && showingAlert {
                Text("Account Type is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }

    // Picker for selecting the associated institution when editing an account
    private var institutionPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.2.fill").foregroundColor(.gray)
                Text("Institution*")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
            }
            Picker("Institution*", selection: $selectedInstitutionId) {
                Text("Select Institution...").tag(nil as Int?)
                ForEach(availableInstitutions) { inst in
                    Text(inst.name).tag(inst.id as Int?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedInstitutionId == nil && !isValid && showingAlert ?
                            Color.red.opacity(0.6) : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
            if selectedInstitutionId == nil && !isValid && showingAlert {
                Text("Institution is required.")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }

    private var editModernContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Account Details", icon: "pencil.and.scribble", color: .orange)
                    editModernTextField(title: "Account Name*", text: $accountName, placeholder: "e.g., Main Trading Account", icon: "tag.fill", isRequired: true)
                    institutionPickerField
                    editModernTextField(title: "Account Number*", text: $accountNumber, placeholder: "e.g., U1234567", icon: "number.square.fill", isRequired: true)
                    accountTypePickerField // MODIFIED: Using Picker
                }.modifier(ModernFormSection(color: .orange))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Financial & Dates", icon: "calendar.badge.clock", color: .green)
                    currencyPickerField
                    Toggle(isOn: $setOpeningDate.animation()) { Text("Set Opening Date") }.modifier(ModernToggleStyle(tint: .green))
                    if setOpeningDate {
                        DatePicker(selection: $openingDateInput, displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.plus").foregroundColor(.gray); Text("Opening Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                    }
                    Toggle(isOn: $setClosingDate.animation()) { Text("Set Closing Date") }.modifier(ModernToggleStyle(tint: .orange))
                    if setClosingDate {
                        DatePicker(selection: $closingDateInput, in: (setOpeningDate ? openingDateInput... : Date.distantPast...), displayedComponents: .date) { HStack { Image(systemName: "calendar.badge.minus").foregroundColor(.gray); Text("Closing Date") .font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) } }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity), removal: .opacity))
                        if setOpeningDate && closingDateInput < openingDateInput && setClosingDate { Text("Closing date must be on or after opening date.").font(.caption).foregroundColor(.red).padding(.leading, 16) }
                    }
                }.modifier(ModernFormSection(color: .green))
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(title: "Settings & Notes", icon: "gearshape.fill", color: .purple)
                    Toggle(isOn: $includeInPortfolio) { Text("Include in Portfolio Calculations") }.modifier(ModernToggleStyle(tint: .purple))
                    Toggle(isOn: $isActive) { Text("Account is Active") }.modifier(ModernToggleStyle(tint: .green))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "note.text").foregroundColor(.gray); Text("Notes").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
                        TextEditor(text: $notes).frame(minHeight: 80, maxHeight: 150).font(.system(size: 16)).padding(12)
                            .background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }.modifier(ModernFormSection(color: .purple))
            }.padding(.horizontal, 24).padding(.bottom, 100)
        }.offset(y: sectionsOffset)
    }
    private var currencyPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "dollarsign.circle.fill").foregroundColor(.gray); Text("Default Currency*").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)) }
            Picker("Default Currency*", selection: $currencyCode) { Text("Select Currency...").tag(""); ForEach(availableCurrencies, id: \.code) { curr in Text("\(curr.name) (\(curr.code))").tag(curr.code) } }
            .pickerStyle(MenuPickerStyle()).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(currencyCode.isEmpty && !isValid && showingAlert ? Color.red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1))
            if currencyCode.isEmpty && !isValid && showingAlert { Text("Currency is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }
    func loadAccountData() {
        availableCurrencies = dbManager.fetchActiveCurrencies()
        availableAccountTypes = dbManager.fetchAccountTypes(activeOnly: true)
        availableInstitutions = dbManager.fetchInstitutions(activeOnly: true)
        
        if let details = dbManager.fetchAccountDetails(id: accountId) {
            accountName = details.accountName
            selectedInstitutionId = details.institutionId
            accountNumber = details.accountNumber
            selectedAccountTypeId = details.accountTypeId; // Set selected ID for Picker
            currencyCode = details.currencyCode;
            if let oDate = details.openingDate { openingDateInput = oDate; setOpeningDate = true } else { setOpeningDate = false; openingDateInput = Date() }
            if let cDate = details.closingDate { closingDateInput = cDate; setClosingDate = true } else { setClosingDate = false; closingDateInput = Date() }
            includeInPortfolio = details.includeInPortfolio; isActive = details.isActive; notes = details.notes ?? "";
            originalData = details; originalSetOpeningDate = setOpeningDate; originalOpeningDateInput = openingDateInput; originalSetClosingDate = setClosingDate; originalClosingDateInput = closingDateInput;
            detectChanges() // Initial check after loading
        } else { alertMessage = "❌ Error: Could not load account details."; showingAlert = true }
    }
    private func showUnsavedChangesAlert() {
        let alert = NSAlert(); alert.messageText = "Unsaved Changes"; alert.informativeText = "You have unsaved changes. Are you sure you want to close?"; alert.addButton(withTitle: "Save & Close"); alert.addButton(withTitle: "Discard & Close"); alert.addButton(withTitle: "Cancel"); alert.alertStyle = .warning
        let response = alert.runModal(); if response == .alertFirstButtonReturn { saveAccountChanges() } else if response == .alertSecondButtonReturn { animateEditExit() }
    }
    func saveAccountChanges() {
        guard isValid, let typeId = selectedAccountTypeId, let _ = selectedInstitutionId else {
            var errorMsg = "Please fill all mandatory fields (*)."; if setClosingDate && setOpeningDate && closingDateInput < openingDateInput { errorMsg += "\nClosing date cannot be before opening date." }; if selectedAccountTypeId == nil {errorMsg += "\nAccount Type is required."}
            alertMessage = errorMsg; showingAlert = true; return
        }
        guard hasChanges else { animateEditExit(); return } // Only save if there are changes
        isLoading = true
        let finalOpeningDate: Date? = setOpeningDate ? openingDateInput : nil
        let finalClosingDate: Date? = setClosingDate ? closingDateInput : nil
        
        let success = dbManager.updateAccount(
            id: accountId,
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionId: selectedInstitutionId!,
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            accountTypeId: typeId, // Pass selected ID
            currencyCode: currencyCode,
            openingDate: finalOpeningDate,
            closingDate: finalClosingDate,
            includeInPortfolio: includeInPortfolio,
            isActive: isActive,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isLoading = false
        if success {
            // Reload originalData to correctly reflect the saved state for subsequent 'hasChanges' checks
            if let currentDetails = dbManager.fetchAccountDetails(id: accountId) {
                originalData = currentDetails
                selectedAccountTypeId = currentDetails.accountTypeId // ensure this is also updated for comparison
                if let oDate = currentDetails.openingDate { originalOpeningDateInput = oDate; originalSetOpeningDate = true } else { originalSetOpeningDate = false }
                if let cDate = currentDetails.closingDate { originalClosingDateInput = cDate; originalSetClosingDate = true } else { originalSetClosingDate = false }
            }
            detectChanges() // Re-evaluate hasChanges, should be false now
            NotificationCenter.default.post(name: NSNotification.Name("RefreshCustodyAccounts"), object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { animateEditExit() }
        } else { alertMessage = "❌ Failed to update account. Please try again."; if alertMessage.contains("UNIQUE constraint failed: Accounts.account_number") { alertMessage = "❌ Failed to update account: Account Number must be unique."}; showingAlert = true }
    }
}
