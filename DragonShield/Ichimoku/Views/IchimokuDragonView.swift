import SwiftUI
#if os(macOS)
import AppKit
#endif

private enum IchimokuDragonSection: String, CaseIterable, Identifiable {
    case dashboard
    case watchlist
    case alerts
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .watchlist: return "Watchlist"
        case .alerts: return "Alerts"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .watchlist: return "list.bullet.rectangle"
        case .alerts: return "bell.badge"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct IchimokuDragonView: View {
    @EnvironmentObject var viewModel: IchimokuDragonViewModel
    @State private var selectedSection: IchimokuDragonSection = .dashboard

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Picker("Section", selection: $selectedSection) {
                ForEach(IchimokuDragonSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage).tag(section)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedSection {
                case .dashboard:
                    IchimokuDashboardSection()
                case .watchlist:
                    IchimokuWatchlistSection()
                case .alerts:
                    IchimokuAlertsSection()
                case .history:
                    IchimokuHistorySection()
                case .settings:
                    IchimokuSettingsSection()
                }
            }
            .environmentObject(viewModel)
        }
        .padding(24)
        .background(Color(.windowBackgroundColor))
        .task {
            viewModel.loadInitialData()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading) {
                Text("Ichimoku Dragon")
                    .font(.system(size: 26, weight: .bold))
                Text("Momentum scanner for S&P 500 & Nasdaq 100")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isRunning {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
    }
}

private struct IchimokuDashboardSection: View {
    @EnvironmentObject var viewModel: IchimokuDragonViewModel
    @EnvironmentObject var scheduler: IchimokuScheduler
    @State private var showReportConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    Task { await viewModel.runDailyScan() }
                } label: {
                    Label(viewModel.isRunning ? "Running…" : "Run Daily Scan",
                          systemImage: viewModel.isRunning ? "hourglass" : "play.circle")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                if let summary = viewModel.lastRunSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last run: \(DateFormatter.iso8601DateTime.string(from: summary.scanDate))")
                            .font(.footnote)
                        Text("Candidates: \(summary.candidates.count) • Alerts: \(summary.sellAlerts.count)")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
                Spacer()
                if let url = viewModel.lastReportURL {
                    Button {
                        open(url: url)
                    } label: {
                        Label("Open CSV Report", systemImage: "doc.richtext")
                    }
                }
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let nextRun = scheduler.nextRun {
                Text("Next scheduled run: \(DateFormatter.iso8601DateTime.string(from: nextRun))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            candidateDateSelector
            candidatesList
            Spacer()
        }
    }

    private var candidateDateSelector: some View {
        HStack {
            Text("Scan Date")
                .font(.subheadline.weight(.semibold))
            if viewModel.candidateDates.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Scan Date", selection: Binding(get: {
                    viewModel.selectedDate ?? viewModel.candidateDates.first ?? Date()
                }, set: { newDate in
                    viewModel.refreshCandidates(for: newDate)
                })) {
                    ForEach(viewModel.candidateDates, id: \.self) { date in
                        Text(DateFormatter.iso8601DateOnly.string(from: date)).tag(date)
                    }
                }
                .pickerStyle(.menu)
            }
            Spacer()
        }
    }

    private var candidatesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Candidates")
                    .font(.headline)
                Spacer()
            }
            if viewModel.candidates.isEmpty {
                Text("No qualified candidates for the selected date.")
                    .foregroundStyle(.secondary)
            } else {
                Table(viewModel.candidates) {
                    TableColumn("Rank") { candidate in
                        Text("#\(candidate.rank)")
                    }
                    TableColumn("Symbol") { candidate in
                        Text(candidate.ticker.symbol)
                    }
                    TableColumn("Name") { candidate in
                        Text(candidate.ticker.name)
                    }
                    TableColumn("Momentum") { candidate in
                        Text(String(format: "%.4f", candidate.momentumScore))
                    }
                    TableColumn("Close") { candidate in
                        Text(String(format: "%.2f", candidate.closePrice))
                    }
                    TableColumn("Tenkan") { candidate in
                        Text(candidate.tenkan.map { String(format: "%.2f", $0) } ?? "–")
                    }
                    TableColumn("Kijun") { candidate in
                        Text(candidate.kijun.map { String(format: "%.2f", $0) } ?? "–")
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    private func open(url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

private struct IchimokuWatchlistSection: View {
    @EnvironmentObject var viewModel: IchimokuDragonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Positions")
                    .font(.headline)
                Spacer()
                Button("Refresh") { viewModel.refreshPositions() }
            }
            if viewModel.positions.isEmpty {
                Text("No active positions yet. Confirm entries from the dashboard to track them here.")
                    .foregroundStyle(.secondary)
            } else {
                Table(viewModel.positions) {
                    TableColumn("Symbol") { position in
                        Text(position.ticker.symbol)
                    }
                    TableColumn("Name") { position in
                        Text(position.ticker.name)
                    }
                    TableColumn("Opened") { position in
                        Text(DateFormatter.iso8601DateOnly.string(from: position.dateOpened))
                    }
                    TableColumn("Status") { position in
                        Text(position.status.displayName)
                    }
                    TableColumn("Last Close") { position in
                        Text(position.lastClose.map { String(format: "%.2f", $0) } ?? "–")
                    }
                    TableColumn("Last Kijun") { position in
                        Text(position.lastKijun.map { String(format: "%.2f", $0) } ?? "–")
                    }
                    TableColumn("Actions") { position in
                        HStack {
                            if !position.confirmedByUser {
                                Button("Confirm") { viewModel.confirmPosition(position) }
                            }
                            Button("Close") { viewModel.closePosition(position) }
                        }
                    }
                }
                .frame(minHeight: 220)
            }
            Spacer()
        }
    }
}

private struct IchimokuAlertsSection: View {
    @EnvironmentObject var viewModel: IchimokuDragonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sell Alerts")
                    .font(.headline)
                Spacer()
                Button("Refresh") { viewModel.refreshSellAlerts(includeResolved: true) }
            }
            if viewModel.sellAlerts.isEmpty {
                Text("No alerts recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                Table(viewModel.sellAlerts) {
                    TableColumn("Symbol") { alert in
                        Text(alert.ticker.symbol)
                    }
                    TableColumn("Alert Date") { alert in
                        Text(DateFormatter.iso8601DateOnly.string(from: alert.alertDate))
                    }
                    TableColumn("Close") { alert in
                        Text(String(format: "%.2f", alert.closePrice))
                    }
                    TableColumn("Kijun") { alert in
                        Text(alert.kijunValue.map { String(format: "%.2f", $0) } ?? "–")
                    }
                    TableColumn("Reason") { alert in
                        Text(alert.reason)
                    }
                    TableColumn("Actions") { alert in
                        HStack {
                            if alert.resolvedAt == nil {
                                Button("Resolve") { viewModel.resolveAlert(alert) }
                            }
                        }
                    }
                }
                .frame(minHeight: 220)
            }
            Spacer()
        }
    }
}

