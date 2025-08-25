// DragonShield/Views/InstitutionsView.swift
// MARK: - Version 1.4
// MARK: - History
// - 1.1 -> 1.2: Added add/edit/delete notifications and dependency check
//                on delete. List now refreshes automatically.
// - 1.2 -> 1.3: Added action bar with Edit/Delete buttons and double-click to
//                edit, matching the AccountTypes maintenance UX.
// - 1.3 -> 1.4: Delete action now removes the institution from the database
//                permanently and clears the current selection.
// - 1.0 -> 1.1: Fixed List selection error by requiring InstitutionData
//                to conform to Hashable.
// - Initial creation: Manage Institutions table using same design as other maintenance views.

import SwiftUI

struct InstitutionsView: View {
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var institutions: [DatabaseManager.InstitutionData] = []
    @State private var selectedInstitution: DatabaseManager.InstitutionData? = nil
    @State private var searchText = ""

    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var institutionToDelete: DatabaseManager.InstitutionData? = nil

    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    var filteredInstitutions: [DatabaseManager.InstitutionData] {
        if searchText.isEmpty { return institutions }
        return institutions.filter { inst in
            inst.name.localizedCaseInsensitiveContains(searchText) ||
            (inst.bic?.localizedCaseInsensitiveContains(searchText) ?? false)
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

            InstitutionsParticleBackground()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                institutionsContent
                modernActionBar
            }
        }
        .onAppear {
            loadData()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshInstitutions"))) { _ in
            loadData()
        }
        .sheet(isPresented: $showAddSheet) { AddInstitutionView().environmentObject(dbManager) }
        .sheet(isPresented: $showEditSheet) {
            if let inst = selectedInstitution {
                EditInstitutionView(institutionId: inst.id).environmentObject(dbManager)
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            guard let inst = institutionToDelete else {
                return Alert(title: Text("Error"), message: Text("No institution selected."), dismissButton: .default(Text("OK")))
            }

            let deleteInfo = dbManager.canDeleteInstitution(id: inst.id)

            if deleteInfo.0 {
                return Alert(
                    title: Text("Delete Institution"),
                    message: Text("Are you sure you want to delete '\(inst.name)'?"),
                    primaryButton: .destructive(Text("Delete")) {
                        performDelete(inst)
                    },
                    secondaryButton: .cancel { institutionToDelete = nil }
                )
            } else {
                return Alert(
                    title: Text("Cannot Delete Institution"),
                    message: Text(deleteInfo.2),
                    dismissButton: .default(Text("OK")) { institutionToDelete = nil }
                )
            }
        }
    }

    private func loadData() { institutions = dbManager.fetchInstitutions(activeOnly: false) }

    private func performDelete(_ inst: DatabaseManager.InstitutionData) {
        let success = dbManager.deleteInstitution(id: inst.id)
        if success {
            loadData()
            selectedInstitution = nil
            institutionToDelete = nil
        }
    }
}

