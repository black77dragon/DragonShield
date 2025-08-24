import SwiftUI

struct AssetSubClassPicker: View {
    @Binding var selectedId: Int
    @State private var isPresented = false
    @StateObject private var viewModel: AssetSubClassPickerViewModel
    private let maxHeight: CGFloat = 360

    init(selectedId: Binding<Int>, subClasses: [(id: Int, name: String)]) {
        _selectedId = selectedId
        _viewModel = StateObject(wrappedValue: AssetSubClassPickerViewModel(subClasses: subClasses.map { .init(id: $0.id, name: $0.name) }))
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(viewModel.displayName(for: selectedId) ?? "Select Asset SubClass")
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
                searchRow
                Divider()
                if viewModel.filtered.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(viewModel.filtered.enumerated()), id: \.1.id) { index, item in
                                    row(for: item, index: index)
                                }
                            }
                        }
                        .frame(maxHeight: maxHeight)
                        .onAppear {
                            DispatchQueue.main.async {
                                proxy.scrollTo(selectedId, anchor: .center)
                                viewModel.highlightedIndex = viewModel.indexOf(id: selectedId) ?? 0
                            }
                        }
                    }
                }
                Text("\(viewModel.filtered.count) results")
                    .font(.caption)
                    .foregroundColor(.clear)
                    .accessibilityHidden(false)
                    .accessibilityLabel("\(viewModel.filtered.count) results")
                    .accessibilityLiveRegion(.polite)
            }
            .frame(width: 260)
            .padding(.bottom, 8)
        }
        .onChange(of: viewModel.filtered) { _, _ in
            viewModel.ensureHighlightWithinBounds()
        }
    }

    private var searchRow: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search…", text: $viewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(8)
    }

    private func row(for item: AssetSubClassPickerViewModel.SubClass, index: Int) -> some View {
        Button {
            selectedId = item.id
            isPresented = false
        } label: {
            HStack {
                Text(item.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            }
            .background(index == viewModel.highlightedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .id(item.id)
    }
}