private struct IchimokuHistorySection: View {
    @EnvironmentObject var viewModel: IchimokuDragonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Run History")
                    .font(.headline)
                Spacer()
                Button("Refresh") { viewModel.refreshRunLogs() }
            }
            if viewModel.runLogs.isEmpty {
                Text("No pipeline runs logged yet.")
                    .foregroundStyle(.secondary)
            } else {
                Table(viewModel.runLogs) {
                    TableColumn("Started") { log in
                        Text(DateFormatter.iso8601DateTime.string(from: log.startedAt))
                    }
                    TableColumn("Status") { log in
                        Text(log.status.rawValue)
                    }
                    TableColumn("Candidates") { log in
                        Text("\(log.candidatesFound)")
                    }
                    TableColumn("Alerts") { log in
                        Text("\(log.alertsTriggered)")
                    }
                    TableColumn("Message") { log in
                        Text(log.message ?? "")
                    }
                }
                .frame(minHeight: 220)
            }
            Spacer()
        }
    }
}

private struct IchimokuSettingsSection: View {
    @EnvironmentObject var viewModel: IchimokuDragonViewModel
    @State private var workingState: IchimokuSettingsState = .defaults

    var body: some View {
        Form {
            Section(header: Text("Scheduler")) {
                Toggle("Enable daily scan", isOn: Binding(get: {
                    viewModel.settingsService.state.scheduleEnabled
                }, set: { newValue in
                    workingState.scheduleEnabled = newValue
                    viewModel.settingsService.update(workingState)
                }))
                HStack {
                    Text("Time")
                    Spacer()
                    DatePicker("",
                               selection: Binding(get: {
                        let comps = viewModel.settingsService.state.scheduleTime
                        let calendar = Calendar.current
                        return calendar.date(from: comps) ?? Date()
                    }, set: { newDate in
                        var comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        comps.timeZone = viewModel.settingsService.state.scheduleTimeZone
                        workingState.scheduleTime = comps
                        viewModel.settingsService.update(workingState)
                    }),
                               displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                TextField("Timezone", text: Binding(get: {
                    viewModel.settingsService.state.scheduleTimeZone.identifier
                }, set: { newValue in
                    if let tz = TimeZone(identifier: newValue) {
                        workingState.scheduleTimeZone = tz
                        viewModel.settingsService.update(workingState)
                    }
                }))
                .textFieldStyle(.roundedBorder)
            }
            Section(header: Text("Scan Parameters")) {
                Stepper(value: Binding(get: {
                    Double(viewModel.settingsService.state.maxCandidates)
                }, set: { newValue in
                    workingState.maxCandidates = Int(newValue)
                    viewModel.settingsService.update(workingState)
                }), in: 1...10, step: 1) {
                    Text("Max candidates: \(viewModel.settingsService.state.maxCandidates)")
                }
                Stepper(value: Binding(get: {
                    Double(viewModel.settingsService.state.historyLookbackDays)
                }, set: { newValue in
                    workingState.historyLookbackDays = Int(newValue)
                    viewModel.settingsService.update(workingState)
                }), in: 60...400, step: 10) {
                    Text("History lookback: \(viewModel.settingsService.state.historyLookbackDays) days")
                }
                Stepper(value: Binding(get: {
                    Double(viewModel.settingsService.state.regressionWindow)
                }, set: { newValue in
                    workingState.regressionWindow = Int(newValue)
                    viewModel.settingsService.update(workingState)
                }), in: 3...15, step: 1) {
                    Text("Regression window: \(viewModel.settingsService.state.regressionWindow) days")
                }
            }
        }
        .onAppear {
            workingState = viewModel.settingsService.state
        }
        .onReceive(viewModel.settingsService.$state) { newState in
            workingState = newState
        }
    }
}
