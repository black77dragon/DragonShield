import SwiftUI

struct CreditSuisseInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions (German) — Credit-Suisse")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("• Sprache: Deutsch")
                Text("• In \u{201E}Gesamt\u00fcbersicht\u201C Depot \u{201E}398424-05\u201C ausw\u00e4hlen")
                Text("• \u201EPDF/Export\u201C w\u00e4hlen \u2192 \u201EXLS\u201C")
            }
            Button("Close") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 360)
    }
}
