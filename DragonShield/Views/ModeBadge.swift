import SwiftUI

struct ModeBadge: View {
    @EnvironmentObject var dbManager: DatabaseManager

    private var color: Color {
        dbManager.dbMode == .production ? .red : .blue
    }

    var body: some View {
        Text(dbManager.dbMode.rawValue.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Capsule()
                    .stroke(color, lineWidth: 2)
            )
            .foregroundColor(color)
            .accessibilityLabel("Database mode")
    }
}

struct ModeBadge_Previews: PreviewProvider {
    static var previews: some View {
        ModeBadge()
            .environmentObject(DatabaseManager())
    }
}
