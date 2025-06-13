// DragonShield/Views/TransactionHistoryView.swift
// MARK: - Version 1.1
// MARK: - History
// - 1.0 -> 1.1: Integrated live data fetching from DatabaseManager. Removed sample data.
// - Initial creation: Basic structure for transaction history display.

import SwiftUI

struct TransactionRowData: Identifiable, Equatable {
    let id: Int // Transaction ID
    var date: Date
    var accountName: String
    var instrumentName: String?
    var typeName: String
    var description: String?
    var quantity: Double?
    var price: Double?
    var netAmount: Double
    var currency: String
    var portfolioName: String?

    static func == (lhs: TransactionRowData, rhs: TransactionRowData) -> Bool {
        lhs.id == rhs.id
    }
}

struct TransactionHistoryView: View {
    @EnvironmentObject var dbManager: DatabaseManager
    @State private var transactions: [TransactionRowData] = []
    @State private var showAddTransactionSheet = false
    @State private var selectedTransaction: TransactionRowData? = nil
    @State private var showingDeleteAlert = false
    @State private var transactionToDelete: TransactionRowData? = nil
    @State private var searchText = ""

    @State private var headerOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var buttonsOpacity: Double = 0

    var filteredTransactions: [TransactionRowData] {
        if searchText.isEmpty {
            return transactions.sorted { $0.date > $1.date }
        } else {
            return transactions.filter { transaction in
                transaction.accountName.localizedCaseInsensitiveContains(searchText) ||
                (transaction.instrumentName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                transaction.typeName.localizedCaseInsensitiveContains(searchText) ||
                (transaction.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                transaction.currency.localizedCaseInsensitiveContains(searchText) ||
                (transaction.portfolioName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                String(format: "%.2f", transaction.netAmount).localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.date > $1.date }
        }
    }

    var body: some View {
        ZStack {
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

            TransactionHistoryParticleBackground()

            VStack(spacing: 0) {
                modernHeader
                searchAndStats
                transactionsContent
                modernActionBar
            }
        }
        .onAppear {
            loadTransactionHistory()
            animateEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTransactionHistory"))) { _ in
            loadTransactionHistory()
        }
    }

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(Color.teal)
                    
                    Text("Transaction History")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.black, .gray],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                Text("Review your past financial activities")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                modernStatCard(
                    title: "Total",
                    value: "\(transactions.count)", // Will update with live data
                    icon: "list.bullet.indent",
                    color: .teal
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .opacity(headerOpacity)
    }
    
    private var searchAndStats: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search (description, instrument, type, amount...)", text: $searchText) // Updated placeholder
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
            
            if !filteredTransactions.isEmpty && !searchText.isEmpty { // Show count only if results exist for search
                HStack {
                    Text("Found \(filteredTransactions.count) transaction(s)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .offset(y: contentOffset)
    }
    
    private var transactionsContent: some View {
        VStack(spacing: 16) {
            if transactions.isEmpty && searchText.isEmpty { // Show "No transactions recorded" only if DB is empty and no search
                emptyStateView
            } else if filteredTransactions.isEmpty && !searchText.isEmpty { // Show "No matching transactions" for active search
                 emptyStateView
            }
            else {
                transactionsTable
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .offset(y: contentOffset)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(spacing: 8) {
                    Text(searchText.isEmpty && transactions.isEmpty ? "No transactions recorded" : "No matching transactions")
                        .font(.title2).fontWeight(.semibold).foregroundColor(.gray)
                    Text(searchText.isEmpty && transactions.isEmpty ? "Your transaction history will appear here." : "Try adjusting your search terms or clear the search.")
                        .font(.body).foregroundColor(.gray).multilineTextAlignment(.center)
                }
            }
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var transactionsTable: some View {
        VStack(spacing: 0) {
            modernTableHeader
            ScrollView {
                LazyVStack(spacing: CGFloat(dbManager.tableRowSpacing)) {
                    ForEach(filteredTransactions) { transaction in
                        ModernTransactionRowView(
                            transaction: transaction,
                            isSelected: selectedTransaction?.id == transaction.id,
                            rowPadding: CGFloat(dbManager.tableRowPadding),
                            onTap: { selectedTransaction = transaction },
                            onEdit: {
                                selectedTransaction = transaction
                            }
                        )
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    private var modernTableHeader: some View {
        HStack {
            Text("Date").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 100, alignment: .leading)
            Text("Type").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 120, alignment: .leading)
            Text("Instrument/Desc.").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading) // Adjusted Header
            Text("Account").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 150, alignment: .leading)
            Text("Amount").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 100, alignment: .trailing) // Adjusted width
            Text("Curr.").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray).frame(width: 40, alignment: .leading) // Adjusted width
        }
        .padding(.horizontal, CGFloat(dbManager.tableRowPadding))
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
        .padding(.bottom, 1)
    }
    
    private var modernActionBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1)
            HStack(spacing: 16) {
                Button {
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add New Transaction")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.teal)
                    .clipShape(Capsule())
                    .shadow(color: .teal.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(true)
                
                Spacer()
                
                if let transaction = selectedTransaction {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.teal)
                        Text("Selected: \(transaction.typeName) on \(transaction.date, style: .date)")
                            .font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.teal.opacity(0.05)).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
        .opacity(buttonsOpacity)
    }

    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
                Text(title).font(.system(size: 11, weight: .medium)).foregroundColor(.gray)
            }
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1)))
        .shadow(color: color.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) { headerOpacity = 1.0 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) { contentOffset = 0 }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) { buttonsOpacity = 1.0 }
    }

    func loadTransactionHistory() {
         transactions = dbManager.fetchTransactionHistoryItems()
         // Sample data call is now removed.
    }
}

