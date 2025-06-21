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

    var filteredInstitutions: [DatabaseManager.InstitutionData] {
        if searchText.isEmpty { return institutions }
        return institutions.filter { inst in
            inst.name.localizedCaseInsensitiveContains(searchText) ||
            (inst.bic?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search", text: $searchText).textFieldStyle(RoundedBorderTextFieldStyle()).padding()
                Spacer()
                Button("Add") { showAddSheet = true }
            }
            List(selection: $selectedInstitution) {
                ForEach(filteredInstitutions) { inst in
                    HStack {
                        Text(inst.name)
                        Spacer()
                        if let bic = inst.bic { Text(bic).foregroundColor(.secondary) }
                    }
                    .tag(inst as DatabaseManager.InstitutionData?)
                    .onTapGesture { selectedInstitution = inst }
                    .onTapGesture(count: 2) {
                        selectedInstitution = inst
                        showEditSheet = true
                    }
                    .contextMenu {
                        Button("Edit") { selectedInstitution = inst; showEditSheet = true }
                        Button("Delete", role: .destructive) { institutionToDelete = inst; showingDeleteAlert = true }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            HStack(spacing: 16) {
                Button(action: { showAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: { if let inst = selectedInstitution { selectedInstitution = inst; showEditSheet = true } }) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(selectedInstitution == nil)

                Button(action: {
                    if let inst = selectedInstitution {
                        institutionToDelete = inst
                        showingDeleteAlert = true
                    }
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(selectedInstitution == nil)

                Spacer()
                if let inst = selectedInstitution {
                    Text("Selected: \(inst.name)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .onAppear { loadData() }
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

    @State private var name = ""
    @State private var bic = ""
    @State private var type = ""
    @State private var website = ""
    @State private var isActive = true
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack {
            Text("Add Institution").font(.headline)
            Form {
                TextField("Name", text: $name)
                TextField("BIC", text: $bic)
                TextField("Type", text: $type)
                TextField("Website", text: $website)
                Toggle("Active", isOn: $isActive)
            }
            HStack {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .padding().frame(width: 400, height: 300)
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func save() {
        let success = dbManager.addInstitution(name: name.trimmingCharacters(in: .whitespacesAndNewlines), bic: bic.isEmpty ? nil : bic, type: type.isEmpty ? nil : type, website: website.isEmpty ? nil : website, isActive: isActive)
        if success {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
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
    @State private var isActive = true
    @State private var loaded = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack {
            Text("Edit Institution").font(.headline)
            Form {
                TextField("Name", text: $name)
                TextField("BIC", text: $bic)
                TextField("Type", text: $type)
                TextField("Website", text: $website)
                Toggle("Active", isOn: $isActive)
            }
            HStack {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                Spacer()
                Button("Save") { save() }.disabled(!isValid)
            }.padding()
        }
        .padding().frame(width: 400, height: 300)
        .onAppear { if !loaded { load() } }
        .alert("Result", isPresented: $showingAlert) { Button("OK") { if alertMessage.hasPrefix("✅") { presentationMode.wrappedValue.dismiss() } } } message: { Text(alertMessage) }
    }

    private func load() {
        if let inst = dbManager.fetchInstitutionDetails(id: institutionId) {
            name = inst.name; bic = inst.bic ?? ""; type = inst.type ?? ""; website = inst.website ?? ""; isActive = inst.isActive; loaded = true
        }
    }

    private func save() {
        let success = dbManager.updateInstitution(id: institutionId, name: name.trimmingCharacters(in: .whitespacesAndNewlines), bic: bic.isEmpty ? nil : bic, type: type.isEmpty ? nil : type, website: website.isEmpty ? nil : website, isActive: isActive)
        if success {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshInstitutions"), object: nil)
            alertMessage = "✅ Updated"
        } else {
            alertMessage = "❌ Failed"
        }
        showingAlert = true
    }
}

