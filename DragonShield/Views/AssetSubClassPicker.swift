import SwiftUI

enum AssetSubClassPickerModel {
    static func sort(_ groups: [(id: Int, name: String)]) -> [(id: Int, name: String)] {
        groups.sorted {
            $0.name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .localizedCompare(
                    $1.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                ) == .orderedAscending
        }
    }

    static func filter(_ groups: [(id: Int, name: String)], query: String) -> [(id: Int, name: String)] {
        let sortedGroups = sort(groups)
        guard !query.isEmpty else { return sortedGroups }
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return sortedGroups.filter {
            $0.name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(q)
        }
    }
}

struct AssetSubClassPickerView: View {
    let instrumentGroups: [(id: Int, name: String)]
    @Binding var selectedGroupId: Int
    var onSelect: (() -> Void)?

    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(DSColor.textSecondary)
                Text("Asset SubClass*")
                    .dsCaption()
                    .foregroundColor(DSColor.textPrimary)
                Spacer()
            }

            Button {
                isPresented = true
            } label: {
                HStack {
                    Text(instrumentGroups.first { $0.id == selectedGroupId }?.name ?? "Select Asset SubClass")
                        .foregroundColor(DSColor.textPrimary)
                        .dsBody()
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DSColor.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(DSColor.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(DSColor.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $isPresented) {
                AssetSubClassPickerSheet(
                    groups: instrumentGroups,
                    selectedId: $selectedGroupId,
                    onSelection: {
                        onSelect?()
                        isPresented = false
                    },
                    onCancel: { isPresented = false }
                )
            }
        }
    }
}

private struct AssetSubClassPickerSheet: View {
    let groups: [(id: Int, name: String)]
    @Binding var selectedId: Int
    var onSelection: () -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var debounceTask: DispatchWorkItem?
    @State private var filtered: [(id: Int, name: String)] = []
    @State private var highlighted: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search…", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { _, _ in
                        debounceTask?.cancel()
                        let task = DispatchWorkItem {
                            filtered = AssetSubClassPickerModel.filter(groups, query: searchText)
                            highlighted = filtered.first?.id
                        }
                        debounceTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: task)
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        filtered = AssetSubClassPickerModel.filter(groups, query: "")
                        highlighted = filtered.first?.id
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            Divider()
            ScrollViewReader { proxy in
                List(selection: $highlighted) {
                    ForEach(filtered, id: \.id) { group in
                        Text(group.name)
                            .tag(group.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedId = group.id
                                onSelection()
                                dismiss()
                            }
                            .help(group.name)
                    }
                    if filtered.isEmpty {
                        Text("No matches found. Clear the search to see all.")
                            .foregroundColor(.gray)
                            .tag(-1)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(minHeight: 400, maxHeight: 600)
                .onAppear {
                    filtered = AssetSubClassPickerModel.filter(groups, query: "")
                    highlighted = selectedId
                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
                .onChange(of: highlighted) { _, newValue in
                    if let id = newValue {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .onExitCommand {
            if searchText.isEmpty {
                onCancel()
                dismiss()
            } else {
                searchText = ""
                filtered = AssetSubClassPickerModel.filter(groups, query: "")
                highlighted = filtered.first?.id
            }
        }
        .onSubmit {
            if let id = highlighted, let match = filtered.first(where: { $0.id == id }) {
                selectedId = match.id
                onSelection()
                dismiss()
            } else if let first = filtered.first {
                selectedId = first.id
                onSelection()
                dismiss()
            }
        }
        .accessibilityLabel("\(filtered.count) results")
    }
}
