// DragonShield/Views/InstitutionsView.swift
// MARK: - Version 1.1
// MARK: - History
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
                    .contextMenu {
                        Button("Edit") { selectedInstitution = inst; showEditSheet = true }
                        Button("Delete", role: .destructive) { institutionToDelete = inst; showingDeleteAlert = true }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear { loadData() }
        .sheet(isPresented: $showAddSheet) { AddInstitutionView().environmentObject(dbManager) }
        .sheet(isPresented: $showEditSheet) {
            if let inst = selectedInstitution {
                EditInstitutionView(institutionId: inst.id).environmentObject(dbManager)
            }
        }
        .alert("Delete Institution", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let inst = institutionToDelete { _ = dbManager.deleteInstitution(id: inst.id); loadData() }
            }
        } message: {
            if let inst = institutionToDelete { Text("Delete \(inst.name)?") }
        }
    }

    private func loadData() { institutions = dbManager.fetchInstitutions(activeOnly: false) }
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
        alertMessage = success ? "✅ Added" : "❌ Failed"
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
        alertMessage = success ? "✅ Updated" : "❌ Failed"
        showingAlert = true
    }
}