struct ModernTransactionRowView: View {
    let transaction: TransactionRowData
    let isSelected: Bool
    let rowPadding: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void

    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // Matching schema's date format for display consistency
        return formatter
    }()

    var body: some View {
        HStack {
            Text(transaction.date, formatter: Self.dateFormatter)
                .font(.system(size: 14, weight: .regular, design: .monospaced)).foregroundColor(.primary) // Monospaced for dates
                .frame(width: 100, alignment: .leading)

            Text(transaction.typeName)
                .font(.system(size: 13, weight: .medium)) // Slightly smaller
                .foregroundColor(transactionTypeColor(transaction.typeName))
                .padding(.horizontal, 8).padding(.vertical, 3) // Adjusted padding
                .background(transactionTypeColor(transaction.typeName).opacity(0.1))
                .clipShape(Capsule())
                .frame(width: 120, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 1) { // Reduced spacing
                Text(transaction.instrumentName ?? transaction.description ?? "N/A")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.primary) // Slightly smaller
                    .lineLimit(1)
                if transaction.instrumentName != nil && transaction.description != nil && !(transaction.description?.isEmpty ?? true) {
                    Text(transaction.description!)
                        .font(.system(size: 12)).foregroundColor(.gray) // Smaller caption
                        .lineLimit(1)
                } else if transaction.instrumentName == nil && transaction.description != nil {
                     Text(transaction.description!)
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(transaction.accountName)
                .font(.system(size: 13)).foregroundColor(.secondary) // Slightly smaller
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)

            Text(String(format: "%.2f", transaction.netAmount))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(transaction.netAmount >= 0 ? .green : .red)
                .frame(width: 100, alignment: .trailing) // Adjusted width
            
            Text(transaction.currency)
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray) // Slightly smaller
                .frame(width: 40, alignment: .leading) // Adjusted width
        }
        .padding(.horizontal, rowPadding)
        .padding(.vertical, rowPadding / 1.8) // Adjusted vertical padding
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.teal.opacity(0.1) : Color.clear).overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.teal.opacity(0.3) : Color.clear, lineWidth: 1)))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onTapGesture(count: 2) { onEdit() }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func transactionTypeColor(_ typeName: String) -> Color {
        switch typeName.uppercased() {
        case "PURCHASE", "BUY", "TRANSFER OUT": return .red
        case "SALE", "SELL", "TRANSFER IN": return .green
        case "DIVIDEND", "INTEREST": return .purple
        case "FEE", "TAX": return .orange
        case "DEPOSIT": return .blue
        case "WITHDRAWAL": return .pink
        default: return .gray
        }
    }
}

struct TransactionHistoryParticleBackground: View {
    @State private var particles: [TransactionHistoryParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Circle()
                    .fill(Color.teal.opacity(0.03))
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
            TransactionHistoryParticle(
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
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            for index in particles.indices {
                particles[index].position.y -= 1000
                particles[index].opacity = Double.random(in: 0.05...0.15)
            }
        }
    }
}

struct TransactionHistoryParticle {
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct TransactionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionHistoryView()
            .environmentObject(DatabaseManager())
    }
}
