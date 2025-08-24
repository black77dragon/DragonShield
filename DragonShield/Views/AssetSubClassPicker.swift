import SwiftUI

struct AssetSubClassPicker: View {
    @Binding var selectedId: Int
    let groups: [(id: Int, name: String)]

    @StateObject private var viewModel: AssetSubClassPickerViewModel
    @State private var isPresented = false
    @State private var highlightedId: Int?
    @FocusState private var searchFocused: Bool

    init(selectedId: Binding<Int>, groups: [(id: Int, name: String)]) {
        self._selectedId = selectedId
        self.groups = groups
        _viewModel = StateObject(wrappedValue: AssetSubClassPickerViewModel(groups: groups))
    }

    var body: some View {
        Button(action: { isPresented = true }) {
            HStack {
                Text(viewModel.name(for: selectedId) ?? "Select Asset SubClass")
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
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search…", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($searchFocused)
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding()

                Divider()

                if viewModel.results.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        List(selection: $highlightedId) {
                            ForEach(viewModel.results, id: \.id) { group in
                                Text(group.name)
                                    .tag(group.id)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedId = group.id
                                        isPresented = false
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 360)
                        .onAppear {
                            highlightedId = selectedId
                            searchFocused = true
                            proxy.scrollTo(selectedId, anchor: .center)
                        }
                        .onChange(of: highlightedId) { newId in
                            if let newId = newId {
                                proxy.scrollTo(newId, anchor: .center)
                            }
                        }
                        .onChange(of: viewModel.results) { _ in
                            if !viewModel.results.contains(where: { $0.id == highlightedId }) {
                                highlightedId = viewModel.results.first?.id
                            }
                        }
                    }
                }
            }
            .onSubmit {
                if let id = highlightedId ?? viewModel.results.first?.id {
                    selectedId = id
                    isPresented = false
                }
            }
            .onExitCommand {
                if !viewModel.searchText.isEmpty {
                    viewModel.clearSearch()
                } else {
                    isPresented = false
                }
            }
        }
        .onChange(of: groups) { newGroups in
            viewModel.updateGroups(newGroups)
        }
    }
}
