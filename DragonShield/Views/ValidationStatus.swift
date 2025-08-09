import SwiftUI

enum ValidationStatus: String {
    case compliant
    case warning
    case error

    var color: Color {
        switch self {
        case .compliant: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var label: String {
        switch self {
        case .compliant: return "Compliant"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}