struct AddInstitutionView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    var onAdd: ((Int) -> Void)? = nil

    @State private var name = ""
    @State private var bic = ""
    @State private var type = ""
    @State private var website = ""
    @State private var contactInfo = ""
    @State private var defaultCurrency = ""
    @State private var countryCode = ""
    @State private var notes = ""
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var availableCountries: [String] = []
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currValid = defaultCurrency.isEmpty || defaultCurrency.count == 3
        let countryValid = countryCode.isEmpty || countryCode.count == 2
        return !trimmedName.isEmpty && currValid && countryValid
    }

    var body: some View {
        VStack {
            Text("Add Institution").font(.headline)
            Form {
                TextField("Name", text: $name)
                TextField("BIC", text: $bic)
                TextField("Type", text: $type)
                TextField("Website", text: $website)
                TextField("Contact Info", text: $contactInfo)
                Picker("Default Currency", selection: $defaultCurrency) {
                    Text("None").tag("")
                    ForEach(availableCurrencies, id: \.code) { curr in
                        Text("\(curr.code)").tag(curr.code)
                    }
                }
                Picker("Country", selection: $countryCode) {
                    Text("None").tag("")
                    ForEach(availableCountries, id: \.self) { code in
                        Text("\(flagEmoji(code)) \(code)").tag(code)
                    }
                }
                Text("Notes")
                TextEditor(text: $notes)
                    .frame(height: 60)
                Toggle("Active", isOn: $isActive)
            }
            HStack {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .padding().frame(width: 400, height: 500)
        .onAppear {
            availableCurrencies = dbManager.fetchActiveCurrencies()
            availableCountries = Locale.Region.isoRegions.map(\.identifier).sorted()
        }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func save() {
        let newId = dbManager.addInstitution(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bic: bic.isEmpty ? nil : bic,
            type: type.isEmpty ? nil : type,
            website: website.isEmpty ? nil : website,
            contactInfo: contactInfo.isEmpty ? nil : contactInfo,
            defaultCurrency: defaultCurrency.isEmpty ? nil : defaultCurrency,
            countryCode: countryCode.isEmpty ? nil : countryCode,
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive)
        if let id = newId {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            onAdd?(id)
            alertMessage = "✅ Added"
        } else {
            alertMessage = "❌ Failed"
        }
        showingAlert = true
    }
}

struct EditInstitutionView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager
    let institutionId: Int

    @State private var name = ""
    @State private var bic = ""
    @State private var type = ""
    @State private var website = ""
    @State private var contactInfo = ""
    @State private var defaultCurrency = ""
    @State private var countryCode = ""
    @State private var notes = ""
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var availableCountries: [String] = []
    @State private var isActive = true
    @State private var loaded = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currValid = defaultCurrency.isEmpty || defaultCurrency.count == 3
        let countryValid = countryCode.isEmpty || countryCode.count == 2
        return !trimmedName.isEmpty && currValid && countryValid
    }

    var body: some View {
        VStack {
            Text("Edit Institution").font(.headline)
            Form {
                TextField("Name", text: $name)
                TextField("BIC", text: $bic)
                TextField("Type", text: $type)
                TextField("Website", text: $website)
                TextField("Contact Info", text: $contactInfo)
                Picker("Default Currency", selection: $defaultCurrency) {
                    Text("None").tag("")
                    ForEach(availableCurrencies, id: \.code) { curr in
                        Text("\(curr.code)").tag(curr.code)
                    }
                }
                Picker("Country", selection: $countryCode) {
                    Text("None").tag("")
                    ForEach(availableCountries, id: \.self) { code in
                        Text("\(flagEmoji(code)) \(code)").tag(code)
                    }
                }
                Text("Notes")
                TextEditor(text: $notes)
                    .frame(height: 60)
                Toggle("Active", isOn: $isActive)
            }
            HStack {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .padding().frame(width: 400, height: 500)
        .onAppear {
            if !loaded { load() }
            availableCurrencies = dbManager.fetchActiveCurrencies()
            availableCountries = Locale.Region.isoRegions.map(\.identifier).sorted()
        }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func load() {
        if let inst = dbManager.fetchInstitutionDetails(id: institutionId) {
            name = inst.name
            bic = inst.bic ?? ""
            type = inst.type ?? ""
            website = inst.website ?? ""
            contactInfo = inst.contactInfo ?? ""
            defaultCurrency = inst.defaultCurrency ?? ""
            countryCode = inst.countryCode ?? ""
            notes = inst.notes ?? ""
            isActive = inst.isActive
            loaded = true
        }
    }

    private func save() {
        let success = dbManager.updateInstitution(
            id: institutionId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bic: bic.isEmpty ? nil : bic,
            type: type.isEmpty ? nil : type,
            website: website.isEmpty ? nil : website,
            contactInfo: contactInfo.isEmpty ? nil : contactInfo,
            defaultCurrency: defaultCurrency.isEmpty ? nil : defaultCurrency,
            countryCode: countryCode.isEmpty ? nil : countryCode,
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive)
        if success {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            alertMessage = "✅ Updated"
        } else {
            alertMessage = "❌ Failed"
        }
        showingAlert = true
    }
}

// MARK: - Modern Institutions Components

private extension InstitutionsView {
    var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Institutions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
                }
                Text("Manage financial institutions")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            HStack(spacing: 16) {
                modernStatCard(title: "Total", value: "\(institutions.count)", icon: "number.circle.fill", color: .blue)
                modernStatCard(title: "Active", value: "\(institutions.filter { $0.isActive }.count)", icon: "checkmark.circle.fill", color: .green)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search institutions...", text: $searchText).textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
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

            if !searchText.isEmpty && !filteredInstitutions.isEmpty {
                HStack {
                    Text("Found \(filteredInstitutions.count) of \(institutions.count) institutions")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }

    var institutionsContent: some View {
        VStack(spacing: 16) {
            if institutions.isEmpty && searchText.isEmpty {
                emptyStateView
            } else if filteredInstitutions.isEmpty && !searchText.isEmpty {
                emptyStateView
            } else {
                institutionsTable
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
                Image(systemName: searchText.isEmpty && institutions.isEmpty ? "building.2" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 8) {
                    Text(searchText.isEmpty && institutions.isEmpty ? "No institutions yet" : "No matching institutions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    Text(searchText.isEmpty && institutions.isEmpty ? "Add your first institution to get started." : "Try adjusting your search terms.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if searchText.isEmpty && institutions.isEmpty {
                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add First Institution")
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

    var institutionsTable: some View {
        VStack(spacing: 0) {
            modernTableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(filteredInstitutions) { inst in
                        ModernInstitutionRowView(
                            institution: inst,
                            isSelected: selectedInstitution?.id == inst.id,
                            rowPadding: CGFloat(dbManager.tableRowPadding),
                            onTap: { selectedInstitution = inst },
                            onEdit: { selectedInstitution = inst; showEditSheet = true }
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

    var modernTableHeader: some View {
        HStack {
            Text("Name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("BIC")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            Text("Type")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            Text("Cur")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .leading)
            Text("Country")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 70, alignment: .leading)
            Text("Note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .center)
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

    var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 16) {
                Button { showAddSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add New Institution")
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

                if selectedInstitution != nil {
                    Button { showEditSheet = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        if let inst = selectedInstitution {
                            institutionToDelete = inst
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

                if let inst = selectedInstitution {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(inst.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
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

    func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
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

    func animateEntrance() {
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
}

struct ModernInstitutionRowView: View {
    let institution: DatabaseManager.InstitutionData
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void

    @State private var showNote = false

    var body: some View {
        HStack {
            Text(institution.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(institution.bic ?? "")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 100, alignment: .leading)

            Text(institution.type ?? "")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(institution.defaultCurrency ?? "")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(institution.countryCode.map { "\(flagEmoji($0)) \($0)" } ?? "")
                .font(.system(size: 13))
                .frame(width: 70, alignment: .leading)
            if let note = institution.notes, !note.isEmpty {
                Button(action: { showNote = true }) {
                    Image(systemName: "note.text")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 40, alignment: .center)
                .alert("Note", isPresented: $showNote) {
                    Button("Close", role: .cancel) { }
                } message: {
                    Text(note)
                }
            } else {
                Spacer().frame(width: 40)
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(institution.isActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(institution.isActive ? "Active" : "Inactive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(institution.isActive ? .green : .orange)
            }
            .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowPadding)
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
            Button("Edit Institution") { onEdit() }
            Button("Select Institution") { onTap() }
            Divider()
            Button("Copy Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(institution.name, forType: .string)
            }
            if let bic = institution.bic {
                Button("Copy BIC") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bic, forType: .string)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private func flagEmoji(_ code: String) -> String {
    code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }.map { String($0) }.joined()
}

struct InstitutionParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct InstitutionsParticleBackground: View {
    @State private var particles: [InstitutionParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.blue.opacity(0.03))
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
            InstitutionParticle(
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

