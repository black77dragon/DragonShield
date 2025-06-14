// DragonShield/Views/CurrenciesView.swift
// MARK: - Version 1.4
// MARK: - History
// - 1.3 -> 1.4: Fixed EditCurrencyView to correctly use the environment's DatabaseManager instance.
// - 1.2 -> 1.3: Updated deprecated onChange modifiers to use new two-parameter syntax.
// - 1.1 -> 1.2: Applied dynamic row spacing and padding from DatabaseManager configuration.
// - 1.0 -> 1.1: Updated deprecated onChange modifiers to new syntax for macOS 14.0+.

import SwiftUI

struct CurrenciesView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var currencies: [(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)] = []
    @State private var showAddCurrencySheet = false
    @State private var showEditCurrencySheet = false
    @State private var selectedCurrency: (code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)? = nil
    @State private var showingDeleteAlert = false
    @State private var currencyToDelete: (code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)? = nil
    @State private var searchText = ""
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    var filteredCurrencies: [(code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)] {
        if searchText.isEmpty {
            return currencies.sorted { $0.code < $1.code }
        } else {
            return currencies.filter { currency in
                currency.code.localizedCaseInsensitiveContains(searchText) ||
                currency.name.localizedCaseInsensitiveContains(searchText) ||
                currency.symbol.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.code < $1.code }
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99), Color(red: 0.93, green: 0.95, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            CurrencyParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                currenciesContent
                modernActionBar
            }
        }
        .onAppear {
            loadCurrencies()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCurrencies"))) { _ in
            loadCurrencies()
        }
        .onChange(of: dbManager.tableRowSpacing) { _, _ in }
        .onChange(of: dbManager.tableRowPadding) { _, _ in }
        .sheet(isPresented: $showAddCurrencySheet) {
            AddCurrencyView().environmentObject(dbManager)
        }
        .sheet(isPresented: $showEditCurrencySheet) {
            if let currency = selectedCurrency {
                EditCurrencyView(currencyCode: currency.code).environmentObject(dbManager)
            }
        }
        .alert("Delete Currency", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let currency = currencyToDelete {
                    confirmDelete(currency)
                }
            }
        } message: {
            if let currency = currencyToDelete {
                Text("Are you sure you want to delete '\(currency.name) (\(currency.code))'?")
            }
        }
    }
    
    // MARK: - Subviews (Header, Search, etc. - Unchanged)
    
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill").font(.system(size: 32)).foregroundColor(.green)
                    Text("Currencies").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
                }
                Text("Manage your supported currencies and exchange rates").font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(currencies.count)", icon: "number.circle.fill", color: .green)
                modernStatCard(title: "Active", value: "\(currencies.filter { $0.isActive }.count)", icon: "checkmark.circle.fill", color: .blue)
                modernStatCard(title: "API Supported", value: "\(currencies.filter { $0.apiSupported }.count)", icon: "wifi.circle.fill", color: .purple)
            }
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search currencies...", text: $searchText).textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty { Button {searchText = ""} label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }.buttonStyle(PlainButtonStyle()) }
            }.padding(.horizontal, 16).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1)))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            if !searchText.isEmpty { HStack { Text("Found \(filteredCurrencies.count) of \(currencies.count) currencies").font(.caption).foregroundColor(.gray); Spacer() } }
        }.padding(.horizontal, 24).offset(y: contentOffset)
    }
    
    private var currenciesContent: some View {
        VStack(spacing: 16) {
            if filteredCurrencies.isEmpty {
                emptyStateView
            } else {
                currenciesTable
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
                Image(systemName: searchText.isEmpty ? "dollarsign.circle" : "magnifyingglass").font(.system(size: 64)).foregroundStyle(LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No currencies yet" : "No matching currencies").font(.title2).fontWeight(.semibold).foregroundColor(.gray)
                    Text(searchText.isEmpty ? "Add your first currency to start managing exchange rates" : "Try adjusting your search terms").font(.body).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                if searchText.isEmpty { Button { showAddCurrencySheet = true } label: { HStack(spacing: 8) { Image(systemName: "plus"); Text("Add Your First Currency") }.font(.headline).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 12).background(Color.green).clipShape(Capsule()).shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4) }.buttonStyle(ScaleButtonStyle()).padding(.top, 8) }
            }
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var currenciesTable: some View {
        VStack(spacing: 0) {
            modernTableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(filteredCurrencies, id: \.code) { currency in
                        ModernCurrencyRowView(
                            currency: currency,
                            isSelected: selectedCurrency?.code == currency.code,
                            rowPadding: CGFloat(dbManager.tableRowPadding),
                            onTap: { selectedCurrency = currency },
                            onEdit: {
                                selectedCurrency = currency
                                showEditCurrencySheet = true
                            }
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
            Text("Code").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .leading)
            Text("Name").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text("Symbol").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .center)
            Text("API").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 60, alignment: .center)
            Text("Status").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 80, alignment: .center)
        }.padding(.horizontal, 16).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))).padding(.bottom, 1)
    }
    
    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
            HStack(spacing: 16) {
                Button { showAddCurrencySheet = true } label: { HStack(spacing: 8) { Image(systemName: "plus"); Text("Add New Currency") }.font(.system(size: 16, weight: .semibold)).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 12).background(Color.green).clipShape(Capsule()).shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 3) }.buttonStyle(ScaleButtonStyle())
                if selectedCurrency != nil {
                    Button { showEditCurrencySheet = true } label: { HStack(spacing: 6) { Image(systemName: "pencil"); Text("Edit") }.font(.system(size: 14, weight: .medium)).foregroundColor(.blue).padding(.horizontal, 16).padding(.vertical, 10).background(Color.blue.opacity(0.1)).clipShape(Capsule()).overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)) }.buttonStyle(ScaleButtonStyle())
                    Button { if let currency = selectedCurrency { currencyToDelete = currency; showingDeleteAlert = true } } label: { HStack(spacing: 6) { Image(systemName: "trash"); Text("Delete") }.font(.system(size: 14, weight: .medium)).foregroundColor(.red).padding(.horizontal, 16).padding(.vertical, 10).background(Color.red.opacity(0.1)).clipShape(Capsule()).overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1)) }.buttonStyle(ScaleButtonStyle())
                }
                Spacer()
                if let currency = selectedCurrency { HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Selected: \(currency.code)").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary) }.padding(.horizontal, 12).padding(.vertical, 6).background(Color.green.opacity(0.05)).clipShape(Capsule()) }
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
    
    // MARK: - Functions
    func loadCurrencies() {
        currencies = self.dbManager.fetchCurrencies()
    }
    
    func confirmDelete(_ currency: (code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)) {
        let success = self.dbManager.deleteCurrency(code: currency.code)
        if success {
            loadCurrencies()
            selectedCurrency = nil
            currencyToDelete = nil
        }
    }
}

