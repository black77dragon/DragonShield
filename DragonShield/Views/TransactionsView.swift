import SwiftUI

// MARK: - Version 1.1 (Design System)

// MARK: - History: Initial placeholder - transactions management (coming soon)

struct TransactionsView: View {
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    var body: some View {
        ZStack {
            // Premium background
            DSColor.background
                .ignoresSafeArea()

            // Subtle animated background elements
            TransactionsParticleBackground()

            VStack(spacing: 0) {
                modernHeader
                comingSoonContent
            }
        }
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Modern Header

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSLayout.spaceXS) {
                HStack(spacing: DSLayout.spaceM) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 32))
                        .foregroundColor(DSColor.accentMain)

                    Text("Transactions")
                        .dsHeaderLarge()
                        .foregroundColor(DSColor.textPrimary)
                }

                Text("Manage your financial transactions and activities")
                    .dsBody()
                    .foregroundColor(DSColor.textSecondary)
            }

            Spacer()

            // Status indicator
            DSBadge(text: "Coming Soon", color: DSColor.accentWarning)
        }
        .padding(.horizontal, DSLayout.spaceL)
        .padding(.vertical, DSLayout.spaceL)
        .opacity(headerOpacity)
    }

    // MARK: - Coming Soon Content

    private var comingSoonContent: some View {
        VStack(spacing: DSLayout.spaceXL) {
            Spacer()

            // Icon
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DSColor.accentMain.opacity(0.7), DSColor.accentMain.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Content
            VStack(spacing: DSLayout.spaceM) {
                Text("Transactions Management")
                    .dsHeaderMedium()
                    .foregroundColor(DSColor.textPrimary)

                Text("Comprehensive transaction tracking is coming soon!")
                    .dsHeaderSmall()
                    .foregroundColor(DSColor.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: DSLayout.spaceM) {
                    featureItem(icon: "plus.circle", text: "Add and categorize transactions", color: DSColor.accentMain)
                    featureItem(icon: "magnifyingglass", text: "Search and filter transaction history", color: DSColor.accentMain)
                    featureItem(icon: "chart.line.uptrend.xyaxis", text: "Track portfolio performance over time", color: DSColor.accentSuccess)
                    featureItem(icon: "doc.text", text: "Import from bank statements", color: DSColor.accentWarning)
                    featureItem(icon: "calendar", text: "View transactions by date ranges", color: DSColor.accentError)
                }
                .padding(.top, DSLayout.spaceL)
            }

            Spacer()

            // Progress indicator
            VStack(spacing: DSLayout.spaceS) {
                Text("Development Progress")
                    .dsCaption()
                    .foregroundColor(DSColor.textTertiary)

                ProgressView(value: 0.25)
                    .progressViewStyle(LinearProgressViewStyle(tint: DSColor.accentSuccess))
                    .frame(width: 200)

                Text("25% Complete")
                    .dsMonoSmall()
                    .foregroundColor(DSColor.textTertiary)
            }
            .padding(.bottom, DSLayout.spaceXL)
        }
        .padding(.horizontal, DSLayout.spaceXL)
        .offset(y: contentOffset)
    }

    // MARK: - Feature Item

    private func featureItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DSLayout.spaceM) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .dsBody()
                .foregroundColor(DSColor.textSecondary)

            Spacer()
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            headerOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            contentOffset = 0
        }
    }
}

// MARK: - Background Particles

struct TransactionsParticleBackground: View {
    @State private var particles: [TransactionsParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(DSColor.accentMain.opacity(0.03))
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
        particles = (0 ..< 18).map { _ in
            TransactionsParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0 ... 1200),
                    y: CGFloat.random(in: 0 ... 800)
                ),
                size: CGFloat.random(in: 2 ... 8),
                opacity: Double.random(in: 0.1 ... 0.2)
            )
        }
    }

    private func animateParticles() {
        withAnimation(.linear(duration: 32).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05 ... 0.15)
            }
        }
    }
}

struct TransactionsParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

// MARK: - Preview

struct TransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsView()
    }
}
