#if os(iOS)
import SwiftUI

struct TodoBoardView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @StateObject private var viewModel = KanbanBoardViewModel()
    @State private var tagsByID: [Int: TagRow] = [:]
    @State private var visibleColumns: Set<KanbanColumn> = Set(KanbanColumn.allCases)
    @State private var selectedFontSize: KanbanFontSize = .medium
    @State private var sortMode: KanbanSortMode = .dueDate
    @State private var hasHydratedFontSize = false
    @State private var isHydratingFontSize = false
    @State private var hasHydratedVisibleColumns = false
    @State private var columnBackgroundShade: Double = 10
    @State private var hasHydratedColumnBackgroundShade = false

    private let columnOrder = KanbanColumn.allCases
    private let visibleColumnsDefaultsKey = "TodoBoard.visibleColumns.v1"
    private let columnBackgroundShadeDefaultsKey = "TodoBoard.columnBackgroundShade.v1"

    private var stats: [BoardStat] {
        let total = viewModel.allTodos.count
        let inProgress = viewModel.count(for: .doing)
        let completed = viewModel.count(for: .done)
        let overdue = overdueTodos.count
        let completionRate = total == 0 ? 0 : Double(completed) / Double(total)
        return [
            BoardStat(id: "total", title: "Total Tasks", value: "\(total)", icon: "list.bullet", accent: Color(hex: "5B6CE3")),
            BoardStat(id: "in-progress", title: "In Progress", value: "\(inProgress)", icon: "hammer", accent: KanbanColumn.doing.palette.accent),
            BoardStat(id: "completed", title: "Completed", value: "\(completed)", icon: "checkmark.circle", accent: KanbanColumn.done.palette.accent),
            BoardStat(id: "overdue", title: "Overdue", value: "\(overdue)", icon: "clock.badge.exclamationmark", accent: Color(hex: "F16063")),
            BoardStat(id: "completion", title: "Completion", value: completionRate.formattedPercentage, icon: "chart.bar", accent: Color(hex: "7C5CFF"), progress: completionRate)
        ]
    }

    private var overdueTodos: [KanbanTodo] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return viewModel.allTodos.filter { todo in
            guard !todo.isCompleted,
                  let due = todo.dueDate else { return false }
            let dueDay = calendar.startOfDay(for: due)
            return dueDay < today
        }
    }

    private var filteredColumns: [KanbanColumn] {
        columnOrder.filter { visibleColumns.contains($0) }
    }

    private var hasSelection: Bool {
        !visibleColumns.isEmpty
    }

    private var columnBackgroundColor: Color {
        let normalized = max(0, min(columnBackgroundShade, 100)) / 100
        let whiteValue = 1 - normalized
        return Color(.sRGB, white: whiteValue, opacity: 1)
    }

    private var columnBorderColor: Color {
        columnBackgroundColor.opacity(0.6)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !hasSelection {
                    Text("Select at least one column to show To-Dos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 48)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(filteredColumns) { column in
                                columnView(for: column)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(hex: "F5F6FB"))
        .navigationTitle("To-Do Board")
        .toolbar { toolbarContent }
        .refreshable { await refresh() }
        .task { await refresh() }
        .onAppear {
            hydrateFontSizeIfNeeded()
            hydrateVisibleColumnsIfNeeded()
            hydrateColumnBackgroundShadeIfNeeded()
        }
        .onReceive(dbManager.$todoBoardFontSize) { handleExternalFontSizeUpdate($0) }
        .onChangeCompat(of: selectedFontSize) { _ in
            persistFontSize()
        }
        .onChangeCompat(of: visibleColumns) { _ in
            persistVisibleColumns()
        }
        .onChangeCompat(of: columnBackgroundShade) { _ in
            persistColumnBackgroundShade()
        }
        .alert("Cannot Archive Repeating To-Dos", isPresented: Binding(get: {
            viewModel.archiveBlockedByRepeatingTodos
        }, set: { newValue in
            if !newValue {
                viewModel.archiveBlockedByRepeatingTodos = false
            }
        })) {
            Button("OK", role: .cancel) {
                viewModel.archiveBlockedByRepeatingTodos = false
            }
        } message: {
            Text("Remove the repeat setting before archiving these items.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("get things done")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Track priorities, make progress, and celebrate wins.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(stats) { stat in
                        BoardStatCard(stat: stat)
                    }
                }
                .padding(.vertical, 4)
            }

            configurationRow
        }
    }

    private var fontSizeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Font Size")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("Font Size", selection: $selectedFontSize) {
                ForEach(KanbanFontSize.allCases, id: \.self) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E5E7FF"), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .frame(width: 200, alignment: .leading)
    }

    private var configurationRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                backgroundShadeControl
                fontSizeControl
                columnSelectionMenu
                sortModeControl
            }
            .padding(.vertical, 4)
        }
    }

    private var backgroundShadeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Column Background")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(max(0, min(columnBackgroundShade, 100))))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $columnBackgroundShade, in: 0...100, step: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E5E7FF"), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .frame(width: 220, alignment: .leading)
    }

    private var columnSelectionMenu: some View {
        Menu {
            Section("Columns") {
                ForEach(columnOrder) { column in
                    let isActive = visibleColumns.contains(column)
                    Button {
                        if isActive {
                            guard visibleColumns.count > 1 else { return }
                            visibleColumns.remove(column)
                        } else {
                            visibleColumns.insert(column)
                        }
                    } label: {
                        Label(column.displayTitle, systemImage: isActive ? "checkmark.circle.fill" : "circle")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }

            Section {
                Button("Show All Columns") {
                    visibleColumns = Set(columnOrder)
                }
                Button("Hide Done & Archived") {
                    visibleColumns = Set(columnOrder.filter { ![.done, .archived].contains($0) })
                }
            }
        } label: {
            Label("Column Selection", systemImage: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "DEE0EA"), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
                .foregroundStyle(Color(hex: "474C63"))
        }
    }

    private var sortModeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sort Tasks")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("Sort Tasks", selection: $sortMode) {
                ForEach(KanbanSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "DEE0EA"), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .frame(width: 220, alignment: .leading)
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing scheduled yet")
                .font(.headline)
            Text("Add To-Dos from the desktop app or Quick Add to start filling the board.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func columnView(for column: KanbanColumn) -> some View {
        let todos = sortedTodos(for: column)
        let containsRepeating = column == .done && todos.contains { $0.isRepeating }
        let palette = column.palette

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(column.displayTitle)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black)
                    Text(column.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if column == .done && !todos.isEmpty {
                    Button {
                        viewModel.archiveDoneTodos()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "E0E2EB"))
                            )
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                    .disabled(containsRepeating)
                    .opacity(containsRepeating ? 0.4 : 1.0)
                    .accessibilityHint(containsRepeating ? "Remove repeat settings before archiving." : "Move all done items to archive")
                }

                Text("\(todos.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "D9DCE8"), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.black)
            }

            if todos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No tasks yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black)
                    Text(column.emptyPlaceholder)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
            } else {
                if containsRepeating {
                    Text("Repeat-enabled tasks cannot be archived. Clear repeating before archiving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(todos) { todo in
                            TodoCard(todo: todo,
                                     fontSize: selectedFontSize,
                                     tags: tags(for: todo),
                                     palette: palette,
                                     onToggleCompletion: { newValue in
                                viewModel.setCompletion(for: todo.id, isCompleted: newValue)
                            })
                        }
                    }
                    .padding(.trailing, 2)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(20)
        .frame(width: 300, alignment: .topLeading)
        .frame(minHeight: 420, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(columnBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(columnBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }

    private func tags(for todo: KanbanTodo) -> [TagRow] {
        todo.tagIDs.compactMap { tagsByID[$0] }
    }

    private func sortedTodos(for column: KanbanColumn) -> [KanbanTodo] {
        let todos = viewModel.todos(in: column)
        return sortMode.sort(todos: todos)
    }

    private func refresh() async {
        await MainActor.run {
            viewModel.refreshFromStorage()
            importSnapshotTodosIfAvailable()
            reloadTags()
        }
    }

    private func reloadTags() {
        let repository = TagRepository(dbManager: dbManager)
        tagsByID = Dictionary(uniqueKeysWithValues: repository.listActive().map { ($0.id, $0) })
    }

    private func importSnapshotTodosIfAvailable() {
        guard dbManager.hasOpenConnection() else {
            print("[TodoBoard] Database not open; skipping snapshot import")
            return
        }
        guard let payload = dbManager.configurationValue(for: KanbanSnapshotConfigurationKey) else {
            print("[TodoBoard] Snapshot JSON missing from Configuration")
            return
        }
        if payload.isEmpty {
            print("[TodoBoard] Snapshot JSON empty string")
            return
        }
        guard let todos = KanbanSnapshotCodec.decode(json: payload) else {
            print("[TodoBoard] Failed to decode snapshot JSON (length=\(payload.count))")
            return
        }
        print("[TodoBoard] Imported \(todos.count) snapshot to-dos")
        viewModel.overwrite(with: todos)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Columns") {
                    ForEach(columnOrder) { column in
                        let binding = Binding(
                            get: { visibleColumns.contains(column) },
                            set: { isPresented in
                                if isPresented {
                                    visibleColumns.insert(column)
                                } else {
                                    guard visibleColumns.count > 1 else { return }
                                    visibleColumns.remove(column)
                                }
                            }
                        )
                        Toggle(isOn: binding) {
                            Label(column.displayTitle, systemImage: column.iconName)
                        }
                    }
                }

                Section {
                    Button("Show All") {
                        visibleColumns = Set(columnOrder)
                    }
                    Button("Hide Completed") {
                        visibleColumns = Set(columnOrder.filter { ![.done, .archived].contains($0) })
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private func hydrateFontSizeIfNeeded() {
        guard !hasHydratedFontSize else { return }
        hasHydratedFontSize = true
        isHydratingFontSize = true
        if let stored = KanbanFontSize(rawValue: dbManager.todoBoardFontSize) {
            selectedFontSize = stored
        }
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }

    private func handleExternalFontSizeUpdate(_ rawValue: String) {
        guard !isHydratingFontSize,
              let size = KanbanFontSize(rawValue: rawValue),
              size != selectedFontSize else { return }
        isHydratingFontSize = true
        selectedFontSize = size
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }

    private func persistFontSize() {
        guard !isHydratingFontSize else { return }
        guard dbManager.todoBoardFontSize != selectedFontSize.rawValue else { return }
        isHydratingFontSize = true
        dbManager.setTodoBoardFontSize(selectedFontSize.rawValue)
        DispatchQueue.main.async {
            isHydratingFontSize = false
        }
    }

    private func hydrateColumnBackgroundShadeIfNeeded() {
        guard !hasHydratedColumnBackgroundShade else { return }
        hasHydratedColumnBackgroundShade = true
        if UserDefaults.standard.object(forKey: columnBackgroundShadeDefaultsKey) != nil {
            columnBackgroundShade = UserDefaults.standard.double(forKey: columnBackgroundShadeDefaultsKey)
        } else {
            columnBackgroundShade = 10
        }
    }

    private func persistColumnBackgroundShade() {
        guard hasHydratedColumnBackgroundShade else { return }
        UserDefaults.standard.set(columnBackgroundShade, forKey: columnBackgroundShadeDefaultsKey)
    }

    private var defaultVisibleColumns: Set<KanbanColumn> { Set(columnOrder) }

    private func hydrateVisibleColumnsIfNeeded() {
        guard !hasHydratedVisibleColumns else { return }
        hasHydratedVisibleColumns = true
        let stored = UserDefaults.standard.array(forKey: visibleColumnsDefaultsKey) as? [String]
        let decoded = stored?.compactMap(KanbanColumn.init(rawValue:)) ?? []
        visibleColumns = decoded.isEmpty ? defaultVisibleColumns : Set(decoded)
    }

    private func persistVisibleColumns() {
        guard hasHydratedVisibleColumns else { return }
        let ordered = columnOrder.filter { visibleColumns.contains($0) }
        let payload = (ordered.isEmpty ? columnOrder : ordered).map { $0.rawValue }
        UserDefaults.standard.set(payload, forKey: visibleColumnsDefaultsKey)
    }
}

private extension Double {
    var formattedPercentage: String {
        guard isFinite else { return "0%" }
        let clamped = max(0, min(self, 1))
        return String(format: "%.0f%%", clamped * 100)
    }
}

private struct BoardStat: Identifiable {
    let id: String
    let title: String
    let value: String
    let icon: String
    let accent: Color
    var progress: Double?
}

private struct BoardStatCard: View {
    let stat: BoardStat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(stat.accent.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: stat.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(stat.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(stat.value)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(stat.accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 180, height: 60, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "E6E8F5"), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

private struct KanbanColumnPalette {
    let accent: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let cardBackground: Color
    let cardBorder: Color
    let filterActiveBackground: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var shadowColor: Color {
        accent.opacity(0.12)
    }
}

private extension KanbanColumn {
    var palette: KanbanColumnPalette {
        switch self {
        case .backlog:
            return KanbanColumnPalette(
                accent: Color(hex: "F29933"),
                backgroundTop: Color(hex: "FFF8E9"),
                backgroundBottom: Color(hex: "FFEFD1"),
                cardBackground: .white,
                cardBorder: Color(hex: "FFE2B2"),
                filterActiveBackground: Color(hex: "FFF3DF")
            )
        case .prioritised:
            return KanbanColumnPalette(
                accent: Color(hex: "F45B7A"),
                backgroundTop: Color(hex: "FFEFF4"),
                backgroundBottom: Color(hex: "FFDDE5"),
                cardBackground: .white,
                cardBorder: Color(hex: "FFC5D5"),
                filterActiveBackground: Color(hex: "FFE7ED")
            )
        case .doing:
            return KanbanColumnPalette(
                accent: Color(hex: "7A6BFF"),
                backgroundTop: Color(hex: "F2F1FF"),
                backgroundBottom: Color(hex: "E3E1FF"),
                cardBackground: .white,
                cardBorder: Color(hex: "CCC8FF"),
                filterActiveBackground: Color(hex: "ECEBFF")
            )
        case .done:
            return KanbanColumnPalette(
                accent: Color(hex: "42C195"),
                backgroundTop: Color(hex: "EEFBF5"),
                backgroundBottom: Color(hex: "DBF3E7"),
                cardBackground: .white,
                cardBorder: Color(hex: "B5E8D4"),
                filterActiveBackground: Color(hex: "E8F7F0")
            )
        case .archived:
            return KanbanColumnPalette(
                accent: Color(hex: "8F95A5"),
                backgroundTop: Color(hex: "F4F5F8"),
                backgroundBottom: Color(hex: "E7E8EF"),
                cardBackground: .white,
                cardBorder: Color(hex: "D5D6E0"),
                filterActiveBackground: Color(hex: "F0F1F5")
            )
        }
    }

    var displayTitle: String {
        switch self {
        case .prioritised: return "To Do"
        case .doing: return "In Progress"
        default: return title
        }
    }

    var subtitle: String {
        switch self {
        case .backlog: return "Ideas & discovery"
        case .prioritised: return "Ready to take on"
        case .doing: return "Actively moving"
        case .done: return "Wrapped up work"
        case .archived: return "Saved for reference"
        }
    }
}

private struct TodoCard: View {
    let todo: KanbanTodo
    let fontSize: KanbanFontSize
    let tags: [TagRow]
    let palette: KanbanColumnPalette
    var onToggleCompletion: (Bool) -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()

    private enum DueState {
        case overdue, dueToday, upcoming, none
    }

    private var dueDateString: String? {
        guard let dueDate = todo.dueDate else { return nil }
        return Self.dateFormatter.string(from: dueDate)
    }

    private var dueState: DueState {
        guard let dueDate = todo.dueDate else { return .none }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        if due < today { return .overdue }
        if due == today { return .dueToday }
        return .upcoming
    }

    private var dueDisplayText: Text {
        switch dueState {
        case .overdue:
            return Text("⚠️ ") + Text(dueDateString ?? "")
        case .dueToday, .upcoming:
            if let value = dueDateString {
                return Text(value)
            }
            fallthrough
        case .none:
            return Text("No date")
        }
    }

    private var dueColor: Color {
        switch dueState {
        case .overdue: return .red
        case .dueToday: return .blue
        case .upcoming, .none: return .secondary
        }
    }

    private var dueWeight: Font.Weight {
        switch dueState {
        case .overdue, .dueToday: return .bold
        case .upcoming, .none: return .regular
        }
    }

    private var dueStateBackgroundColor: Color? {
        switch dueState {
        case .overdue: return Color(hex: "FFE2E2")
        case .dueToday: return Color(hex: "E5F1FF")
        default: return nil
        }
    }

    private var completedColumnBackgroundColor: Color? {
        guard [.done, .archived].contains(todo.column) else { return nil }
        return Color(hex: "E9EAEF")
    }

    private var cardBackgroundColor: Color {
        completedColumnBackgroundColor ?? dueStateBackgroundColor ?? palette.cardBackground
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todo.description)
                        .font(fontSize.primaryFont)
                        .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.leading)
                        .strikethrough(todo.isCompleted, color: .secondary)

                    if let frequency = todo.repeatFrequency {
                        RepeatBadge(frequency: frequency, fontSize: fontSize)
                    }
                }

                Spacer()

                Button {
                    onToggleCompletion(!todo.isCompleted)
                } label: {
                    Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(todo.isCompleted ? palette.accent : Color.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todo.isCompleted ? "Mark as not completed" : "Mark as completed")
                .accessibilityHint(todo.repeatFrequency != nil ? "Completing will reschedule the due date." : "")
            }

            HStack(spacing: 16) {
                PriorityBadge(priority: todo.priority, fontSize: fontSize)

                Rectangle()
                    .fill(Color(hex: "D8D9E3"))
                    .frame(width: 1, height: 18)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: fontSize.secondaryPointSize - 1, weight: .medium))
                        .foregroundStyle(dueColor)
                    dueDisplayText
                        .font(fontSize.dueDateFont(weight: dueWeight))
                        .foregroundStyle(todo.isCompleted ? Color.secondary : dueColor)
                        .monospacedDigit()
                }
            }

            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(tags) { tag in
                        TagPill(tag: tag)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.cardBorder, lineWidth: 0.7)
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(todo.priority.color)
                .frame(width: 56, height: 4)
                .offset(x: 20, y: 2)
        }
        .opacity(todo.isCompleted ? 0.6 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private struct PriorityBadge: View {
        let priority: KanbanPriority
        let fontSize: KanbanFontSize

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: priority.iconName)
                    .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                Text(priority.displayName.uppercased())
                    .font(fontSize.badgeFont)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(priority.color.opacity(0.16))
            )
            .foregroundColor(priority.color)
        }
    }

    private struct RepeatBadge: View {
        let frequency: KanbanRepeatFrequency
        let fontSize: KanbanFontSize

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: frequency.systemImageName)
                    .font(.system(size: fontSize.secondaryPointSize, weight: .semibold))
                Text(frequency.displayName)
                    .font(fontSize.secondaryFont)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
            .foregroundColor(.accentColor)
            .accessibilityLabel("Repeats \(frequency.displayName)")
        }
    }
}

private struct TagPill: View {
    let tag: TagRow

    private var backgroundColor: Color {
        guard let hex = tag.color, !hex.isEmpty else { return Color.gray.opacity(0.2) }
        return Color(hex: hex).opacity(0.18)
    }

    private var textColor: Color {
        guard let hex = tag.color, !hex.isEmpty else { return .primary }
        return Color.textColor(forHex: hex)
    }

    var body: some View {
        Text("#\(tag.displayName)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundStyle(textColor)
    }
}

private extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value, initial: false) { _, newValue in
                perform(newValue)
            }
        } else {
            self.onChange(of: value, perform: perform)
        }
    }
}
#endif
