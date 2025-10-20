import SwiftUI

struct InstrumentEditView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var dbManager: DatabaseManager
    let instrumentId: Int

    private typealias PortfolioMembershipRow = DatabaseManager.InstrumentPortfolioMembershipRow
    
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
    // Price management
    @State private var latestPrice: Double? = nil
    @State private var latestPriceAsOf: Date? = nil
    @State private var priceInput: String = ""
    @State private var priceAsOf: Date = Date()
    @State private var priceMessage: String? = nil
    
    // Soft delete / lifecycle
    @State private var isActiveFlag: Bool = true
    @State private var isDeletedFlag: Bool = false
    @State private var positionsCount: Int = 0
    @State private var portfoliosCount: Int = 0
    @State private var deleteReason: String = "No longer tracked"
    @State private var deleteNote: String = ""
    @State private var showLifecycleInfo = false
    @State private var portfolioMemberships: [PortfolioMembershipRow] = []
    @State private var instrumentPositions: [PositionReportData] = []
    @State private var openThemeId: Int? = nil
    @State private var editingPosition: PositionReportData? = nil
    
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
        VStack(spacing: 0) {
            modernHeader
            changeIndicator
            progressBar
            Divider()
            modernContent
            modernFooter
        }
        .frame(width: 660, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(formScale)
        .onAppear {
            loadInstrumentGroups()
            loadAvailableCurrencies()
            loadInstrumentData()
            loadLatestPrice()
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
            InstrumentNotesView(
                instrumentId: instrumentId,
                instrumentCode: tickerSymbol.isEmpty ? instrumentName : tickerSymbol.uppercased(),
                instrumentName: instrumentName,
                initialTab: notesInitialTab,
                initialThemeId: nil,
                onClose: { showNotes = false }
            )
            .environmentObject(dbManager)
        }
        .sheet(item: Binding(get: {
            openThemeId.map { Ident(value: $0) }
        }, set: { newValue in
            openThemeId = newValue?.value
        })) { ident in
            PortfolioThemeWorkspaceView(
                themeId: ident.value,
                origin: "instrument_edit",
                initialTab: .updates
            )
            .environmentObject(dbManager)
        }
        .sheet(item: $editingPosition) { position in
            PositionFormView(position: position) {
                refreshInstrumentUsage()
            }
            .environmentObject(dbManager)
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack(spacing: 12) {
            // Close button with light styling
            Button {
                if hasChanges {
                    showUnsavedChangesAlert()
                } else {
                    animateExit()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .padding(6)
                    .foregroundColor(.secondary)
                    .background(Color.secondary.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            
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
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Save button with premium styling
            Button {
                saveInstrument()
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: hasChanges ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    
                    Text(isLoading ? "Saving..." : "Save")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 28)
                .padding(.horizontal, 12)
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
            }
            .disabled(isLoading || !isValid || !hasChanges)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }
    
    // MARK: - Modern Progress Bar
    private var progressBar: some View {
        VStack(spacing: 6) {
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
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Modern Content
    private var modernContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                requiredSection
                optionalSection
                priceSection
                lifecycleSection
                updatesInThemesSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Required Section
    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Required Information", icon: "checkmark.shield.fill", color: .orange)
            
            VStack(spacing: 12) {
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
                    AssetSubClassPickerView(
                        instrumentGroups: instrumentGroups,
                        selectedGroupId: $selectedGroupId,
                        onSelect: { detectChanges() }
                    )
                        .frame(maxWidth: .infinity)
                    
                    modernCurrencyField()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Optional Section
    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Optional Information", icon: "info.circle.fill", color: .red)
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    compactTextField(
                        title: "Ticker Symbol",
                        text: $tickerSymbol,
                        placeholder: "e.g., AAPL",
                        isRequired: false,
                        autoUppercase: true
                    )
                    .onChange(of: tickerSymbol) { _, _ in detectChanges() }

                    compactTextField(
                        title: "Valor Number",
                        text: $valorNr,
                        placeholder: "e.g., 1234567",
                        isRequired: false,
                        autoUppercase: false
                    )
                    .onChange(of: valorNr) { _, _ in detectChanges() }
                }

                GridRow {
                    compactTextField(
                        title: "ISIN Code",
                        text: $isin,
                        placeholder: "e.g., US0378331005",
                        isRequired: false,
                        autoUppercase: true,
                        validation: isValidISIN,
                        errorMessage: "ISIN must be 12 characters starting with 2 letters"
                    )
                    .onChange(of: isin) { _, _ in detectChanges() }

                    compactTextField(
                        title: "Sector",
                        text: $sector,
                        placeholder: "e.g., Technology",
                        isRequired: false
                    )
                    .onChange(of: sector) { _, _ in detectChanges() }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Price Section
    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Instrument Price", icon: "dollarsign.circle.fill", color: .green)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Price").font(.caption).foregroundColor(.secondary)
                        Text(formattedLatestPrice())
                            .font(.system(size: 14, weight: .medium))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("As Of").font(.caption).foregroundColor(.secondary)
                        Text(formattedAsOf(latestPriceAsOf))
                            .font(.system(size: 14, weight: .medium))
                    }
                    Spacer()
                }
                Divider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Set Price (\(currency))").font(.caption).foregroundColor(.secondary)
                        TextField("e.g., 123.45", text: $priceInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                    VStack(alignment: .leading) {
                        Text("As Of").font(.caption).foregroundColor(.secondary)
                        DatePicker("", selection: $priceAsOf, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    VStack { Spacer(minLength: 0)
                        Button("Save Price") { saveInstrumentPrice() }
                            .buttonStyle(.borderedProminent)
                            .disabled(Double(priceInput) == nil)
                    }
                    VStack { Spacer(minLength: 0)
                        Button("Refresh") { loadLatestPrice() }
                    }
                }
                if let msg = priceMessage {
                    Text(msg).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Price helpers
    private func iso8601Formatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private static let priceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let quantityFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    private func formattedLatestPrice() -> String {
        guard let p = latestPrice else { return "—" }
        let formatted = Self.priceFormatter.string(from: NSNumber(value: p)) ?? String(format: "%.2f", p)
        return currency.isEmpty ? formatted : "\(formatted) \(currency)"
    }

    private func formattedAsOf(_ date: Date?) -> String {
        DateFormatting.asOfDisplay(date)
    }

    private func formattedQuantity(_ quantity: Double, currency: String) -> String {
        let formatted = Self.quantityFormatter.string(from: NSNumber(value: quantity)) ?? String(format: "%.2f", quantity)
        return currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? formatted : "\(formatted) \(currency)"
    }

    private func portfolioAllocationDetail(for membership: PortfolioMembershipRow) -> String? {
        var parts: [String] = []
        if let research = membership.researchTargetPct {
            parts.append(String(format: "Research %.1f%%", research))
        }
        if let user = membership.userTargetPct {
            parts.append(String(format: "User %.1f%%", user))
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  •  ")
    }

    private func loadLatestPrice() {
        if let lp = dbManager.getLatestPrice(instrumentId: instrumentId) {
            latestPrice = lp.price
            if let d = iso8601Formatter().date(from: lp.asOf) { latestPriceAsOf = d }
        } else {
            latestPrice = nil
            latestPriceAsOf = nil
        }
    }

    private func saveInstrumentPrice() {
        guard let p = Double(priceInput) else { return }
        let asOfIso = iso8601Formatter().string(from: priceAsOf)
        let ok = dbManager.upsertPrice(instrumentId: instrumentId, price: p, currency: currency, asOf: asOfIso, source: "manual")
        if ok {
            let displayAsOf = DateFormatting.asOfDisplay(priceAsOf)
            priceMessage = "Saved \(p) \(currency) @ \(displayAsOf)"
            loadLatestPrice()
        } else {
            priceMessage = "Failed to save price"
        }
    }

    private var updatesInThemesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Instrument Notes/Updates", icon: "doc.text", color: .blue)
                Spacer()
                Button("Open Notes") { openInstrumentNotes() }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Open Instrument Notes for \(instrumentName)")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func openInstrumentNotes() {
        let last = UserDefaults.standard.string(forKey: "instrumentNotesLastTab")
        switch last {
        case "general": notesInitialTab = .general
        case "mentions": notesInitialTab = .mentions
        default: notesInitialTab = .updates
        }
        showNotes = true
        let payload: [String: Any] = ["instrumentId": instrumentId, "action": "instrument_notes_open", "source": "panel"]
        if let data = try? JSONSerialization.data(withJSONObject: payload), let log = String(data: data, encoding: .utf8) {
            LoggingService.shared.log(log, logger: .ui)
        }
    }
    
    // MARK: - Edit Glassmorphism Background
    // MARK: - Modern Footer
    private var modernFooter: some View {
        Spacer(minLength: 0)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            trailing()
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
        compactTextField(
            title: title,
            text: text,
            placeholder: placeholder,
            isRequired: isRequired,
            autoUppercase: autoUppercase,
            validation: validation,
            errorMessage: errorMessage,
            leadingIcon: icon
        )
    }

    private func compactTextField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        isRequired: Bool,
        autoUppercase: Bool = false,
        validation: Bool = true,
        errorMessage: String = "",
        leadingIcon: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = leadingIcon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Text(title + (isRequired ? "*" : ""))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if !text.wrappedValue.isEmpty && !validation {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            !text.wrappedValue.isEmpty && !validation ?
                                Color.red.opacity(0.6) : Color.gray.opacity(0.25),
                            lineWidth: 1
                        )
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase {
                        text.wrappedValue = newValue.uppercased()
                    }
                }
            if !text.wrappedValue.isEmpty && !validation && !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }
        
    private func modernCurrencyField() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text("Currency")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
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
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if !currency.isEmpty && !isValidCurrency {
                Text("Please select a currency from the dropdown")
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.8))
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
        let groups = AssetSubClassPickerModel.sort(dbManager.fetchAssetTypes())
        instrumentGroups = groups
    }

    func loadAvailableCurrencies() {
        availableCurrencies = dbManager.fetchActiveCurrencies()
    }

    private func refreshInstrumentUsage() {
        portfolioMemberships = dbManager.listPortfolioMembershipsForInstrument(id: instrumentId)
        instrumentPositions = dbManager.listPositionsForInstrument(id: instrumentId)
        portfoliosCount = portfolioMemberships.count
        positionsCount = instrumentPositions.count
    }

    func loadInstrumentData() {
        if let details = dbManager.fetchInstrumentDetails(id: instrumentId) {
            instrumentName = details.name
            selectedGroupId = details.subClassId
            currency = details.currency
            valorNr = details.valorNr ?? ""
            tickerSymbol = details.tickerSymbol ?? ""
            isin = details.isin ?? ""
            sector = details.sector ?? ""
            isActiveFlag = details.isActive
            isDeletedFlag = details.isDeleted
            
            // Store original values for change detection
            originalName = instrumentName
            originalGroupId = selectedGroupId
            originalCurrency = currency
            originalValorNr = valorNr
            originalTickerSymbol = tickerSymbol
            originalIsin = isin
            originalSector = sector
        }
        refreshInstrumentUsage()
    }

    @ViewBuilder
    private var portfolioMembershipsView: some View {
        if portfolioMemberships.isEmpty {
            Text("Not part of any investment portfolios")
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Investment Portfolios")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(portfolioMemberships) { membership in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(membership.name)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                                .underline()
                                .onTapGesture(count: 2) { openThemeId = membership.id }
                                .help("Double-click to open \(membership.name)")
                            if let status = membership.status, !status.isEmpty {
                                Text(status)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if membership.isArchived {
                                Text("Archived")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            if membership.isSoftDeleted {
                                Text("Hidden")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }
                        if let detail = portfolioAllocationDetail(for: membership) {
                            Text(detail)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    if membership.id != portfolioMemberships.last?.id {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var positionsView: some View {
        if instrumentPositions.isEmpty {
            Text("No current positions recorded")
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Positions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(instrumentPositions) { position in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(position.accountName)
                                .font(.subheadline)
                            Text(position.institutionName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formattedQuantity(position.quantity, currency: position.instrumentCurrency))
                                .font(.caption)
                                .monospacedDigit()
                            Text(DateFormatter.swissDate.string(from: position.reportDate))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editingPosition = position }
                    .help("Double-click to edit position for \(position.accountName)")
                    if position.id != instrumentPositions.last?.id {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
    }

    // MARK: - Lifecycle Section (Soft Delete / Restore)
    private var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Status & Lifecycle", icon: "archivebox", color: .purple) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.leading, 2)
                    .onHover { showLifecycleInfo = $0 }
                    .popover(isPresented: $showLifecycleInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Soft delete will hide this instrument from search and stop price updates. Requirements: no positions and not part of any portfolios.")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 4)
                            if positionsCount > 0 || portfoliosCount > 0 {
                                Text("Cannot soft delete: remove all positions and portfolio memberships first.")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            if isDeletedFlag {
                                Text("This instrument is soft-deleted. It is hidden in selectors and does not receive price updates.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .frame(minWidth: 320)
                        .onHover { showLifecycleInfo = $0 }
                    }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    statusBadge(title: isDeletedFlag ? "Soft-deleted" : (isActiveFlag ? "Tracked" : "Disabled"), color: isDeletedFlag ? .red : (isActiveFlag ? .green : .gray))
                    statusBadge(title: positionsCount > 0 ? "Investment: Active" : "Investment: Inactive", color: positionsCount > 0 ? .blue : .orange)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Portfolio memberships: \(portfoliosCount)  •  Current positions: \(positionsCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    portfolioMembershipsView
                    positionsView
                }
                Divider()
                if !isDeletedFlag {
                    HStack(spacing: 8) {
                        TextField("Reason (optional)", text: $deleteReason)
                            .textFieldStyle(.roundedBorder)
                        TextField("Note (optional)", text: $deleteNote)
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) { performSoftDelete() } label: {
                            Label("Soft Delete Instrument", systemImage: "trash")
                        }
                        .disabled(positionsCount > 0 || portfoliosCount > 0)
                    }
                    if positionsCount > 0 || portfoliosCount > 0 {
                        Text("Cannot soft delete: remove all positions and portfolio memberships first.")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                } else {
                    Text("This instrument is soft-deleted. It is hidden in selectors and does not receive price updates.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button { performRestore() } label: {
                        Label("Restore Instrument", systemImage: "arrow.uturn.left")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func statusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func performSoftDelete() {
        if dbManager.softDeleteInstrument(id: instrumentId,
                                          reason: deleteReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : deleteReason,
                                          note: deleteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : deleteNote) {
            alertMessage = "✅ Instrument soft-deleted. It will be hidden in search and stop price updates."
            showingAlert = true
            isDeletedFlag = true
            isActiveFlag = false
        } else {
            alertMessage = "❌ Unable to soft delete. Ensure it has no positions and is not part of any portfolio."
            showingAlert = true
        }
    }

    private func performRestore() {
        if dbManager.restoreInstrument(id: instrumentId) {
            alertMessage = "✅ Instrument restored. It is visible again and eligible for price updates."
            showingAlert = true
            isDeletedFlag = false
            isActiveFlag = true
        } else {
            alertMessage = "❌ Failed to restore instrument."
            showingAlert = true
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

    private struct Ident: Identifiable {
        let value: Int
        var id: Int { value }
    }

// MARK: - History
// Version 1.1 - Fixed onChange deprecation warnings for macOS 14.0+
// - Updated all .onChange(of:) { _ in } to .onChange(of:) { oldValue, newValue in }
// - Updated .onChange(of:) { newValue in } to .onChange(of:) { oldValue, newValue in }
// - Maintained all existing functionality including change detection and validation
