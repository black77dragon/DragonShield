import SwiftUI

struct InstrumentEditView: View {
    @Environment(\.presentationMode) private var presentationMode
    let instrumentId: Int
    
    @State private var instrumentName = ""
    @State private var selectedGroupId = 1
    @State private var currency = "CHF"
    @State private var tickerSymbol = ""
    @State private var isin = ""
    @State private var valorNr = ""
    @State private var sector = ""
    @State private var instrumentGroups: [(id: Int, name: String)] = []
    @State private var availableCurrencies: [(code: String, name: String, symbol: String)] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var hasChanges = false
    
    // Store original values to detect changes
    @State private var originalName = ""
    @State private var originalGroupId = 1
    @State private var originalCurrency = ""
    @State private var originalTickerSymbol = ""
    @State private var originalIsin = ""
    @State private var originalValorNr = ""
    @State private var originalSector = ""

    @State private var showNotes = false
    @State private var notesInitialTab: InstrumentNotesView.Tab = .updates
    
    // MARK: - Validation
    var isValid: Bool {
        let nameValid = !instrumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currencyValid = !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currencyFormatValid = isValidCurrency
        let isinFormatValid = isValidISIN
        
        return nameValid && currencyValid && currencyFormatValid && isinFormatValid
    }
    
    private var isValidCurrency: Bool {
        // Since we're using dropdown only, currency is always valid if it's from the database
        return availableCurrencies.contains { $0.code == currency } || currency.isEmpty
    }
    
    private var isValidISIN: Bool {
        let trimmed = isin.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return trimmed.count == 12 && trimmed.prefix(2).allSatisfy { $0.isLetter }
    }
    
    // MARK: - Change Detection
    private func detectChanges() {
        hasChanges = instrumentName != originalName ||
                    selectedGroupId != originalGroupId ||
                    currency != originalCurrency ||
                    tickerSymbol != originalTickerSymbol ||
                    isin != originalIsin ||
                    valorNr != originalValorNr ||
                    sector != originalSector
    }
    
    // MARK: - Computed Properties
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 7.0
        
        if !instrumentName.isEmpty { completed += 1 }
        if selectedGroupId > 0 { completed += 1 }
        if !currency.isEmpty { completed += 1 }
        if !tickerSymbol.isEmpty { completed += 1 }
        if !isin.isEmpty { completed += 1 }
        if !valorNr.isEmpty { completed += 1 }
        if !sector.isEmpty { completed += 1 }
        
