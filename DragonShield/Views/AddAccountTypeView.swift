// DragonShield/Views/AddAccountTypeView.swift

// MARK: - Version 1.1

// MARK: - History

// - 1.0 -> 1.1: Corrected particle background struct name and fixed scope issue.
// - Initial creation: View for adding new account types.

import SwiftUI

// Define the particle struct for AddAccountTypeView if it's specific or move to a shared file
struct AddViewParticle: Identifiable { // Renamed to avoid conflict and be more generic for an "Add" view
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct AddAccountTypeView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var dbManager: DatabaseManager

    @State private var typeName: String = ""
    @State private var typeCode: String = ""
    @State private var typeDescription: String = ""
    @State private var isActive: Bool = true

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    // Animation states
    @State private var formScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var sectionsOffset: CGFloat = 50

    var isValid: Bool {
        !typeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !typeCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.95, green: 0.97, blue: 0.99)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            AddAccountTypeParticleBackground()

            VStack(spacing: 0) {
                addModernHeader
                addModernContent
            }
        }
        .frame(width: 600, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(formScale)
        .onAppear {
            animateAddEntrance()
        }
        .alert("Result", isPresented: $showingAlert) {
            Button("OK") {
                if alertMessage.contains("✅") {
                    animateAddExit()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var addModernHeader: some View {
        HStack {
            Button { animateAddExit() } label: {
                Image(systemName: "xmark")
                    .modifier(ModernSubtleButton())
            }
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "creditcard.circle.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(.indigo)
                Text("Add Account Type")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom))
            }
            Spacer()
            Button { saveAccountType() } label: {
                HStack(spacing: 8) {
                    if isLoading { ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8) }
                    else { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }
                    Text(isLoading ? "Saving..." : "Save")
                        .font(.system(size: 14, weight: .semibold))
                }
                .modifier(ModernPrimaryButton(color: .indigo, isDisabled: isLoading || !isValid))
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 20).opacity(headerOpacity)
    }

    private var addModernContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                addFormSection
            }
            .padding(.horizontal, 24).padding(.bottom, 100)
        }
        .offset(y: sectionsOffset)
    }

    private var addFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Type Details", icon: "doc.text.image.fill", color: .indigo)

            VStack(spacing: 16) {
                modernTextField(title: "Type Name*", text: $typeName, placeholder: "e.g., Account", icon: "textformat.abc", isRequired: true)
                modernTextField(title: "Type Code*", text: $typeCode, placeholder: "e.g., CUSTODY (all caps, no spaces)", icon: "number.square", isRequired: true, autoUppercase: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft").foregroundColor(.gray)
                        Text("Description").font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
                    }
                    TextEditor(text: $typeDescription)
                        .frame(minHeight: 60, maxHeight: 100)
                        .font(.system(size: 16))
                        .padding(10)
                        .background(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }

                Toggle("Active", isOn: $isActive)
                    .modifier(ModernToggleStyle(tint: .indigo))
            }
        }
        .modifier(ModernFormSection(color: .indigo))
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20))
                .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.8))
            Spacer()
        }
    }

    private func modernTextField(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool, autoUppercase: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(.gray)
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.7))
                Spacer()
                if isRequired && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && showingAlert && !isValid {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundColor(.red)
                }
            }
            TextField(placeholder, text: text)
                .font(.system(size: 16)).foregroundColor(.black)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                    (isRequired && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && showingAlert && !isValid) ? Color.red.opacity(0.6) : Color.gray.opacity(0.3),
                    lineWidth: 1
                ))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if autoUppercase { text.wrappedValue = newValue.uppercased().filter { !$0.isWhitespace } }
                }
            if isRequired && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && showingAlert && !isValid {
                Text("\(title.replacingOccurrences(of: "*", with: "")) is required.").font(.caption).foregroundColor(.red.opacity(0.8)).padding(.horizontal, 4)
            }
        }
    }

    private func animateAddEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { formScale = 1.0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { sectionsOffset = 0 }
    }

    private func animateAddExit() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { formScale = 0.9; headerOpacity = 0; sectionsOffset = 50 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { presentationMode.wrappedValue.dismiss() }
    }

    func saveAccountType() {
        let finalCode = typeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let finalName = typeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = typeDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if finalName.isEmpty || finalCode.isEmpty {
            alertMessage = "Type Name and Type Code are required."
            showingAlert = true
            return
        }
        if finalCode.contains(" ") {
            alertMessage = "Type Code cannot contain spaces."
            showingAlert = true
            return
        }

        isLoading = true
        let success = dbManager.addAccountType(
            code: finalCode,
            name: finalName,
            description: finalDescription.isEmpty ? nil : finalDescription,
            isActive: isActive
        )

        DispatchQueue.main.async {
            self.isLoading = false
            if success {
                self.alertMessage = "✅ Account Type '\(finalName)' added successfully!"
                NotificationCenter.default.post(name: NSNotification.Name("RefreshAccountTypes"), object: nil)
            } else {
                self.alertMessage = "❌ Failed to add account type. Code might already exist or another error occurred."
            }
            self.showingAlert = true
        }
    }
}

// MARK: - Particle Background for Add View

struct AddAccountTypeParticleBackground: View {
    @State private var particles: [AddViewParticle] = [] // MODIFIED: Use the locally defined AddViewParticle

    var body: some View {
        ZStack {
            ForEach(particles) { particle in // Loop directly over identifiable particles
                Circle().fill(Color.indigo.opacity(0.04))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onAppear { createParticles(); animateParticles() }
    }

    private func createParticles() {
        particles = (0 ..< 12).map { _ in
            AddViewParticle( // MODIFIED
                position: CGPoint(x: CGFloat.random(in: 0 ... 600), y: CGFloat.random(in: 0 ... 550)),
                size: CGFloat.random(in: 3 ... 9),
                opacity: Double.random(in: 0.1 ... 0.2)
            )
        }
    }

    private func animateParticles() {
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 700
                particles[index].opacity = Double.random(in: 0.05 ... 0.15)
            }
        }
    }
}
