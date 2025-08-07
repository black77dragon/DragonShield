import SwiftUI

struct TargetValueCell: View {
    let text: String
    let hasValidationErrors: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if hasValidationErrors {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .accessibilityLabel("Validation warning")
            }
        }
    }
}
