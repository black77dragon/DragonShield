import SwiftUI

struct CreditSuisseInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions (German) — Credit-Suisse")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("\u{2022} Sprache: Deutsch")
                Text("\u{2022} In \u{201E}Gesamt\u00fcbersicht\u201c Depot \u{201E}398424-05\u201c ausw\u00e4hlen")
                Text("\u{2022} \u{201E}PDF/Export\u201c w\u00e4hlen \u2192 \u201EXLS\u201c")
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .frame(width: 400)
    }
}
