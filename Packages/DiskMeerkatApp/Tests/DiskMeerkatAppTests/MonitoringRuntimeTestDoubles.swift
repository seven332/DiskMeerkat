import Foundation

@testable import DiskMeerkatApp

enum MonitoringRuntimeTestError: Error, Sendable {
    case expectedFailure
}

actor TestStartupVolumeReader: StartupVolumeReader {
    private var queuedReadings: [DiskSpaceReading]
    private var pendingReads: [CheckedContinuation<DiskSpaceReading, Never>] = []
    private var readCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var inactiveWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var readCount = 0
    private(set) var activeReadCount = 0
    private(set) var maximumActiveReadCount = 0

    init(readings: [DiskSpaceReading] = []) {
        queuedReadings = readings
    }

    func readStartupVolume() async -> DiskSpaceReading {
        readCount += 1
        activeReadCount += 1
        maximumActiveReadCount = max(maximumActiveReadCount, activeReadCount)
        resumeReadCountWaiters()

        let reading: DiskSpaceReading
        if queuedReadings.isEmpty {
            reading = await withCheckedContinuation { continuation in
                pendingReads.append(continuation)
            }
        } else {
            reading = queuedReadings.removeFirst()
        }

        activeReadCount -= 1
        if activeReadCount == 0 {
            let waiters = inactiveWaiters
            inactiveWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
        return reading
    }

    func enqueue(_ reading: DiskSpaceReading) {
        if pendingReads.isEmpty {
            queuedReadings.append(reading)
        } else {
            pendingReads.removeFirst().resume(returning: reading)
        }
    }

    func waitForReadCount(_ expectedCount: Int) async {
        guard readCount < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            readCountWaiters.append((expectedCount, continuation))
        }
    }

    func counts() -> (read: Int, active: Int, maximumActive: Int) {
        (readCount, activeReadCount, maximumActiveReadCount)
    }

    func waitUntilInactive() async {
        guard activeReadCount > 0 else {
            return
        }

        await withCheckedContinuation { continuation in
            inactiveWaiters.append(continuation)
        }
    }

    private func resumeReadCountWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in readCountWaiters {
            if readCount >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        readCountWaiters = remaining
    }
}

actor TestMonitoringStateRepository: MonitoringStateRepository {
    private var state: StoredMonitoringState
    private var remainingLoadFailures: Int
    private var remainingSaveFailures = 0
    private var shouldSuspendNextSave = false
    private var pendingSave:
        (
            state: StoredMonitoringState,
            continuation: CheckedContinuation<Void, any Error>
        )?
    private var saveCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var loadCount = 0
    private(set) var attemptedSaves: [StoredMonitoringState] = []

    init(
        state: StoredMonitoringState = .defaultValue,
        loadFailures: Int = 0
    ) {
        self.state = state
        remainingLoadFailures = loadFailures
    }

    func load() async throws -> StoredMonitoringState {
        loadCount += 1
        if remainingLoadFailures > 0 {
            remainingLoadFailures -= 1
            throw MonitoringRuntimeTestError.expectedFailure
        }
        return state
    }

    func save(_ state: StoredMonitoringState) async throws {
        attemptedSaves.append(state)
        resumeSaveCountWaiters()

        if remainingSaveFailures > 0 {
            remainingSaveFailures -= 1
            throw MonitoringRuntimeTestError.expectedFailure
        }

        if shouldSuspendNextSave {
            shouldSuspendNextSave = false
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                pendingSave = (state, continuation)
            }
        }

        self.state = state
    }

    func failNextSaves(_ count: Int = 1) {
        remainingSaveFailures += count
    }

    func suspendNextSave() {
        shouldSuspendNextSave = true
    }

    func completePendingSave(success: Bool) {
        guard let pendingSave else {
            return
        }
        self.pendingSave = nil
        if success {
            pendingSave.continuation.resume()
        } else {
            pendingSave.continuation.resume(throwing: MonitoringRuntimeTestError.expectedFailure)
        }
    }

    func waitForSaveCount(_ expectedCount: Int) async {
        guard attemptedSaves.count < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            saveCountWaiters.append((expectedCount, continuation))
        }
    }

    func savedState() -> StoredMonitoringState {
        state
    }

    func saves() -> [StoredMonitoringState] {
        attemptedSaves
    }

    private func resumeSaveCountWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in saveCountWaiters {
            if attemptedSaves.count >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        saveCountWaiters = remaining
    }
}