        return completed / total
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.94, green: 0.96, blue: 0.99),
                    Color(red: 0.91, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle animated background elements
            EditParticleBackground()
            
            // Main content
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    modernHeader
                    changeIndicator
                    progressBar
                    modernContent
                    modernFooter
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.clear)
            }
        }
        .frame(width: 700, height: 750)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadInstrumentGroups()
            loadAvailableCurrencies()
            loadInstrumentData()
            animateEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("✅") {
                    animateExit()
                } else {
                    // For error messages, just dismiss the alert
                    showingAlert = false
                }
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showNotes) {
            InstrumentNotesView(instrumentId: instrumentId, instrumentCode: tickerSymbol.isEmpty ? instrumentName : tickerSymbol.uppercased(), instrumentName: instrumentName, initialTab: notesInitialTab, initialThemeId: nil, onClose: { showNotes = false })
                .environmentObject(DatabaseManager())
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            // Close button with light styling
            Button {
                if hasChanges {
                    showUnsavedChangesAlert()
                } else {
                    animateExit()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // Modern title with icon
            HStack(spacing: 12) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Edit Instrument")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            // Save button with premium styling
            Button {
                saveInstrument()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Text(isLoading ? "Saving..." : "Save Changes")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 32)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if isValid && hasChanges && !isLoading {
                            Color.orange
                        } else {
                            Color.gray.opacity(0.4)
                        }
                    }
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isValid && hasChanges ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading || !isValid || !hasChanges)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    // MARK: - Change Indicator
    private var changeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }
    
    // MARK: - Modern Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completion")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(completionPercentage * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .orange.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Modern Content
    private var modernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                requiredSection
                optionalSection
                if FeatureFlags.portfolioInstrumentUpdatesEnabled() {
                    updatesInThemesSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Required Section
    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Required Information", icon: "checkmark.shield.fill", color: .orange)
            
            VStack(spacing: 16) {
                modernTextField(
                    title: "Instrument Name",
                    text: $instrumentName,
                    placeholder: "e.g., Apple Inc.",
                    icon: "building.2.crop.circle.fill",
                    isRequired: true
                )
                .onChange(of: instrumentName) { oldValue, newValue in detectChanges() }
                
                // Asset SubClass and Currency side by side
                HStack(spacing: 16) {
                    modernAssetTypePicker()
                        .frame(maxWidth: .infinity)
                    
                    modernCurrencyField()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background(editGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Optional Section
    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Optional Information", icon: "info.circle.fill", color: .red)
            
            VStack(spacing: 16) {
                modernTextField(
                    title: "Ticker Symbol",
                    text: $tickerSymbol,
                    placeholder: "e.g., AAPL",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    isRequired: false,
                    autoUppercase: true
                )
                .onChange(of: tickerSymbol) { oldValue, newValue in detectChanges() }
                
                modernTextField(
                    title: "ISIN Code",
                    text: $isin,
                    placeholder: "e.g., US0378331005",
                    icon: "number.circle.fill",
                    isRequired: false,
                    autoUppercase: true,
                    validation: isValidISIN,
                    errorMessage: "ISIN must be 12 characters starting with 2 letters"
                )
                .onChange(of: isin) { oldValue, newValue in detectChanges() }

                modernTextField(
                    title: "Valor Number",
                    text: $valorNr,
                    placeholder: "e.g., 1234567",
                    icon: "number.circle",
                    isRequired: false,
                    autoUppercase: false
                )
                .onChange(of: valorNr) { oldValue, newValue in detectChanges() }
                
                modernTextField(
                    title: "Sector",
                    text: $sector,
                    placeholder: "e.g., Technology",
                    icon: "briefcase.circle.fill",
                    isRequired: false
                )
                .onChange(of: sector) { oldValue, newValue in detectChanges() }
            }
        }
        .padding(24)
        .background(editGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .red.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private var updatesInThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader(title: "Updates in Themes", icon: "doc.text", color: .blue)
                Spacer()
                Button("Open Instrument Notes") { openInstrumentNotes() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Open Instrument Notes for \(instrumentName)")
            }
        }
        .padding(24)
        .background(editGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func openInstrumentNotes() {
        let last = UserDefaults.standard.string(forKey: "instrumentNotesLastTab")
        notesInitialTab = last == "mentions" ? .mentions : .updates
        showNotes = true
        let payload: [String: Any] = ["instrumentId": instrumentId, "action": "instrument_notes_open", "source": "panel"]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }
    
    // MARK: - Edit Glassmorphism Background
    private var editGlassMorphismBackground: some View {
        ZStack {
            // Base glass effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.85),
                            .white.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            .orange.opacity(0.05),
                            .red.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - Modern Footer
    private var modernFooter: some View {
        Spacer()
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
    
    private func modernTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        icon: String,
        isRequired: Bool,
        autoUppercase: Bool = false,
        validation: Bool = true,
        errorMessage: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(title + (isRequired ? "*" : ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                Spacer()
                
                if !text.wrappedValue.isEmpty && !validation {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            !text.wrappedValue.isEmpty && !validation ?
                                .red.opacity(0.6) : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { oldValue, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
            
            if !text.wrappedValue.isEmpty && !validation && !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private func modernAssetTypePicker() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Text("Asset SubClass*")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))

                Spacer()
            }

            AssetSubClassPicker(groups: instrumentGroups, selectedGroupId: $selectedGroupId)
                .onChange(of: selectedGroupId) { _, _ in
                    detectChanges()
                }
        }
    }
    
    private func modernCurrencyField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text("Currency*")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                Spacer()
                
                if !currency.isEmpty && !isValidCurrency {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            
            Menu {
                ForEach(availableCurrencies, id: \.code) { curr in
                    Button(action: {
                        currency = curr.code
                        detectChanges()
                    }) {
                        HStack {
                            Text(curr.code)
                                .fontWeight(.medium)
                            Spacer()
                            Text(curr.symbol)
                                .foregroundColor(.secondary)
                            Text("(\(curr.name))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            } label: {
                HStack {
                    if let selectedCurrency = availableCurrencies.first(where: { $0.code == currency }) {
                        HStack(spacing: 6) {
                            Text(selectedCurrency.code)
                                .foregroundColor(.black)
                                .font(.system(size: 16, weight: .medium))
                            Text(selectedCurrency.symbol)
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    } else {
                        Text(currency.isEmpty ? "Select Currency" : currency)
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                    }
                    
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
            
            if !currency.isEmpty && !isValidCurrency {
                Text("Please select a currency from the dropdown")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Animations
    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            formScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headerOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            sectionsOffset = 0
        }
    }
    
    private func animateExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Functions
    func loadInstrumentGroups() {
        let dbManager = DatabaseManager()
        instrumentGroups = AssetSubClassLookup.sort(dbManager.fetchAssetTypes())
    }
    
    func loadAvailableCurrencies() {
        let dbManager = DatabaseManager()
        availableCurrencies = dbManager.fetchActiveCurrencies()
    }
    
    func loadInstrumentData() {
        let dbManager = DatabaseManager()
        if let details = dbManager.fetchInstrumentDetails(id: instrumentId) {
            instrumentName = details.name
            selectedGroupId = details.subClassId
            currency = details.currency
            valorNr = details.valorNr ?? ""
            tickerSymbol = details.tickerSymbol ?? ""
            isin = details.isin ?? ""
            sector = details.sector ?? ""
            
            // Store original values for change detection
            originalName = instrumentName
            originalGroupId = selectedGroupId
            originalCurrency = currency
            originalValorNr = valorNr
            originalTickerSymbol = tickerSymbol
            originalIsin = isin
            originalSector = sector
        }
    }
    
    private func showUnsavedChangesAlert() {
        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "You have unsaved changes. Are you sure you want to close without saving?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save & Close")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Save & Close
            saveInstrument()
        case .alertSecondButtonReturn: // Discard Changes
            animateExit()
        default: // Cancel
            break
        }
    }
    
    func saveInstrument() {
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let dbManager = DatabaseManager()
        let success = dbManager.updateInstrument(
            id: instrumentId,
            name: instrumentName.trimmingCharacters(in: .whitespacesAndNewlines),
            subClassId: selectedGroupId,
            currency: currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            valorNr: valorNr.isEmpty ? nil : valorNr,
            tickerSymbol: tickerSymbol.isEmpty ? nil : tickerSymbol.uppercased(),
            isin: isin.isEmpty ? nil : isin.uppercased(),
            sector: sector.isEmpty ? nil : sector
        )
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                // Update original values to reflect saved state
                self.originalName = self.instrumentName
                self.originalGroupId = self.selectedGroupId
                self.originalCurrency = self.currency
                self.originalTickerSymbol = self.tickerSymbol
                self.originalIsin = self.isin
                self.originalSector = self.sector
                self.detectChanges()
                
                NotificationCenter.default.post(name: NSNotification.Name("RefreshPortfolio"), object: nil)
                
                // Auto-dismiss after successful save without showing alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.animateExit()
                }
            } else {
                self.alertMessage = "❌ Failed to update instrument. Please try again."
                self.showingAlert = true
            }
        }
    }
}

// MARK: - Supporting Views

struct EditParticleBackground: View {
    @State private var particles: [EditParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.04))
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
        particles = (0..<12).map { _ in
            EditParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...750)
                ),
                size: CGFloat.random(in: 3...10),
                opacity: Double.random(in: 0.1...0.25)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 900
                particles[index].opacity = Double.random(in: 0.05...0.2)
            }
        }
    }
}

struct EditParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

// MARK: - History
// Version 1.1 - Fixed onChange deprecation warnings for macOS 14.0+
// - Updated all .onChange(of:) { _ in } to .onChange(of:) { oldValue, newValue in }
// - Updated .onChange(of:) { newValue in } to .onChange(of:) { oldValue, newValue in }
// - Maintained all existing functionality including change detection and validation
