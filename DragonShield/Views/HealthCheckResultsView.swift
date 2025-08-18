import SwiftUI

struct HealthCheckResultsView: View {
    @EnvironmentObject var runner: HealthCheckRunner

    var body: some View {
        if runner.reports.isEmpty {
            Text("No health checks executed")
                .foregroundColor(.secondary)
                .navigationTitle("Health Checks")
        } else {
            List {
                Section(header: Text(summary)) {
                    ForEach(runner.reports) { report in
                        HStack {
                            Text(report.name)
                            Spacer()
                            switch report.result {
                            case .ok(let message):
                                Label(message, systemImage: "checkmark.circle")
                                    .foregroundColor(.green)
                            case .warning(let message):
                                Label(message, systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.yellow)
                            case .error(let message):
                                Label(message, systemImage: "xmark.octagon")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Health Checks")
        }
    }

    private var summary: String {
        let ok = runner.reports.filter { if case .ok = $0.result { return true } else { return false } }.count
        let warning = runner.reports.filter { if case .warning = $0.result { return true } else { return false } }.count
        let error = runner.reports.filter { if case .error = $0.result { return true } else { return false } }.count
        return "\(runner.reports.count) checks: \(ok) ok, \(warning) warning, \(error) error"
    }
}

struct HealthCheckResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let runner = HealthCheckRunner(checks: [])
        return HealthCheckResultsView()
            .environmentObject(runner)
    }
}
