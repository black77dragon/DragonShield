import SwiftUI

struct ValidationStatusDot: View {
    let status: String

    private var color: Color {
        switch status {
        case "compliant": return .success
        case "warning": return .warning
        case "error": return .error
        default: return .gray
        }
    }

    private var label: String {
        switch status {
        case "compliant": return "Compliant"
        case "warning": return "Warning"
        case "error": return "Error"
        default: return "Unknown"
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityLabel(Text(label))
    }
}
