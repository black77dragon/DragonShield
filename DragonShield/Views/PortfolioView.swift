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
    
    // Animation states
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0
    
    // Filtered assets based on search
    var filteredAssets: [DragonAsset] {
        if searchText.isEmpty {
            return assetManager.assets
        } else {
            return assetManager.assets.filter { asset in
                asset.name.localizedCaseInsensitiveContains(searchText) ||
                asset.type.localizedCaseInsensitiveContains(searchText) ||
                asset.currency.localizedCaseInsensitiveContains(searchText) ||
                asset.tickerSymbol?.localizedCaseInsensitiveContains(searchText) == true ||
                asset.isin?.localizedCaseInsensitiveContains(searchText) == true
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
            if let asset = selectedAsset,
               let instrumentId = getInstrumentId(for: asset) {
                InstrumentEditView(instrumentId: instrumentId)
                    .onDisappear {
                        assetManager.loadAssets()
                        selectedAsset = nil
                    }
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
            if !searchText.isEmpty {
                HStack {
                    Text("Found \(filteredAssets.count) of \(assetManager.assets.count) instruments")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }
    
    // MARK: - Instruments Content
    private var instrumentsContent: some View {
        VStack(spacing: 16) {
            if filteredAssets.isEmpty {
                emptyStateView
            } else {
                instrumentsTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .offset(y: contentOffset)
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
                    ForEach(filteredAssets) { asset in
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
            Text("Name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Type")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text("Currency")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text("Symbol")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            Text("ISIN")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.bottom, 1)
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
        if let instrumentId = getInstrumentId(for: asset) {
            let dbManager = DatabaseManager()
            let success = dbManager.deleteInstrument(id: instrumentId)
            
            if success {
                assetManager.loadAssets()
                selectedAsset = nil
                assetToDelete = nil
            }
        }
    }
    
    private func getInstrumentId(for asset: DragonAsset) -> Int? {
        let dbManager = DatabaseManager()
        let instruments = dbManager.fetchAssets()
        return instruments.first { $0.name == asset.name }?.id
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
            
            Text(asset.isin ?? "--")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
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