// MARK: - Modern Currency Row (Unchanged)
struct ModernCurrencyRowView: View {
    let currency: (code: String, name: String, symbol: String, isActive: Bool, apiSupported: Bool)
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Text(currency.code)
                .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(.primary)
                .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 80, alignment: .leading)
            Text(currency.name)
                .font(.system(size: 15, weight: .medium)).foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(currency.symbol)
                .font(.system(size: 16, weight: .bold)).foregroundColor(.secondary)
                .frame(width: 80, alignment: .center)
            HStack(spacing: 4) {
                Circle().fill(currency.apiSupported ? Color.purple : Color.gray).frame(width: 8, height: 8)
                Text(currency.apiSupported ? "Yes" : "No").font(.system(size: 12, weight: .medium)).foregroundColor(currency.apiSupported ? .purple : .gray)
            }.frame(width: 60, alignment: .center)
            HStack(spacing: 4) {
                Circle().fill(currency.isActive ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(currency.isActive ? "Active" : "Inactive").font(.system(size: 12, weight: .medium)).foregroundColor(currency.isActive ? .green : .orange)
            }.frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowPadding)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.green.opacity(0.1) : Color.clear).overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit Currency") { onEdit() }
            Button("Select Currency") { onTap() }
            Divider()
            Button("Copy Code") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(currency.code, forType: .string) }
            Button("Copy Name") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(currency.name, forType: .string) }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Add Currency View (Unchanged)
