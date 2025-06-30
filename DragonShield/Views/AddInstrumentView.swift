import SwiftUI

struct AddInstrumentView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var instrumentName = ""
    @State private var selectedGroupId = 1
    @State private var currency = "CHF"
    @State private var tickerSymbol = ""
    @State private var isin = ""
    @State private var sector = ""
    @State private var instrumentGroups: [(id: Int, name: String)] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50
    @State private var currentStep = 1
    
    // Currency picker options
    private let commonCurrencies = ["CHF", "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CNY", "INR"]
    
    // MARK: - Validation
    var isValid: Bool {
        let nameValid = !instrumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currencyValid = !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currencyFormatValid = isValidCurrency
        let isinFormatValid = isValidISIN
        
        return nameValid && currencyValid && currencyFormatValid && isinFormatValid
    }
    
    private var isValidCurrency: Bool {
        let trimmed = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 3 && trimmed.allSatisfy { $0.isLetter }
    }
    
    private var isValidISIN: Bool {
        let trimmed = isin.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return trimmed.count == 12 && trimmed.prefix(2).allSatisfy { $0.isLetter }
    }
    
    // MARK: - Computed Properties
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 6.0
        
        if !instrumentName.isEmpty { completed += 1 }
        if selectedGroupId > 0 { completed += 1 }
        if !currency.isEmpty { completed += 1 }
        if !tickerSymbol.isEmpty { completed += 1 }
        if !isin.isEmpty { completed += 1 }
        if !sector.isEmpty { completed += 1 }
        
        return completed / total
    }
    
    var body: some View {
        ZStack {
            // Premium light gradient background
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
            LightParticleBackground()
            
            // Main content
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    modernHeader
                    progressBar
                    modernContent
                    modernFooter
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.clear)
            }
        }
        .frame(width: 700, height: 700)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            loadInstrumentGroups()
            animateEntrance()
        }
        .alert("Success", isPresented: $showingAlert) {
            Button("Continue") {
                if alertMessage.contains("✅") {
                    animateExit()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Modern Header
    private var modernHeader: some View {
        HStack {
            // Close button with light styling
            Button {
                animateExit()
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
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Add New Instrument")
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
            
            // Save button with premium light styling
            Button {
                saveInstrument()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                    
                    Text(isLoading ? "Saving..." : "Save")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 32)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if isValid && !isLoading {
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
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
                .shadow(color: isValid ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            }
            .disabled(isLoading)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
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
                    .foregroundColor(.blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                        .shadow(color: .blue.opacity(0.3), radius: 3, x: 0, y: 1)
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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }
    
    // MARK: - Required Section with Light Glassmorphism
    private var requiredSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Required Information", icon: "checkmark.shield.fill", color: .blue)
            
            VStack(spacing: 16) {
                modernTextField(
                    title: "Instrument Name",
                    text: $instrumentName,
                    placeholder: "e.g., Apple Inc.",
                    icon: "building.2.crop.circle.fill",
                    isRequired: true
                )
                
                modernAssetTypePicker()
                
                modernCurrencyField()
            }
        }
        .padding(24)
        .background(lightGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .blue.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Optional Section
    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Optional Information", icon: "info.circle.fill", color: .purple)
            
            VStack(spacing: 16) {
                modernTextField(
                    title: "Ticker Symbol",
                    text: $tickerSymbol,
                    placeholder: "e.g., AAPL",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    isRequired: false,
                    autoUppercase: true
                )
                
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
                
                modernTextField(
                    title: "Sector",
                    text: $sector,
                    placeholder: "e.g., Technology",
                    icon: "briefcase.circle.fill",
                    isRequired: false
                )
            }
        }
        .padding(24)
        .background(lightGlassMorphismBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .purple.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Light Glassmorphism Background
    private var lightGlassMorphismBackground: some View {
        ZStack {
            // Base glass effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .white.opacity(0.6)
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
                            .blue.opacity(0.05),
                            .purple.opacity(0.03),
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
            
            Menu {
                ForEach(instrumentGroups, id: \.id) { group in
                    Button(group.name) {
                        selectedGroupId = group.id
                    }
                }
            } label: {
                HStack {
                    Text(instrumentGroups.first(where: { $0.id == selectedGroupId })?.name ?? "Select Asset SubClass")
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
            
            HStack(spacing: 12) {
                Menu {
                    ForEach(commonCurrencies, id: \.self) { curr in
                        Button(curr) {
                            currency = curr
                        }
                    }
                } label: {
                    HStack {
                        Text(currency.isEmpty ? "Select" : currency)
                            .foregroundColor(.black)
                            .font(.system(size: 14, weight: .medium))
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("or")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextField("Custom", text: $currency)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                !currency.isEmpty && !isValidCurrency ?
                                    .red.opacity(0.6) : Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .onChange(of: currency) { oldValue, newValue in
                        currency = newValue.uppercased()
                    }
            }
            
            if !currency.isEmpty && !isValidCurrency {
                Text("Currency must be 3 letters (e.g., USD, EUR)")
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
        let groups = dbManager.fetchAssetTypes()
        self.instrumentGroups = groups
        if !groups.isEmpty {
            selectedGroupId = groups[0].id
        }
    }
    
    private func resetForm() {
        instrumentName = ""
        currency = "CHF"
        tickerSymbol = ""
        isin = ""
        sector = ""
        if !instrumentGroups.isEmpty {
            selectedGroupId = instrumentGroups[0].id
        }
    }
    
    func saveInstrument() {
        guard isValid else {
            alertMessage = "Please fill in all required fields correctly"
            showingAlert = true
            return
        }
        
        let trimmedName = instrumentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        isLoading = true
        
        let dbManager = DatabaseManager()
        
        let success = dbManager.addInstrument(
            name: trimmedName,
            subClassId: selectedGroupId,
            currency: trimmedCurrency,
            tickerSymbol: tickerSymbol.isEmpty ? nil : tickerSymbol.uppercased(),
            isin: isin.isEmpty ? nil : isin.uppercased(),
            countryCode: nil,
            exchangeCode: nil,
            sector: sector.isEmpty ? nil : sector
        )
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if success {
                self.alertMessage = "✅ Instrument '\(trimmedName)' added successfully!"
                self.resetForm()
                
                // Trigger refresh of portfolio view
                NotificationCenter.default.post(name: NSNotification.Name("RefreshPortfolio"), object: nil)
            } else {
                self.alertMessage = "❌ Failed to add instrument. Please try again."
            }
            self.showingAlert = true
        }
    }
}

// MARK: - Supporting Views

struct LightParticleBackground: View {
    @State private var particles: [LightParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(0.05))
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
        particles = (0..<15).map { _ in
            LightParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...700),
                    y: CGFloat.random(in: 0...700)
                ),
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.1...0.3)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 800
                particles[index].opacity = Double.random(in: 0.05...0.25)
            }
        }
    }
}

struct LightParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}


// MARK: - History
// Version 1.1 - Fixed onChange deprecation warnings for macOS 14.0+
// - Updated .onChange(of:) { newValue in } to .onChange(of:) { oldValue, newValue in }
// - Maintained all existing functionality and styling
