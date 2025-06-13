import SwiftUI

struct DatabaseConnectionTest: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🐉 Dragon Shield Database Test")
                .font(.title)
                .padding()
            
            Button("🔍 Test Database Connection") {
                testDatabaseConnection()
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    func testDatabaseConnection() {
        print("🚀 Starting database test...")
        
        let dbManager = DatabaseManager()
        
        print("📊 Base Currency: \(dbManager.baseCurrency)")
        print("📅 As Of Date: \(dbManager.asOfDate)")
        
        let groups = dbManager.fetchAssetTypes()
        print("📁 Instrument Groups: \(groups.count)")
        for group in groups {
            print("  - \(group.name)")
        }
        
        let instruments = dbManager.fetchAssets()
        print("🏆 Instruments: \(instruments.count)")
        
        let portfolios = dbManager.fetchPortfolios()
        print("💼 Portfolios: \(portfolios.count)")
        for portfolio in portfolios {
            print("  - \(portfolio.name)")
        }
        
        let holdings = dbManager.fetchCurrentHoldings()
        print("📈 Current Holdings: \(holdings.count)")
        
        print("✅ Database test completed successfully!")
    }
}