struct AddCurrencyView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var currencyCode = ""
    @State private var currencyName = ""
    @State private var currencySymbol = ""
    @State private var isActive = true
    @State private var apiSupported = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    
    var isValid: Bool {
        !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidCurrencyCode
    }
    private var isValidCurrencyCode: Bool {
        let trimmed = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 3 && trimmed.allSatisfy { $0.isLetter }
    }
    private var completionPercentage: Double {
        var completed = 0.0; let total = 4.0
        if !currencyCode.isEmpty { completed += 1 }; if !currencyName.isEmpty { completed += 1 }; if !currencySymbol.isEmpty { completed += 1 }; completed += 1
        return completed / total
    }
    var body: some View {
        ZStack {
            LinearGradient( colors: [Color(red: 0.98, green: 0.99, blue: 1.0),Color(red: 0.95, green: 0.97, blue: 0.99),Color(red: 0.93, green: 0.95, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            AddCurrencyParticleBackground()
            VStack(spacing: 0) { addModernHeader; addProgressBar; addModernContent; }
        }.frame(width: 600, height: 550).clipShape(RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale).onAppear { animateAddEntrance() }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.contains("✅") { animateAddExit() } } } message: { Text(alertMessage) }
    }
    private var addModernHeader: some View {
        HStack {
            Button { animateAddExit() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(.gray).frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)) }.buttonStyle(ScaleButtonStyle())
            Spacer()
            HStack(spacing: 12) { Image(systemName: "dollarsign.circle.badge.plus").font(.system(size: 24)).foregroundColor(.green); Text("Add Currency").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)) }
            Spacer()
            Button { saveCurrency() } label: { HStack(spacing: 8) { if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) } else { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }; Text(isLoading ? "Saving..." : "Save").font(.system(size: 14, weight: .semibold)) }.foregroundColor(.white).frame(height: 32).padding(.horizontal, 16).background(Group { if isValid && !isLoading { Color.green } else { Color.gray.opacity(0.4) } }).clipShape(Capsule()).overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1)).shadow(color: isValid ? .green.opacity(0.3) : .clear, radius: 8, x: 0, y: 2) }.disabled(isLoading || !isValid).buttonStyle(ScaleButtonStyle())
        }.padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }
    private var addProgressBar: some View {
        VStack(spacing: 8) {
            HStack { Text("Completion").font(.caption).foregroundColor(.gray); Spacer(); Text("\(Int(completionPercentage * 100))%").font(.caption.weight(.semibold)).foregroundColor(.green) }
            GeometryReader { geometry in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 6); RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)).frame(width: geometry.size.width * completionPercentage, height: 6).animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage).shadow(color: .green.opacity(0.3), radius: 3, x: 0, y: 1) } }.frame(height: 6)
        }.padding(.horizontal, 24).padding(.bottom, 20)
    }
    private var addModernContent: some View {
        ScrollView { VStack(spacing: 24) { addCurrencyInfoSection; addStatusSection; }.padding(.horizontal, 24).padding(.bottom, 100) }.offset(y: sectionsOffset)
    }
    private var addCurrencyInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Currency Information", icon: "dollarsign.circle.fill", color: .green)
            VStack(spacing: 16) { addModernTextField(title: "Currency Code",text: $currencyCode,placeholder: "e.g., JPY",icon: "number.circle.fill",isRequired: true,autoUppercase: true,validation: isValidCurrencyCode,errorMessage: "Currency code must be 3 letters (e.g., USD, EUR)"); addModernTextField(title: "Currency Name",text: $currencyName,placeholder: "e.g., Japanese Yen",icon: "textformat",isRequired: true); addModernTextField(title: "Currency Symbol",text: $currencySymbol,placeholder: "e.g., ¥",icon: "dollarsign",isRequired: true) }
        }.padding(24).background(addCurrencyGlassMorphismBackground).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.2), lineWidth: 1)).shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    private var addStatusSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            addSectionHeader(title: "Settings", icon: "gearshape.circle.fill", color: .blue)
            VStack(spacing: 16) { HStack(spacing: 16) { VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundColor(.gray); Text("Active Status").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }; Toggle("Active", isOn: $isActive).toggleStyle(SwitchToggleStyle(tint: .green)).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) }.frame(maxWidth: .infinity); VStack(alignment: .leading, spacing: 8) { HStack { Image(systemName: "wifi.circle").font(.system(size: 14)).foregroundColor(.gray); Text("API Support").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }; Toggle("API Supported", isOn: $apiSupported).toggleStyle(SwitchToggleStyle(tint: .purple)).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) }.frame(maxWidth: .infinity) } }
        }.padding(24).background(addCurrencyGlassMorphismBackground).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.blue.opacity(0.2), lineWidth: 1)).shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    private var addCurrencyGlassMorphismBackground: some View {
        ZStack { RoundedRectangle(cornerRadius: 16).fill(.regularMaterial).background(LinearGradient(colors: [.white.opacity(0.8),.white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)); RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [.green.opacity(0.05),.blue.opacity(0.03),.clear], startPoint: .topLeading, endPoint: .bottomTrailing)) }
    }
    private func addSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)); Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8)); Spacer() }
    }
    private func addModernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool, autoUppercase: Bool = false, validation: Bool = true, errorMessage: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray); Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer(); if !text.wrappedValue.isEmpty && !validation { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red) } }
            TextField(placeholder, text: text).font(.system(size: 16)).foregroundColor(.black).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(!text.wrappedValue.isEmpty && !validation ? .red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .onChange(of: text.wrappedValue) { _, newValue in if autoUppercase { let uppercased = newValue.uppercased(); if text.wrappedValue != uppercased { text.wrappedValue = uppercased } } }
            if !text.wrappedValue.isEmpty && !validation && !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }
    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }; withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }; withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50 }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }
    func saveCurrency() {
        guard isValid else { alertMessage = "Please fill in all required fields correctly"; showingAlert = true; return }; isLoading = true
        let success = dbManager.addCurrency(code: currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), name: currencyName.trimmingCharacters(in: .whitespacesAndNewlines), symbol: currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines), isActive: isActive, apiSupported: apiSupported)
        DispatchQueue.main.async { self.isLoading = false; if success { NotificationCenter.default.post(name: NSNotification.Name("RefreshCurrencies"), object: nil); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.animateAddExit() } } else { self.alertMessage = "❌ Failed to add currency. Please try again."; self.showingAlert = true } }
    }
}