actor TestMonitoringNotificationService: MonitoringNotificationService {
    private var state: NotificationAuthorizationState
    private var requestedState: NotificationAuthorizationState
    private var remainingStatusFailures = 0
    private var remainingRequestFailures = 0
    private var remainingSubmissionFailures = 0
    private var shouldSuspendNextRemoval = false
    private var shouldSuspendNextSubmission = false
    private var pendingRemoval: CheckedContinuation<Void, Never>?
    private var pendingSubmission: CheckedContinuation<Void, any Error>?
    private var removalCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var submissionCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var authorizationStateCallCount = 0
    private(set) var authorizationRequestCount = 0
    private(set) var deliveredNotificationRemovalCount = 0
    private(set) var submittedCandidates: [LowSpaceNotificationCandidate] = []

    init(state: NotificationAuthorizationState = .denied) {
        self.state = state
        requestedState = state
    }

    func authorizationState() async throws -> NotificationAuthorizationState {
        authorizationStateCallCount += 1
        if remainingStatusFailures > 0 {
            remainingStatusFailures -= 1
            throw MonitoringRuntimeTestError.expectedFailure
        }
        return state
    }

    func requestAuthorization() async throws -> NotificationAuthorizationState {
        authorizationRequestCount += 1
        if remainingRequestFailures > 0 {
            remainingRequestFailures -= 1
            throw MonitoringRuntimeTestError.expectedFailure
        }
        state = requestedState
        return state
    }

    func removeDeliveredLowSpaceNotification() async {
        deliveredNotificationRemovalCount += 1
        resumeRemovalCountWaiters()
        if shouldSuspendNextRemoval {
            shouldSuspendNextRemoval = false
            await withCheckedContinuation { continuation in
                pendingRemoval = continuation
            }
        }
    }

    func submit(_ candidate: LowSpaceNotificationCandidate) async throws {
        submittedCandidates.append(candidate)
        resumeSubmissionCountWaiters()
        if remainingSubmissionFailures > 0 {
            remainingSubmissionFailures -= 1
            throw MonitoringRuntimeTestError.expectedFailure
        }
        if shouldSuspendNextSubmission {
            shouldSuspendNextSubmission = false
            try await withCheckedThrowingContinuation { continuation in
                pendingSubmission = continuation
            }
        }
    }

    func setAuthorizationState(_ state: NotificationAuthorizationState) {
        self.state = state
    }

    func setRequestedState(_ state: NotificationAuthorizationState) {
        requestedState = state
    }

    func failNextStatusRequests(_ count: Int = 1) {
        remainingStatusFailures += count
    }

    func failNextAuthorizationRequests(_ count: Int = 1) {
        remainingRequestFailures += count
    }

    func failNextSubmissions(_ count: Int = 1) {
        remainingSubmissionFailures += count
    }

    func suspendNextRemoval() {
        shouldSuspendNextRemoval = true
    }

    func suspendNextSubmission() {
        shouldSuspendNextSubmission = true
    }

    func completePendingRemoval() {
        pendingRemoval?.resume()
        pendingRemoval = nil
    }

    func completePendingSubmission(success: Bool) {
        guard let pendingSubmission else {
            return
        }
        self.pendingSubmission = nil
        if success {
            pendingSubmission.resume()
        } else {
            pendingSubmission.resume(throwing: MonitoringRuntimeTestError.expectedFailure)
        }
    }

    func waitForSubmissionCount(_ expectedCount: Int) async {
        guard submittedCandidates.count < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            submissionCountWaiters.append((expectedCount, continuation))
        }
    }

    func waitForRemovalCount(_ expectedCount: Int) async {
        guard deliveredNotificationRemovalCount < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            removalCountWaiters.append((expectedCount, continuation))
        }
    }

    func removalCount() -> Int {
        deliveredNotificationRemovalCount
    }

    func submissionCount() -> Int {
        submittedCandidates.count
    }

    func requestCount() -> Int {
        authorizationRequestCount
    }

    private func resumeRemovalCountWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in removalCountWaiters {
            if deliveredNotificationRemovalCount >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        removalCountWaiters = remaining
    }

    private func resumeSubmissionCountWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in submissionCountWaiters {
            if submittedCandidates.count >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        submissionCountWaiters = remaining
    }
}

actor TestMonitoringScheduler: MonitoringScheduler {
    private struct PendingSleep {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var pendingSleeps: [PendingSleep] = []
    private var sleepCountWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private let ignoresCancellation: Bool
    private(set) var requestedDurations: [Duration] = []

    init(ignoresCancellation: Bool = false) {
        self.ignoresCancellation = ignoresCancellation
    }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    requestedDurations.append(duration)
                    pendingSleeps.append(PendingSleep(id: id, continuation: continuation))
                    resumeSleepCountWaiters()
                }
            }
        } onCancel: {
            Task {
                await self.cancel(id: id)
            }
        }
    }

    func fireNext() {
        guard !pendingSleeps.isEmpty else {
            return
        }
        pendingSleeps.removeFirst().continuation.resume()
    }

    func waitForSleepCount(_ expectedCount: Int) async {
        guard requestedDurations.count < expectedCount else {
            return
        }

        await withCheckedContinuation { continuation in
            sleepCountWaiters.append((expectedCount, continuation))
        }
    }

    func durations() -> [Duration] {
        requestedDurations
    }

    func pendingSleepCount() -> Int {
        pendingSleeps.count
    }

    private func cancel(id: UUID) {
        guard !ignoresCancellation,
            let index = pendingSleeps.firstIndex(where: { $0.id == id })
        else {
            return
        }
        pendingSleeps.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func resumeSleepCountWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in sleepCountWaiters {
            if requestedDurations.count >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        sleepCountWaiters = remaining
    }
}

actor TestMonitoringWallClock: MonitoringWallClock {
    private var dates: [Date]
    private let fallback: Date
    private(set) var callCount = 0

    init(dates: [Date] = [Date(timeIntervalSince1970: 1_000)]) {
        self.dates = dates
        fallback = dates.last ?? Date(timeIntervalSince1970: 1_000)
    }

    func now() async -> Date {
        callCount += 1
        if dates.isEmpty {
            return fallback
        }
        return dates.removeFirst()
    }

    func calls() -> Int {
        callCount
    }
}

actor TestMonitoringWakeEventSource: MonitoringWakeEventSource {
    private var continuations: [AsyncStream<Void>.Continuation] = []

    func events() async -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        continuations.append(continuation)
        return stream
    }

    func sendWake() {
        continuations.last?.yield()
    }
}
