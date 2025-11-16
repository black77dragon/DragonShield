import Combine
import Foundation

@MainActor
final class IchimokuScheduler: ObservableObject {
    @Published private(set) var nextRun: Date? = nil

    private let settingsService: IchimokuSettingsService
    private weak var viewModel: IchimokuDragonViewModel?
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(settingsService: IchimokuSettingsService,
         viewModel: IchimokuDragonViewModel)
    {
        self.settingsService = settingsService
        self.viewModel = viewModel
        settingsService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reschedule()
            }
            .store(in: &cancellables)
    }

    func start() {
        reschedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        nextRun = nil
    }

    private func reschedule() {
        timer?.invalidate()
        guard settingsService.state.scheduleEnabled else {
            nextRun = nil
            return
        }
        guard let nextDate = computeNextRunDate(from: Date()) else {
            nextRun = nil
            return
        }
        nextRun = nextDate
        let interval = max(1, nextDate.timeIntervalSinceNow)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let vm = self.viewModel { await vm.runDailyScan() }
                self.reschedule()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func computeNextRunDate(from reference: Date) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var components = settingsService.state.scheduleTime
        components.timeZone = settingsService.state.scheduleTimeZone
        var baseComponents = calendar.dateComponents(in: settingsService.state.scheduleTimeZone, from: reference)
        baseComponents.hour = components.hour
        baseComponents.minute = components.minute
        baseComponents.second = 0
        baseComponents.nanosecond = 0
        guard let candidate = calendar.date(from: baseComponents) else { return nil }
        if candidate > reference {
            return candidate
        } else {
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            return next
        }
    }
}
