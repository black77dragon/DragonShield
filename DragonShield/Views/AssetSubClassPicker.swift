import SwiftUI

struct AssetSubClassPicker: View {
    @Binding var selection: Int
    let items: [AssetSubClassItem]

    @State private var isPresented = false
    @StateObject private var viewModel: AssetSubClassPickerViewModel

    init(selection: Binding<Int>, items: [AssetSubClassItem]) {
        self._selection = selection
        self._viewModel = StateObject(wrappedValue: AssetSubClassPickerViewModel(items: items))
    }

    var body: some View {
        Button(action: {
            viewModel.updateSearch("")
            viewModel.searchText = ""
            isPresented.toggle()
        }) {
            HStack {
                Text(items.first { $0.id == selection }?.name ?? "Select Asset SubClass")
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
                    Image(systemName: "magnifyingglass")
                    TextField("Search…", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.searchText) { _, newValue in
                            viewModel.updateSearch(newValue)
                        }
                        .onSubmit {
                            if let first = viewModel.highlightedItem {
                                select(item: first)
                            }
                        }
                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.updateSearch("")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                Divider()
                ScrollViewReader { proxy in
                    List(viewModel.filteredItems, id: \.id, selection: $viewModel.highlightedItem) { item in
                        Text(item.name)
                            .lineLimit(1)
                            .tag(item)
                            .onTapGesture {
                                select(item: item)
                            }
                            .id(item.id)
                    }
                    .frame(maxHeight: 360)
                    .onAppear {
                        if let target = viewModel.items.first(where: { $0.id == selection }) {
                            viewModel.highlightedItem = target
                            proxy.scrollTo(target.id, anchor: .center)
                        }
                    }
                }
                if viewModel.filteredItems.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .frame(width: 300, height: 360)
            .onExitCommand {
                if viewModel.searchText.isEmpty {
                    isPresented = false
                } else {
                    viewModel.searchText = ""
                    viewModel.updateSearch("")
                }
            }
        }
    }

    private func select(item: AssetSubClassItem) {
        selection = item.id
        isPresented = false
    }
}
