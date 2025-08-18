import Foundation
import SwiftUI

@MainActor
final class HealthCheckViewModel: ObservableObject {
    enum Status: String {
        case ok
        case warning
        case error
    }

    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let status: Status
        let message: String
    }

    @Published private(set) var results: [Result] = []

    func runChecks() {
        results = [
            Result(name: "Database", status: .ok, message: "Connected"),
            Result(name: "Disk Space", status: .warning, message: "Low disk space"),
            Result(name: "Backup", status: .error, message: "No recent backup")
        ]
    }

    var summary: (ok: Int, warning: Int, error: Int) {
        let ok = results.filter { $0.status == .ok }.count
        let warning = results.filter { $0.status == .warning }.count
        let error = results.filter { $0.status == .error }.count
        return (ok, warning, error)
    }
}
