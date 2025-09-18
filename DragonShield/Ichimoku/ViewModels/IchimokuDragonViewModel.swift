import Foundation
import Combine

@MainActor
final class IchimokuDragonViewModel: ObservableObject {
    @Published var candidateDates: [Date] = []
    @Published var selectedDate: Date? = nil
    @Published var candidates: [IchimokuCandidateRow] = []
    @Published var positions: [IchimokuPositionRow] = []
    @Published var sellAlerts: [IchimokuSellAlertRow] = []
    @Published var runLogs: [IchimokuRunLogRow] = []
    @Published var lastRunSummary: IchimokuPipelineSummary? = nil
    @Published var lastReportURL: URL? = nil
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = ""

    let settingsService: IchimokuSettingsService

    private let dbManager: DatabaseManager
    private let pipelineService: IchimokuPipelineService
    private let reportService: IchimokuReportService
    private var cancellables: Set<AnyCancellable> = []

    init(dbManager: DatabaseManager,
         settingsService: IchimokuSettingsService) {
        self.dbManager = dbManager
        self.settingsService = settingsService
        self.pipelineService = IchimokuPipelineService(dbManager: dbManager,
                                                       settingsService: settingsService)
        self.reportService = IchimokuReportService(dbManager: dbManager)
    }

    func loadInitialData() {
        refreshCandidateDates()
        refreshPositions()
        refreshSellAlerts()
        refreshRunLogs()
        if selectedDate == nil {
            selectedDate = candidateDates.first
        }
        if let date = selectedDate {
            refreshCandidates(for: date)
        }
    }


    func refreshCandidateDates(limit: Int = 30) {
        let dates = dbManager.ichimokuFetchRecentCandidateDates(limit: limit)
        candidateDates = dates
        let formatter = DateFormatter.iso8601DateOnly
        if let selected = selectedDate {
            let selectedKey = formatter.string(from: selected)
            if let match = dates.first(where: { formatter.string(from: $0) == selectedKey }) {
                selectedDate = match
            } else {
                selectedDate = dates.first
            }
        } else {
            selectedDate = dates.first
        }
    }

    func refreshCandidates(for date: Date) {
        selectedDate = date
        candidates = dbManager.ichimokuFetchCandidates(for: date)
    }

    func refreshPositions(includeClosed: Bool = false) {
        positions = dbManager.ichimokuFetchPositions(includeClosed: includeClosed)
    }

    func refreshSellAlerts(includeResolved: Bool = true) {
        sellAlerts = dbManager.ichimokuFetchSellAlerts(limit: includeResolved ? 50 : 20,
                                                       unresolvedOnly: !includeResolved)
    }

    func refreshRunLogs(limit: Int = 20) {
        runLogs = dbManager.ichimokuFetchRunLogs(limit: limit)
    }

    func runDailyScan() async {
        guard !isRunning else { return }
        isRunning = true
        statusMessage = "Running daily scan..."
        do {
            let summary = try await pipelineService.runDailyScan()
            statusMessage = ""
            lastRunSummary = summary
            refreshCandidateDates()
            if let date = summary.scanDate as Date? {
                refreshCandidates(for: date)
            }
            refreshPositions()
            refreshSellAlerts()
            refreshRunLogs()
            do {
                lastReportURL = try reportService.generateReport(summary: summary)
            } catch {
                statusMessage = "Scan completed but report failed: \(error.localizedDescription)"
            }
            if statusMessage.isEmpty {
                statusMessage = "Scan completed successfully"
            }
        } catch {
            statusMessage = "Scan failed: \(error.localizedDescription)"
        }
        isRunning = false
    }

    func confirmPosition(_ position: IchimokuPositionRow) {
        guard dbManager.ichimokuSetPositionConfirmation(positionId: position.id, confirmed: true) else { return }
        refreshPositions()
    }

    func closePosition(_ position: IchimokuPositionRow) {
        guard dbManager.ichimokuUpdatePositionStatus(positionId: position.id,
                                                     status: .closed,
                                                     closedDate: Date()) else { return }
        refreshPositions()
    }

    func resolveAlert(_ alert: IchimokuSellAlertRow) {
        guard dbManager.ichimokuResolveSellAlert(alertId: alert.id, resolvedAt: Date()) else { return }
        refreshSellAlerts()
    }
}
