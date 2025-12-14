import SwiftUI

struct InstrumentEditView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var dbManager: DatabaseManager
    let instrumentId: Int

    init(instrumentId: Int, isPresented: Binding<Bool>) {
        self.instrumentId = instrumentId
        self._isPresented = isPresented
    }

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
    @State private var priceAsOf: Date = .init()
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

    // Risk profile
    @State private var riskProfile: DatabaseManager.RiskProfileRow? = nil
    @State private var riskManualOverride: Bool = false
    @State private var riskOverrideSRI: Int = 5
    @State private var riskOverrideLiquidity: Int = 1
    @State private var riskOverrideReason: String = ""
    @State private var riskOverrideExpiryEnabled: Bool = false
    @State private var riskOverrideExpiry: Date = .init()
    @State private var originalRiskManualOverride: Bool = false
    @State private var originalRiskOverrideSRI: Int = 5
    @State private var originalRiskOverrideLiquidity: Int = 1
    @State private var originalRiskOverrideReason: String = ""
    @State private var originalRiskOverrideExpiry: Date? = nil
    @State private var riskStatusMessage: String?
    private let riskColors: [Color] = [
        Color.green.opacity(0.7),
        Color.green,
        Color.yellow,
        Color.orange,
        Color.orange.opacity(0.85),
        Color.red.opacity(0.9),
        Color.red
    ]

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
        let trimmedReason = riskOverrideReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalTrimmedReason = originalRiskOverrideReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentExpiry = riskOverrideExpiryEnabled ? riskOverrideExpiry : nil
        hasChanges = instrumentName != originalName ||
            selectedGroupId != originalGroupId ||
            currency != originalCurrency ||
            tickerSymbol != originalTickerSymbol ||
            isin != originalIsin ||
            valorNr != originalValorNr ||
            sector != originalSector ||
            riskManualOverride != originalRiskManualOverride ||
            riskOverrideSRI != originalRiskOverrideSRI ||
            riskOverrideLiquidity != originalRiskOverrideLiquidity ||
            trimmedReason != originalTrimmedReason ||
            currentExpiry != originalRiskOverrideExpiry
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
        .background(DSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusL))
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
        HStack(spacing: DSLayout.spaceM) {
            // Close button with light styling
            Button {
                if hasChanges {
                    showUnsavedChangesAlert()
                } else {
                    animateExit()
                }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))

            Spacer()

            // Modern title with icon
            HStack(spacing: DSLayout.spaceS) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DSColor.primaryGradient)

                Text("Edit Instrument")
                    .dsHeaderLarge()
                    .foregroundColor(DSColor.textPrimary)
            }

            Spacer()

            // Save button with premium styling
            Button {
                handleSaveAction()
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
                }
            }
            .buttonStyle(DSButtonStyle(type: .primary, size: .small))
            .disabled(isLoading || !isValid)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceM)
        .opacity(headerOpacity)
    }

    // MARK: - Change Indicator

    private var changeIndicator: some View {
        HStack {
            if hasChanges {
                HStack(spacing: DSLayout.spaceS) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(DSColor.accentWarning)

                    Text("Unsaved changes")
                        .dsCaption()
                        .foregroundColor(DSColor.accentWarning)
                }
                .padding(.horizontal, DSLayout.spaceM)
                .padding(.vertical, 4)
                .background(DSColor.accentWarning.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(DSColor.accentWarning.opacity(0.3), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()
        }
        .padding(.horizontal, DSLayout.spaceL)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasChanges)
    }

    // MARK: - Modern Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Completion")
                    .dsCaption()
                    .foregroundColor(DSColor.textSecondary)

                Spacer()

                Text("\(Int(completionPercentage * 100))%")
                    .dsCaption()
                    .foregroundColor(DSColor.accentMain)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DSColor.surfaceSecondary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DSColor.primaryGradient)
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: DSColor.accentMain.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.bottom, DSLayout.spaceM)
    }

    // MARK: - Modern Content

    private var modernContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                requiredSection
                optionalSection
                riskSection
                priceSection
                lifecycleSection
                updatesInThemesSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
        .offset(y: sectionsOffset)
    }

    // MARK: - Required Section

    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            sectionHeader(title: "Required Information", icon: "checkmark.shield.fill", color: DSColor.accentMain)

            VStack(spacing: DSLayout.spaceM) {
                modernTextField(
                    title: "Instrument Name",
                    text: $instrumentName,
                    placeholder: "e.g., Apple Inc.",
                    icon: "building.2.crop.circle.fill",
                    isRequired: true
                )
                .onChange(of: instrumentName) { _, _ in detectChanges() }

                // Asset SubClass and Currency side by side
                HStack(spacing: DSLayout.spaceM) {
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
        .padding(DSLayout.spaceM)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
    }

    // MARK: - Optional Section

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            sectionHeader(title: "Optional Information", icon: "info.circle.fill", color: DSColor.accentWarning)

            Grid(alignment: .leading, horizontalSpacing: DSLayout.spaceM, verticalSpacing: DSLayout.spaceM) {
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
        .padding(DSLayout.spaceM)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
    }

    // MARK: - Risk Section

    private var riskSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            sectionHeader(title: "Risk Management", icon: "shield.checkerboard", color: DSColor.accentMain)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Computed").dsCaption().foregroundColor(DSColor.textSecondary)
                        HStack(spacing: 8) {
                            riskBadge(riskProfile?.computedSRI ?? 0)
                            Text(riskShortDescription(riskProfile?.computedSRI))
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                        }
                        Text(liquidityLabel(riskProfile?.computedLiquidityTier))
                            .dsCaption()
                            .foregroundColor(DSColor.textSecondary)
                    }
                    Divider().overlay(DSColor.border)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Manual override", isOn: $riskManualOverride)
                            .toggleStyle(.switch)
                            .onChange(of: riskManualOverride) { _, _ in
                                riskStatusMessage = nil
                                detectChanges()
                            }
                        if riskManualOverride {
                            Stepper("Override SRI: \(riskOverrideSRI)", value: $riskOverrideSRI, in: 1 ... 7)
                                .onChange(of: riskOverrideSRI) { _, _ in detectChanges() }
                            HStack(spacing: 8) {
                                riskBadge(riskOverrideSRI)
                                Text(riskShortDescription(riskOverrideSRI))
                                    .dsCaption()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                            Picker("Override Liquidity", selection: $riskOverrideLiquidity) {
                                Text("Liquid").tag(0)
                                Text("Restricted").tag(1)
                                Text("Illiquid").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: riskOverrideLiquidity) { _, _ in detectChanges() }
                            TextField("Reason (optional)", text: $riskOverrideReason)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: riskOverrideReason) { _, _ in detectChanges() }
                            Toggle("Set expiry", isOn: $riskOverrideExpiryEnabled)
                                .onChange(of: riskOverrideExpiryEnabled) { _, _ in detectChanges() }
                            if riskOverrideExpiryEnabled {
                                DatePicker("Override expires", selection: $riskOverrideExpiry, displayedComponents: .date)
                                    .onChange(of: riskOverrideExpiry) { _, _ in detectChanges() }
                            }
                        } else {
                            Text("Using computed values from mapping \(riskProfile?.mappingVersion ?? "—")")
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button("Save Risk") { saveRiskProfile() }
                        .buttonStyle(DSButtonStyle(type: .primary, size: .small))
                    Button("Recalculate") { recalcRiskProfile() }
                        .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    if let status = riskStatusMessage {
                        Text(status)
                            .dsCaption()
                            .foregroundColor(DSColor.textSecondary)
                    }
                }
            }
        }
        .padding(DSLayout.spaceM)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
    }

    // MARK: - Price Section

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            sectionHeader(title: "Instrument Price", icon: "dollarsign.circle.fill", color: DSColor.accentSuccess)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: DSLayout.spaceM) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Price").dsCaption().foregroundColor(DSColor.textSecondary)
                        Text(formattedLatestPrice())
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("As Of").dsCaption().foregroundColor(DSColor.textSecondary)
                        Text(formattedAsOf(latestPriceAsOf))
                            .dsBody()
                            .foregroundColor(DSColor.textPrimary)
                    }
                    Spacer()
                }
                Divider().overlay(DSColor.border)
                HStack(spacing: DSLayout.spaceM) {
                    VStack(alignment: .leading) {
                        Text("Set Price (\(currency))").dsCaption().foregroundColor(DSColor.textSecondary)
                        TextField("e.g., 123.45", text: $priceInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                    VStack(alignment: .leading) {
                        Text("As Of").dsCaption().foregroundColor(DSColor.textSecondary)
                        DatePicker("", selection: $priceAsOf, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    VStack { Spacer(minLength: 0)
                        Button("Save Price") { saveInstrumentPrice() }
                            .buttonStyle(DSButtonStyle(type: .primary, size: .small))
                            .disabled(Double(priceInput) == nil)
                    }
                    VStack { Spacer(minLength: 0)
                        Button("Refresh") { loadLatestPrice() }
                            .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    }
                }
                if let msg = priceMessage {
                    Text(msg).dsCaption().foregroundColor(DSColor.textSecondary)
                }
            }
        }
        .padding(DSLayout.spaceM)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
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
                sectionHeader(title: "Instrument Notes/Updates", icon: "doc.text", color: DSColor.accentMain)
                Spacer()
                Button("Open Notes") { openInstrumentNotes() }
                    .buttonStyle(DSButtonStyle(type: .secondary, size: .small))
                    .accessibilityLabel("Open Instrument Notes for \(instrumentName)")
            }
        }
        .padding(DSLayout.spaceM)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
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
        HStack(spacing: DSLayout.spaceS) {
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
                .dsHeaderSmall()
                .foregroundColor(DSColor.textPrimary)
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
                        .foregroundColor(DSColor.textSecondary)
                }
                Text(title + (isRequired ? "*" : ""))
                    .dsCaption()
                    .foregroundColor(DSColor.textPrimary)
                Spacer()
                if !text.wrappedValue.isEmpty && !validation {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DSColor.accentError)
                }
            }
            TextField(placeholder, text: text)
                .dsBody()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(
                            !text.wrappedValue.isEmpty && !validation ?
                                DSColor.accentError.opacity(0.6) : DSColor.border,
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
                    .foregroundColor(DSColor.accentError.opacity(0.8))
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
                            Text(curr.name)
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
                                .foregroundColor(DSColor.textPrimary)
                                .dsBody()
                            Text(selectedCurrency.symbol)
                                .foregroundColor(DSColor.textSecondary)
                                .dsBody()
                        }
                    } else {
                        Text(currency.isEmpty ? "Select Currency" : currency)
                            .foregroundColor(DSColor.textPrimary)
                            .dsBody()
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DSColor.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.radiusS))
                .overlay(
                    RoundedRectangle(cornerRadius: DSLayout.radiusS)
                        .stroke(DSColor.border, lineWidth: 1)
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

    @Environment(\.dismiss) private var dismiss

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
        print("🚪 [InstrumentEditView] animateExit called")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            formScale = 0.9
            headerOpacity = 0
            sectionsOffset = 50
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("🚪 [InstrumentEditView] executing dismissal (isPresented = false, dismiss())")
            isPresented = false
            dismiss()
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
            detectChanges()
        }
        refreshInstrumentUsage()
        loadRiskProfile()
    }

    private func storeRiskBaseline() {
        originalRiskManualOverride = riskManualOverride
        originalRiskOverrideSRI = riskOverrideSRI
        originalRiskOverrideLiquidity = riskOverrideLiquidity
        originalRiskOverrideReason = riskOverrideReason.trimmingCharacters(in: .whitespacesAndNewlines)
        originalRiskOverrideExpiry = riskOverrideExpiryEnabled ? riskOverrideExpiry : nil
    }

    private func loadRiskProfile() {
        if let profile = dbManager.fetchRiskProfile(instrumentId: instrumentId) {
            riskProfile = profile
        } else {
            _ = dbManager.recalcRiskProfileForInstrument(instrumentId: instrumentId)
            riskProfile = dbManager.fetchRiskProfile(instrumentId: instrumentId)
        }
        if let profile = riskProfile {
            riskManualOverride = profile.manualOverride
            riskOverrideSRI = profile.overrideSRI ?? profile.computedSRI
            riskOverrideLiquidity = profile.overrideLiquidityTier ?? profile.computedLiquidityTier
            riskOverrideReason = profile.overrideReason ?? ""
            if let exp = profile.overrideExpiresAt {
                riskOverrideExpiryEnabled = true
                riskOverrideExpiry = exp
            } else {
                riskOverrideExpiryEnabled = false
            }
        }
        storeRiskBaseline()
        detectChanges()
    }

    private func saveRiskProfile() {
        let reason = riskManualOverride ? riskOverrideReason.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let expiry = (riskManualOverride && riskOverrideExpiryEnabled) ? riskOverrideExpiry : nil
        let ok = dbManager.updateRiskProfileOverride(
            instrumentId: instrumentId,
            subClassId: selectedGroupId,
            manualOverride: riskManualOverride,
            overrideSRI: riskManualOverride ? riskOverrideSRI : nil,
            overrideLiquidityTier: riskManualOverride ? riskOverrideLiquidity : nil,
            overrideReason: reason,
            overrideBy: NSFullUserName(),
            overrideExpiresAt: expiry
        )
        riskStatusMessage = ok ? "Saved" : "Save failed"
        loadRiskProfile()
    }

    private func recalcRiskProfile() {
        riskManualOverride = false
        riskOverrideReason = ""
        riskOverrideExpiryEnabled = false
        let ok = dbManager.updateRiskProfileOverride(
            instrumentId: instrumentId,
            subClassId: selectedGroupId,
            manualOverride: false,
            overrideSRI: nil,
            overrideLiquidityTier: nil,
            overrideReason: nil,
            overrideBy: NSFullUserName(),
            overrideExpiresAt: nil
        )
        riskStatusMessage = ok ? "Recalculated" : "Recalc failed"
        loadRiskProfile()
    }

    private func riskDisplay(_ value: Int?, prefix: String) -> String {
        guard let v = value else { return "—" }
        return "\(prefix) \(v)"
    }

    private func liquidityLabel(_ tier: Int?) -> String {
        switch tier {
        case 0: return "Liquid"
        case 1: return "Restricted"
        case 2: return "Illiquid"
        default: return "Unknown"
        }
    }

    private func riskShortDescription(_ value: Int?) -> String {
        switch value {
        case 1: return "Very low risk: cash-like."
        case 2: return "Low risk: short-duration IG."
        case 3: return "Low–medium risk: IG credit/balanced."
        case 4: return "Medium risk: diversified equity."
        case 5: return "Medium–high risk: concentrated/EM/commods."
        case 6: return "High risk: leverage/complex/volatile."
        case 7: return "Very high risk: speculative/extreme."
        default: return "Risk category"
        }
    }

    @ViewBuilder
    private func riskBadge(_ value: Int) -> some View {
        if value >= 1 && value <= 7 {
            Text("SRI \(value)")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(riskColors[value - 1])
                .foregroundColor(.white)
                .clipShape(Capsule())
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var portfolioMembershipsView: some View {
        if portfolioMemberships.isEmpty {
            Text("Not part of any investment portfolios")
                .dsCaption()
                .foregroundColor(DSColor.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Investment Portfolios")
                    .dsCaption()
                    .foregroundColor(DSColor.textSecondary)
                ForEach(portfolioMemberships) { membership in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(membership.name)
                                .dsBody()
                                .foregroundColor(DSColor.accentMain)
                                .underline()
                                .onTapGesture(count: 2) { openThemeId = membership.id }
                                .help("Double-click to open \(membership.name)")
                            if let status = membership.status, !status.isEmpty {
                                Text(status)
                                    .dsCaption()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                            if membership.isArchived {
                                Text("Archived")
                                    .dsCaption()
                                    .fontWeight(.semibold)
                                    .foregroundColor(DSColor.accentWarning)
                            }
                            if membership.isSoftDeleted {
                                Text("Hidden")
                                    .dsCaption()
                                    .fontWeight(.semibold)
                                    .foregroundColor(DSColor.accentError)
                            }
                        }
                        if let detail = portfolioAllocationDetail(for: membership) {
                            Text(detail)
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                    if membership.id != portfolioMemberships.last?.id {
                        Divider().overlay(DSColor.border).opacity(0.5)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var positionsView: some View {
        if instrumentPositions.isEmpty {
            Text("No current positions recorded")
                .dsCaption()
                .foregroundColor(DSColor.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Positions")
                    .dsCaption()
                    .foregroundColor(DSColor.textSecondary)
                ForEach(instrumentPositions) { position in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(position.accountName)
                                .dsBody()
                                .foregroundColor(DSColor.textPrimary)
                            Text(position.institutionName)
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formattedQuantity(position.quantity, currency: position.instrumentCurrency))
                                .dsCaption()
                                .monospacedDigit()
                                .foregroundColor(DSColor.textPrimary)
                            Text(DateFormatter.swissDate.string(from: position.reportDate))
                                .dsCaption()
                                .foregroundColor(DSColor.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editingPosition = position }
                    .help("Double-click to edit position for \(position.accountName)")
                    if position.id != instrumentPositions.last?.id {
                        Divider().overlay(DSColor.border).opacity(0.5)
                    }
                }
            }
        }
    }

    // MARK: - Lifecycle Section (Soft Delete / Restore)

    private var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            sectionHeader(title: "Status & Lifecycle", icon: "archivebox", color: .purple) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DSColor.textSecondary)
                    .padding(.leading, 2)
                    .onHover { showLifecycleInfo = $0 }
                    .popover(isPresented: $showLifecycleInfo, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Soft delete will hide this instrument from search and stop price updates. Requirements: no positions and not part of any portfolios.")
                                .dsCaption()
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 4)
                            if positionsCount > 0 || portfoliosCount > 0 {
                                Text("Cannot soft delete: remove all positions and portfolio memberships first.")
                                    .dsCaption()
                                    .foregroundColor(DSColor.accentError)
                            }
                            if isDeletedFlag {
                                Text("This instrument is soft-deleted. It is hidden in selectors and does not receive price updates.")
                                    .dsCaption()
                                    .foregroundColor(DSColor.textSecondary)
                            }
                        }
                        .padding(DSLayout.spaceM)
                        .frame(minWidth: 320)
                        .onHover { showLifecycleInfo = $0 }
                    }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    statusBadge(title: isDeletedFlag ? "Soft-deleted" : (isActiveFlag ? "Tracked" : "Disabled"), color: isDeletedFlag ? DSColor.accentError : (isActiveFlag ? DSColor.accentSuccess : DSColor.textSecondary))
                    statusBadge(title: positionsCount > 0 ? "Investment: Active" : "Investment: Inactive", color: positionsCount > 0 ? DSColor.accentMain : DSColor.accentWarning)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Portfolio memberships: \(portfoliosCount)  •  Current positions: \(positionsCount)")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                    portfolioMembershipsView
                    positionsView
                }
                Divider().overlay(DSColor.border)
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
                            .dsCaption()
                            .foregroundColor(DSColor.accentError)
                    }
                } else {
                    Text("This instrument is soft-deleted. It is hidden in selectors and does not receive price updates.")
                        .dsCaption()
                        .foregroundColor(DSColor.textSecondary)
                    Button { performRestore() } label: {
                        Label("Restore Instrument", systemImage: "arrow.uturn.left")
                    }
                    .buttonStyle(DSButtonStyle(type: .primary))
                }
            }
        }
        .padding(DSLayout.spaceM)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSLayout.radiusM))
    }

    private func statusBadge(title: String, color: Color) -> some View {
        Text(title)
            .dsCaption()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func performSoftDelete() {
        if dbManager.softDeleteInstrument(id: instrumentId,
                                          reason: deleteReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : deleteReason,
                                          note: deleteNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : deleteNote)
        {
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

    private func handleSaveAction() {
        if isLoading { return }
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }

        if hasChanges {
            saveInstrument()
        } else {
            animateExit()
        }
    }

    func saveInstrument() {
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }

        print("📝 [InstrumentEditView] Starting save for id: \(instrumentId)")
        isLoading = true

        // Capture values to pass to background thread
        let id = instrumentId
        let name = instrumentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let grpId = selectedGroupId
        let curr = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let val = valorNr.isEmpty ? nil : valorNr
        let tick = tickerSymbol.isEmpty ? nil : tickerSymbol.uppercased()
        let i = isin.isEmpty ? nil : isin.uppercased()
        let sec = sector.isEmpty ? nil : sector
        let riskManual = riskManualOverride
        let riskSRI = riskOverrideSRI
        let riskLiquidity = riskOverrideLiquidity
        let riskReason = riskOverrideReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let riskExpiry = (riskManualOverride && riskOverrideExpiryEnabled) ? riskOverrideExpiry : nil
        let riskBy = NSFullUserName()

        DispatchQueue.global(qos: .userInitiated).async {
            print("📝 [InstrumentEditView] executing updateInstrument in background...")
            let success = self.dbManager.updateInstrument(
                id: id,
                name: name,
                subClassId: grpId,
                currency: curr,
                valorNr: val,
                tickerSymbol: tick,
                isin: i,
                sector: sec
            )
            print("📝 [InstrumentEditView] updateInstrument result: \(success)")

            var riskSaved = true
            if success {
                riskSaved = self.dbManager.updateRiskProfileOverride(
                    instrumentId: id,
                    subClassId: grpId,
                    manualOverride: riskManual,
                    overrideSRI: riskManual ? riskSRI : nil,
                    overrideLiquidityTier: riskManual ? riskLiquidity : nil,
                    overrideReason: riskManual ? riskReason : nil,
                    overrideBy: riskBy,
                    overrideExpiresAt: riskExpiry
                )
            }

            DispatchQueue.main.async {
                self.isLoading = false

                if success && riskSaved {
                    print("✅ [InstrumentEditView] Save successful. Updating state and dismissing.")
                    // Update original values to reflect saved state
                    self.originalName = self.instrumentName
                    self.originalGroupId = self.selectedGroupId
                    self.originalCurrency = self.currency
                    self.originalTickerSymbol = self.tickerSymbol
                    self.originalIsin = self.isin
                    self.originalSector = self.sector
                    self.storeRiskBaseline()
                    self.detectChanges()

                    NotificationCenter.default.post(name: NSNotification.Name("RefreshPortfolio"), object: nil)

                    // Auto-dismiss after successful save without showing alert
                    // Use a slightly longer delay to ensure the user sees the checkmark state if desired,
                    // but here we just want it to work.
                    self.animateExit()
                } else {
                    print("❌ [InstrumentEditView] Save failed.")
                    if !success {
                        self.alertMessage = "❌ Failed to update instrument. Please try again."
                    } else {
                        self.alertMessage = "❌ Instrument saved but risk override failed. Please retry."
                    }
                    self.showingAlert = true
                }
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