// MARK: - Edit Currency View (FIXED)
struct EditCurrencyView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager // Use the environment object
    
    let currencyCode: String
    
    @State private var currencyName = ""
    @State private var currencySymbol = ""
    @State private var isActive = true
    @State private var apiSupported = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false
    
    @State private var originalName = ""
    @State private var originalSymbol = ""
    @State private var originalIsActive = true
    @State private var originalApiSupported = true

    init(currencyCode: String) {
        self.currencyCode = currencyCode
    }
    
    var isValid: Bool {
        !currencyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func detectChanges() {
        hasChanges = currencyName != originalName ||
                     currencySymbol != originalSymbol ||
                     isActive != originalIsActive ||
                     apiSupported != originalApiSupported
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 0.99), Color(red: 0.91, green: 0.94, blue: 0.98)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            EditCurrencyParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                changeIndicator
                progressBar
                modernContent
                modernFooter
            }
        }
        .frame(width: 700, height: 750)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadCurrencyData()
            animateEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") { showingAlert = false }
        } message: { Text(alertMessage) }
        .onChange(of: currencyName) { _, _ in detectChanges() }
        .onChange(of: currencySymbol) { _, _ in detectChanges() }
        .onChange(of: isActive) { _, _ in detectChanges() }
        .onChange(of: apiSupported) { _, _ in detectChanges() }
    }
    
    private var modernHeader: some View {
        HStack {
            Button {
                if hasChanges { showUnsavedChangesAlert() } else { animateExit() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.gray)
                    .frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }.buttonStyle(ScaleButtonStyle())
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill").font(.system(size: 24))
                    .foregroundStyle(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Edit Currency").font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
            }
            Spacer()
            Button { saveCurrency() } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8) }
                    else { Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark").font(.system(size: 14, weight: .bold)) }
                    Text(isLoading ? "Saving..." : "Save Changes").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white).frame(height: 32).padding(.horizontal, 16)
                .background(Group { if isValid && hasChanges && !isLoading { Color.orange } else { Color.gray.opacity(0.4) } })
                .clipShape(Capsule()).overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: isValid && hasChanges && !isLoading ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid || !hasChanges)
            .buttonStyle(ScaleButtonStyle())
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
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion").font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(Int(completionPercentage * 100))%").font(.caption.weight(.semibold)).foregroundColor(.orange)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.orange, .green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }.frame(height: 6)
        }.padding(.horizontal, 24).padding(.bottom, 20)
    }
    
    private var modernContent: some View {
        ScrollView { VStack(spacing: 24) { requiredSection; optionalSection; }.padding(.horizontal, 24).padding(.bottom, 100) }.offset(y: sectionsOffset)
    }
    
    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Currency Information", icon: "checkmark.shield.fill", color: .orange)
            VStack(spacing: 16) {
                modernTextField(title: "Currency Code",text: .constant(currencyCode),placeholder: currencyCode,icon: "number.circle.fill",isRequired: true,isReadOnly: true)
                modernTextField(title: "Currency Name",text: $currencyName,placeholder: "e.g., Danish Krone",icon: "textformat",isRequired: true)
                modernTextField(title: "Currency Symbol",text: $currencySymbol,placeholder: "e.g., DKK",icon: "dollarsign",isRequired: true)
            }
        }.modifier(ModernFormSection(color: .orange))
    }
    
    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Settings", icon: "gearshape.circle.fill", color: .red)
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundColor(.gray); Text("Active Status").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }
                        Toggle("Active", isOn: $isActive).modifier(ModernToggleStyle(tint: .green))
                    }.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "wifi.circle").font(.system(size: 14)).foregroundColor(.gray); Text("API Support").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer() }
                        Toggle("API Supported", isOn: $apiSupported).modifier(ModernToggleStyle(tint: .purple))
                    }.frame(maxWidth: .infinity)
                }
            }
        }.modifier(ModernFormSection(color: .red))
    }
    
    private var modernFooter: some View { Spacer() }
    
    private var completionPercentage: Double {
        var completed = 0.0; let total = 4.0
        completed += 1; if !currencyName.isEmpty { completed += 1 }; if !currencySymbol.isEmpty { completed += 1 }; completed += 1
        return completed / total
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)); Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8)); Spacer() }
    }
    
    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool, autoUppercase: Bool = false, validation: Bool = true, errorMessage: String = "", isReadOnly: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray); Text(title + (isRequired ? "*" : "")).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7)); Spacer(); if isReadOnly { Text("(Read-only)").font(.caption).foregroundColor(.gray).italic() }; if !text.wrappedValue.isEmpty && !validation { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red) } }
            if isReadOnly { Text(text.wrappedValue).font(.system(size: 16, weight: .medium)).foregroundColor(.primary).padding(.horizontal, 16).padding(.vertical, 12).background(Color.gray.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1)) }
            else { TextField(placeholder, text: text).font(.system(size: 16)).foregroundColor(.black).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(!text.wrappedValue.isEmpty && !validation ? .red.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)).shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase { let uppercased = newValue.uppercased(); if text.wrappedValue != uppercased { text.wrappedValue = uppercased } }
                }
            }
            if !text.wrappedValue.isEmpty && !validation && !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4) }
        }
    }
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }; withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }; withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }
    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50 }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }
    
    func loadCurrencyData() {
        if let details = dbManager.fetchCurrencyDetails(code: currencyCode) {
            currencyName = details.name
            currencySymbol = details.symbol
            isActive = details.isActive
            apiSupported = details.apiSupported
            
            originalName = details.name
            originalSymbol = details.symbol
            originalIsActive = details.isActive
            originalApiSupported = details.apiSupported
        } else {
             alertMessage = "❌ Error: Could not load details for \(currencyCode)."
             showingAlert = true
        }
    }
    
    private func showUnsavedChangesAlert() {
        let alert = NSAlert();alert.messageText = "Unsaved Changes";alert.informativeText = "You have unsaved changes. Are you sure you want to close without saving?";alert.alertStyle = .warning;alert.addButton(withTitle: "Save & Close");alert.addButton(withTitle: "Discard Changes");alert.addButton(withTitle: "Cancel");
        let response = alert.runModal();
        switch response { case .alertFirstButtonReturn: saveCurrency(); case .alertSecondButtonReturn: animateExit(); default: break }
    }
    func saveCurrency() {
        guard isValid else { alertMessage = "Please fill in all required fields correctly"; showingAlert = true; return }; isLoading = true
        let success = dbManager.updateCurrency(code: currencyCode, name: currencyName.trimmingCharacters(in: .whitespacesAndNewlines), symbol: currencySymbol.trimmingCharacters(in: .whitespacesAndNewlines), isActive: isActive, apiSupported: apiSupported)
        DispatchQueue.main.async { self.isLoading = false; if success { self.originalName = self.currencyName; self.originalSymbol = self.currencySymbol; self.originalIsActive = self.isActive; self.originalApiSupported = self.apiSupported; self.detectChanges(); NotificationCenter.default.post(name: NSNotification.Name("RefreshCurrencies"), object: nil); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.animateExit() } } else { self.alertMessage = "❌ Failed to update currency. Please try again."; self.showingAlert = true } }
    }
}

