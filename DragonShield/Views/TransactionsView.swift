import SwiftUI

// MARK: - Version 1.0

// MARK: - History: Initial placeholder - transactions management (coming soon)

struct TransactionsView: View {
    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.93, green: 0.95, blue: 0.98),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.system(size: 32))
                        .foregroundColor(.green)

                    Text("Transactions")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Manage your financial transactions and activities")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.fill")
                    .foregroundColor(.orange)
                Text("Coming Soon")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }

    // MARK: - Coming Soon Content

    private var comingSoonContent: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.7), .green.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Content
            VStack(spacing: 16) {
                Text("Transactions Management")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Comprehensive transaction tracking is coming soon!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    featureItem(icon: "plus.circle", text: "Add and categorize transactions", color: .blue)
                    featureItem(icon: "magnifyingglass", text: "Search and filter transaction history", color: .purple)
                    featureItem(icon: "chart.line.uptrend.xyaxis", text: "Track portfolio performance over time", color: .green)
                    featureItem(icon: "doc.text", text: "Import from bank statements", color: .orange)
                    featureItem(icon: "calendar", text: "View transactions by date ranges", color: .red)
                }
                .padding(.top, 20)
            }

            Spacer()

            // Progress indicator
            VStack(spacing: 8) {
                Text("Development Progress")
                    .font(.caption)
                    .foregroundColor(.gray)

                ProgressView(value: 0.25)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .frame(width: 200)

                Text("25% Complete")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
        .offset(y: contentOffset)
    }

    // MARK: - Feature Item

    private func featureItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundColor(.secondary)

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
                    .fill(Color.green.opacity(0.03))
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
