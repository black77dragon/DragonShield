import SwiftUI

struct HealthCheckResultsView: View {
    @EnvironmentObject var runner: HealthCheckRunner

    var body: some View {
        List(runner.reports) { report in
            HStack {
                Text(report.name)
                Spacer()
                switch report.result {
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                case .warning(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                case .failure(let message):
                    Label(message, systemImage: "xmark.octagon")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Health Checks")
    }
}

struct HealthCheckResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let runner = HealthCheckRunner(checks: [])
        return HealthCheckResultsView()
            .environmentObject(runner)
    }
}