// MARK: - Particle Backgrounds (Unchanged)
struct AddCurrencyParticleBackground: View {
    @State private var particles: [AddCurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.green.opacity(0.04)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0..<12).map { _ in AddCurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0...600), y: CGFloat.random(in: 0...550)), size: CGFloat.random(in: 3...9), opacity: Double.random(in: 0.1...0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { for index in particles.indices { particles[index].position.y -= 700; particles[index].opacity = Double.random(in: 0.05...0.15) } } }
}
struct EditCurrencyParticleBackground: View {
    @State private var particles: [EditCurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.orange.opacity(0.04)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0..<12).map { _ in EditCurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0...600), y: CGFloat.random(in: 0...600)), size: CGFloat.random(in: 3...9), opacity: Double.random(in: 0.1...0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) { for index in particles.indices { particles[index].position.y -= 800; particles[index].opacity = Double.random(in: 0.05...0.15) } } }
}
struct AddCurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }
struct EditCurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }

struct CurrencyParticleBackground: View {
    @State private var particles: [CurrencyParticle] = []; var body: some View { ZStack { ForEach(particles.indices, id: \.self) { index in Circle().fill(Color.green.opacity(0.03)).frame(width: particles[index].size, height: particles[index].size).position(particles[index].position).opacity(particles[index].opacity) } }.onAppear { createParticles(); animateParticles() } }
    private func createParticles() { particles = (0..<15).map { _ in CurrencyParticle(position: CGPoint(x: CGFloat.random(in: 0...1200), y: CGFloat.random(in: 0...800)), size: CGFloat.random(in: 2...8), opacity: Double.random(in: 0.1...0.2)) } }
    private func animateParticles() { withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) { for index in particles.indices { particles[index].position.y -= 1000; particles[index].opacity = Double.random(in: 0.05...0.15) } } }
}
struct CurrencyParticle { var position: CGPoint; var size: CGFloat; var opacity: Double }
