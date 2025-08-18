import SwiftUI

struct HealthReportView: View {
    @EnvironmentObject var healthVM: HealthCheckViewModel

    var body: some View {
        List(healthVM.results) { result in
            VStack(alignment: .leading) {
                HStack {
                    Text(result.name)
                    Spacer()
                    Text(result.status.rawValue.capitalized)
                        .foregroundColor(color(for: result.status))
                }
                if !result.message.isEmpty {
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Health Report")
    }

    private func color(for status: HealthCheckViewModel.Status) -> Color {
        switch status {
        case .ok: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
