import Foundation

struct SuspendingMonitoringScheduler: MonitoringScheduler {
    private let clock = SuspendingClock()

    func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}

struct SystemMonitoringWallClock: MonitoringWallClock {
    private let dateProvider: @Sendable () -> Date

    init(dateProvider: @escaping @Sendable () -> Date = { Date.now }) {
        self.dateProvider = dateProvider
    }

    func now() async -> Date {
        dateProvider()
    }
}
