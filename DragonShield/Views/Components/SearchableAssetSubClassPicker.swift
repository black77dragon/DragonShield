import SwiftUI
import Combine

/// Searchable picker for Asset SubClasses with alphabetical ordering and live filtering.
struct SearchableAssetSubClassPicker: View {
    let options: [AssetSubClassOption]
    @Binding var selection: Int

    @State private var search: String = ""
    @State private var debouncedSearch: String = ""
    @State private var isPresented = false

    private var filteredOptions: [AssetSubClassOption] {
        AssetSubClassPickerModel.filter(options, query: debouncedSearch)
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack {
                Text(options.first(where: { $0.id == selection })?.name ?? "Select Asset SubClass")
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
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search…", text: $search)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit(selectFirstResult)
                        .accessibilityLabel("Search Asset SubClass")
                    if !search.isEmpty {
                        Button {
                            search = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(8)
                Divider()
                if filteredOptions.isEmpty {
                    Text("No matches found. Clear the search to see all.")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        List(filteredOptions, id: \.id) { option in
                            Text(option.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .background(option.id == selection ? Color.accentColor.opacity(0.2) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = option.id
                                    isPresented = false
                                }
                                .id(option.id)
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 360)
                        .onAppear {
                            if let index = filteredOptions.firstIndex(where: { $0.id == selection }) {
                                DispatchQueue.main.async {
                                    proxy.scrollTo(filteredOptions[index].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 260)
            .onReceive(Just(search).debounce(for: .milliseconds(150), scheduler: RunLoop.main)) { value in
                debouncedSearch = value
            }
            .onExitCommand {
                if search.isEmpty {
                    isPresented = false
                } else {
                    search = ""
                }
            }
        }
    }

    private func selectFirstResult() {
        if let first = filteredOptions.first {
            selection = first.id
            isPresented = false
        }
    }
}

