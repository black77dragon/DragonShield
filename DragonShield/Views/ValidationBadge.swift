import SwiftUI

struct ValidationBadge: View {
    let status: ValidationStatus

    var body: some View {
        Text(status.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .clipShape(Capsule())
    }
}
