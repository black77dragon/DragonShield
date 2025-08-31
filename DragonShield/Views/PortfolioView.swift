import SwiftUI

// MARK: - Main Portfolio View
struct PortfolioView: View {
    @EnvironmentObject var assetManager: AssetManager
    @State private var showAddInstrumentSheet = false
    @State private var showEditInstrumentSheet = false
    @State private var selectedAsset: DragonAsset? = nil
    @State private var showingDeleteAlert = false
    @State private var assetToDelete: DragonAsset? = nil
    @State private var searchText = ""
    // Filtering & Sorting
    @State private var typeFilters: Set<String> = []
    @State private var currencyFilters: Set<String> = []
    @State private var sortColumn: SortColumn = .name
    @State private var sortAscending: Bool = true
    @State private var showUnusedReport = false

    enum SortColumn {
        case name, type, currency, symbol, valor, isin
    }

    // Animation states
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    // Filtered assets based on search and column filters
    var filteredAssets: [DragonAsset] {
        var result = assetManager.assets
        if !searchText.isEmpty {
            result = result.filter { asset in
                asset.name.localizedCaseInsensitiveContains(searchText) ||
                asset.type.localizedCaseInsensitiveContains(searchText) ||
                asset.currency.localizedCaseInsensitiveContains(searchText) ||
                asset.tickerSymbol?.localizedCaseInsensitiveContains(searchText) == true ||
                asset.isin?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        if !typeFilters.isEmpty {
            result = result.filter { typeFilters.contains($0.type) }
        }
        if !currencyFilters.isEmpty {
            result = result.filter { currencyFilters.contains($0.currency) }
        }
        return result
    }

    // Sorted assets based on selected column
    var sortedAssets: [DragonAsset] {
        filteredAssets.sorted { a, b in
            switch sortColumn {
            case .name:
                return sortAscending ? a.name < b.name : a.name > b.name
            case .type:
                return sortAscending ? a.type < b.type : a.type > b.type
            case .currency:
                return sortAscending ? a.currency < b.currency : a.currency > b.currency
            case .symbol:
                return sortAscending ? (a.tickerSymbol ?? "") < (b.tickerSymbol ?? "") : (a.tickerSymbol ?? "") > (b.tickerSymbol ?? "")
            case .valor:
                return sortAscending ? (a.valorNr ?? "") < (b.valorNr ?? "") : (a.valorNr ?? "") > (b.valorNr ?? "")
            case .isin:
                return sortAscending ? (a.isin ?? "") < (b.isin ?? "") : (a.isin ?? "") > (b.isin ?? "")
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
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
            
            // Subtle animated background elements
            InstrumentParticleBackground()
            
            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                instrumentsContent
                modernActionBar
            }
        }
        .onAppear {
            assetManager.loadAssets()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPortfolio"))) { _ in
            assetManager.loadAssets()
        }
        .sheet(isPresented: $showAddInstrumentSheet) {
            AddInstrumentView()
                .onDisappear {
                    assetManager.loadAssets()
                }
        }
        .sheet(isPresented: $showEditInstrumentSheet) {
            if let asset = selectedAsset {
                InstrumentEditView(instrumentId: asset.id)
                    .onDisappear {
                        assetManager.loadAssets()
                        selectedAsset = nil
                    }
            }
        }
        .sheet(isPresented: $showUnusedReport) {
            UnusedInstrumentsReportView {
                showUnusedReport = false
            }
        }

        .alert("Delete Instrument", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let asset = assetToDelete {
                    confirmDelete(asset)
                }
            }
        } message: {
            if let asset = assetToDelete {
                Text("Are you sure you want to delete '\(asset.name)'?\n\nThis action cannot be undone.")
            }
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    Text("Instruments")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text("Manage your financial instruments")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Quick stats
            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(assetManager.assets.count)",
                    icon: "number.circle.fill",
                    color: .blue
                )
                
                modernStatCard(
                    title: "Types",
                    value: "\(Set(assetManager.assets.map(\.type)).count)",
                    icon: "folder.circle.fill",
                    color: .purple
                )
                
                modernStatCard(
                    title: "Currencies",
                    value: "\(Set(assetManager.assets.map(\.currency)).count)",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Search and Stats
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search instruments...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
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
            
            // Results indicator
            if !searchText.isEmpty || !typeFilters.isEmpty || !currencyFilters.isEmpty {
                HStack {
                    Text("Found \(sortedAssets.count) of \(assetManager.assets.count) instruments")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                if !typeFilters.isEmpty || !currencyFilters.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(typeFilters), id: \.self) { val in
                            filterChip(text: val) { typeFilters.remove(val) }
                        }
                        ForEach(Array(currencyFilters), id: \.self) { val in
                            filterChip(text: val) { currencyFilters.remove(val) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Instruments Content
    private var instrumentsContent: some View {
        VStack(spacing: 16) {
            if sortedAssets.isEmpty {
                emptyStateView
            } else {
                instrumentsTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "briefcase" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No instruments yet" : "No matching instruments")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    Text(searchText.isEmpty ?
                         "Start building your portfolio by adding your first instrument" :
                         "Try adjusting your search terms")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                if searchText.isEmpty {
                    Button {
                        showAddInstrumentSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Your First Instrument")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
    
    // MARK: - Instruments Table
    private var instrumentsTable: some View {
        VStack(spacing: 0) {
            // Table header
            modernTableHeader
            
            // Table content
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(sortedAssets) { asset in
                        ModernAssetRowView(
                            asset: asset,
                            isSelected: selectedAsset?.id == asset.id,
                            onTap: {
                                selectedAsset = asset
                            },
                            onEdit: {
                                selectedAsset = asset
                                showEditInstrumentSheet = true
                            }
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
    
    // MARK: - Modern Table Header
    private var modernTableHeader: some View {
        HStack {
            headerCell(title: "Name", column: .name)
                .frame(maxWidth: .infinity, alignment: .leading)

            headerCell(title: "Type", column: .type, filterValues: Array(Set(assetManager.assets.map(\.type))), filterSelection: $typeFilters)
                .frame(width: 120, alignment: .leading)

            headerCell(title: "Currency", column: .currency, filterValues: Array(Set(assetManager.assets.map(\.currency))), filterSelection: $currencyFilters)
                .frame(width: 80, alignment: .leading)

            headerCell(title: "Symbol", column: .symbol)
                .frame(width: 100, alignment: .leading)

            headerCell(title: "Valor", column: .valor)
                .frame(width: 100, alignment: .leading)

            headerCell(title: "ISIN", column: .isin)
                .frame(width: 140, alignment: .leading)

            Image(systemName: "note.text")
                .frame(width: 32, alignment: .center)
                .help("Notes")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.bottom, 1)
    }

    private func headerCell(title: String, column: SortColumn, filterValues: [String] = [], filterSelection: Binding<Set<String>>? = nil) -> some View {
        let sortedValues = filterValues.sorted { a, b in
            if a == "—" { return false }
            if b == "—" { return true }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }

        return HStack(spacing: 4) {
            Button(action: {
                if sortColumn == column {
                    sortAscending.toggle()
                } else {
                    sortColumn = column
                    sortAscending = true
                }
            }) {
                HStack(spacing: 2) {
                    Text(title)
                    Image(systemName: sortColumn == column && sortAscending ? "arrow.up" : "arrow.down")
                        .opacity(sortColumn == column ? 1 : 0.2)
                        .font(.system(size: 9))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if let binding = filterSelection {
                Menu {
                    ForEach(sortedValues, id: \.self) { val in
                        Button(action: {
                            if binding.wrappedValue.contains(val) {
                                binding.wrappedValue.remove(val)
                            } else {
                                binding.wrappedValue.insert(val)
                            }
                        }) {
                            Label(val, systemImage: binding.wrappedValue.contains(val) ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .opacity(binding.wrappedValue.isEmpty ? 0.3 : 1)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.gray)
    }

    private func filterChip(text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Modern Action Bar
    private var modernActionBar: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 16) {
                // Primary action
                Button {
                    showAddInstrumentSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add New Instrument")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    showUnusedReport = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Unused Instruments")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Open unused instruments report")

                // Secondary actions
                if selectedAsset != nil {
                    Button {
                        showEditInstrumentSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button {
                        if let asset = selectedAsset {
                            assetToDelete = asset
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
                
                // Selection indicator
                if let asset = selectedAsset {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Selected: \(asset.name)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
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
    
    // MARK: - Helper Views
    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
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
    
    // MARK: - Animations
    private func animateEntrance() {
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
    
    // MARK: - Functions
    func confirmDelete(_ asset: DragonAsset) {
        let dbManager = DatabaseManager()
        let success = dbManager.deleteInstrument(id: asset.id)

        if success {
            assetManager.loadAssets()
            selectedAsset = nil
            assetToDelete = nil
        }
    }
}

// MARK: - Modern Asset Row
struct ModernAssetRowView: View {
    let asset: DragonAsset
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Text(asset.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(asset.type)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(asset.currency)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
                .frame(width: 80, alignment: .leading)
            
            Text(asset.tickerSymbol ?? "--")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(asset.valorNr ?? "--")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(asset.isin ?? "--")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            NotesIconView(instrumentId: asset.id, instrumentName: asset.name, instrumentCode: asset.tickerSymbol ?? "")
                .frame(width: 32, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button("Edit Instrument") {
                onEdit()
            }
            Button("Select Instrument") {
                onTap()
            }
            Divider()
            Button("Copy Name") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(asset.name, forType: .string)
            }
            if let isin = asset.isin {
                Button("Copy ISIN") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(isin, forType: .string)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct NotesIconView: View {
    let instrumentId: Int
    let instrumentName: String
    let instrumentCode: String

    @State private var updatesCount: Int?
    @State private var mentionsCount: Int?
    @State private var showModal = false
    @State private var initialTab: InstrumentNotesView.Tab = .updates

    private static var cache: [Int: (Int, Int)] = [:]

    var body: some View {
        Button(action: openDefault) {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundColor(hasNotes ? .accentColor : .gray)
                .opacity(hasNotes ? 1 : 0.3)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Open notes for \(instrumentName)")
        .help(tooltip)
        .contextMenu {
            Button("Open Updates") { openUpdates() }
            Button("Open Mentions") { openMentions() }
        }
        .sheet(isPresented: $showModal) {
            InstrumentNotesView(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName, initialTab: initialTab, initialThemeId: nil, onClose: {
                showModal = false
                NotesIconView.invalidateCache(instrumentId: instrumentId)
                loadCounts()
            })
                .environmentObject(DatabaseManager())
        }
        .onAppear { loadCounts() }
    }

    private var hasNotes: Bool {
        (updatesCount ?? 0) > 0 || (mentionsCount ?? 0) > 0
    }

    private var tooltip: String {
        if let u = updatesCount, let m = mentionsCount {
            return (u == 0 && m == 0) ? "Open notes (no notes yet)" : "Updates: \(u) • Mentions: \(m)"
        } else {
            return "Open notes"
        }
    }

    private func openDefault() {
        let last = UserDefaults.standard.string(forKey: "instrumentNotesLastTab")
        initialTab = last == "mentions" ? .mentions : .updates
        showModal = true
    }

    private func openUpdates() {
        initialTab = .updates
        showModal = true
    }

    private func openMentions() {
        initialTab = .mentions
        showModal = true
    }

    private func loadCounts() {
        if let cached = NotesIconView.cache[instrumentId] {
            updatesCount = cached.0
            mentionsCount = cached.1
            return
        }
        DispatchQueue.global().async {
            let db = DatabaseManager()
            let summary = db.instrumentNotesSummary(instrumentId: instrumentId, instrumentCode: instrumentCode, instrumentName: instrumentName)
            DispatchQueue.main.async {
                updatesCount = summary.updates
                mentionsCount = summary.mentions
                NotesIconView.cache[instrumentId] = (summary.updates, summary.mentions)
            }
        }
    }

    static func invalidateCache(instrumentId: Int) {
        cache.removeValue(forKey: instrumentId)
    }
}

// MARK: - Background Particles
struct InstrumentParticleBackground: View {
    @State private var particles: [InstrumentParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(0.03))
                    .frame(width: particles[index].size, height: particles[index].size)
                    .position(particles[index].position)
                    .opacity(particles[index].opacity)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<20).map { _ in
            InstrumentParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...1200),
                    y: CGFloat.random(in: 0...800)
                ),
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.1...0.2)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 35).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct InstrumentParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

// Note: ScaleButtonStyle is defined in AddInstrumentView.swift

// MARK: - Preview
struct PortfolioView_Previews: PreviewProvider {
    static var previews: some View {
        PortfolioView()
            .environmentObject(AssetManager())
    }
}
