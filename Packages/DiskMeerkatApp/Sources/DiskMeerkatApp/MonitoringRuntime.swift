import Foundation

actor MonitoringRuntime {
    private let diskReader: any StartupVolumeReader
    private let repository: SerializedMonitoringStateRepository
    private let notificationService: any MonitoringNotificationService
    private let scheduler: any MonitoringScheduler
    private let wallClock: any MonitoringWallClock
    private let wakeEventSource: any MonitoringWakeEventSource

    private var storedState = StoredMonitoringState.defaultValue
    private var lifecycleState = MonitoringLifecycleState.stopped
    private var notificationAuthorizationState = NotificationAuthorizationState.unknown
    private var persistenceFailure: MonitoringPersistenceFailure?
    private var notificationFailure: MonitoringNotificationFailure?
    private var latestSuccessfulVolume: StartupVolumeSnapshot?
    private var latestAssessment: DiskSpaceAssessment?
    private var lastSuccessfulCheckAt: Date?
    private var nextScheduledCheckAt: Date?

    private var runtimeGeneration: UInt64 = 0
    private var configurationRevision: UInt64 = 0
    private var durableRevision: UInt64 = 0
    private var scheduleGeneration: UInt64 = 0
    private var configurationSaveGeneration: UInt64 = 0
    private var authorizationOperationGeneration: UInt64 = 0
    private var persistenceWriteGeneration: UInt64 = 0

    private var isCheckInProgress = false
    private var hasPendingCheck = false
    private var isSavingConfiguration = false
    private var activeConfigurationSave: UInt64?
    private var needsPersistenceWrite = false
    private var activePersistenceWrite: UInt64?

    private var checkTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var snapshotContinuations: [UUID: AsyncStream<MonitoringSnapshot>.Continuation] = [:]

    init(
        diskReader: any StartupVolumeReader,
        repository: any MonitoringStateRepository,
        notificationService: any MonitoringNotificationService,
        scheduler: any MonitoringScheduler,
        wallClock: any MonitoringWallClock,
        wakeEventSource: any MonitoringWakeEventSource
    ) {
        self.diskReader = diskReader
        self.repository = SerializedMonitoringStateRepository(repository: repository)
        self.notificationService = notificationService
        self.scheduler = scheduler
        self.wallClock = wallClock
        self.wakeEventSource = wakeEventSource
    }

    func currentSnapshot() -> MonitoringSnapshot {
        makeSnapshot()
    }

    func snapshots() -> AsyncStream<MonitoringSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: MonitoringSnapshot.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.removeSnapshotContinuation(id: id)
            }
        }
        snapshotContinuations[id] = continuation
        continuation.yield(makeSnapshot())
        return stream
    }

    func start() async {
        guard lifecycleState == .stopped else {
            return
        }

        runtimeGeneration &+= 1
        let generation = runtimeGeneration
        resetTransientStateForStart()
        lifecycleState = .starting
        publishSnapshot()

        let restoredState: StoredMonitoringState
        do {
            restoredState = try await repository.load()
        } catch {
            guard isCurrent(generation: generation, lifecycle: .starting) else {
                return
            }
            lifecycleState = .stopped
            persistenceFailure = .load
            publishSnapshot()
            return
        }

        guard isCurrent(generation: generation, lifecycle: .starting) else {
            return
        }
        storedState = restoredState
        configurationRevision &+= 1
        durableRevision &+= 1
        persistenceFailure = nil

        do {
            let state = try await notificationService.authorizationState()
            guard isCurrent(generation: generation, lifecycle: .starting) else {
                return
            }
            notificationAuthorizationState = state
            notificationFailure = nil
        } catch {
            guard isCurrent(generation: generation, lifecycle: .starting) else {
                return
            }
            notificationAuthorizationState = .unknown
            notificationFailure = .authorizationStatus
        }

        let wakeEvents = await wakeEventSource.events()
        guard isCurrent(generation: generation, lifecycle: .starting) else {
            return
        }

        lifecycleState = .running
        startWakeTask(events: wakeEvents, generation: generation)
        publishSnapshot()
        requestImmediateCheck()
    }

    func stop() {
        guard lifecycleState != .stopped || checkTask != nil || scheduleTask != nil || wakeTask != nil else {
            return
        }

        runtimeGeneration &+= 1
        scheduleGeneration &+= 1
        lifecycleState = .stopped
        checkTask?.cancel()
        checkTask = nil
        scheduleTask?.cancel()
        scheduleTask = nil
        wakeTask?.cancel()
        wakeTask = nil
        activeConfigurationSave = nil
        isSavingConfiguration = false
        isCheckInProgress = false
        hasPendingCheck = false
        nextScheduledCheckAt = nil
        publishSnapshot()
    }

    func checkNow() {
        requestImmediateCheck()
    }

    func saveConfiguration(
        _ configuration: MonitoringConfiguration
    ) async -> MonitoringConfigurationSaveOutcome {
        guard lifecycleState == .running else {
            return .notRunning
        }
        guard activeConfigurationSave == nil else {
            return .alreadySaving
        }

        configurationSaveGeneration &+= 1
        let saveGeneration = configurationSaveGeneration
        let generation = runtimeGeneration
        let candidateRevision = durableRevision
        let candidate = StoredMonitoringState(
            configuration: configuration,
            notificationEpisodeState: storedState.notificationEpisodeState,
            hasCompletedOnboarding: storedState.hasCompletedOnboarding
        )
        activeConfigurationSave = saveGeneration
        isSavingConfiguration = true
        publishSnapshot()

        do {
            try await repository.save(candidate)
        } catch {
            guard
                isCurrentConfigurationSave(
                    generation: generation,
                    saveGeneration: saveGeneration
                )
            else {
                return .notRunning
            }
            activeConfigurationSave = nil
            isSavingConfiguration = false
            persistenceFailure = .configurationSave
            await persistLatestStateIfNeeded(generation: generation)
            guard isCurrent(generation: generation, lifecycle: .running) else {
                return .notRunning
            }
            publishSnapshot()
            return .failed
        }

        guard
            isCurrentConfigurationSave(
                generation: generation,
                saveGeneration: saveGeneration
            )
        else {
            return .notRunning
        }

        let durableStateChangedWhileSaving = durableRevision != candidateRevision
        storedState = StoredMonitoringState(
            configuration: configuration,
            notificationEpisodeState: storedState.notificationEpisodeState,
            hasCompletedOnboarding: storedState.hasCompletedOnboarding
        )
        configurationRevision &+= 1
        durableRevision &+= 1
        needsPersistenceWrite = durableStateChangedWhileSaving
        activeConfigurationSave = nil
        isSavingConfiguration = false
        persistenceFailure = nil
        await persistLatestStateIfNeeded(generation: generation)
        guard isCurrent(generation: generation, lifecycle: .running) else {
            return .notRunning
        }
        requestImmediateCheck()
        publishSnapshot()
        return .saved
    }

    func requestNotificationAuthorization() async {
        guard lifecycleState == .running else {
            return
        }

        let generation = runtimeGeneration
        authorizationOperationGeneration &+= 1
        let operationGeneration = authorizationOperationGeneration
        let previousState = notificationAuthorizationState
        do {
            let state = try await notificationService.requestAuthorization()
            guard
                isCurrentAuthorizationOperation(
                    generation: generation,
                    operationGeneration: operationGeneration
                )
            else {
                return
            }
            notificationAuthorizationState = state
            notificationFailure = nil
            if state == .authorized, previousState != .authorized {
                requestImmediateCheck()
            }
        } catch {
            guard
                isCurrentAuthorizationOperation(
                    generation: generation,
                    operationGeneration: operationGeneration
                )
            else {
                return
            }
            notificationFailure = .authorizationRequest
        }
        publishSnapshot()
    }

    func refreshNotificationAuthorization() async {
        guard lifecycleState == .running else {
            return
        }

        let generation = runtimeGeneration
        authorizationOperationGeneration &+= 1
        let operationGeneration = authorizationOperationGeneration
        let previousState = notificationAuthorizationState
        do {
            let state = try await notificationService.authorizationState()
            guard
                isCurrentAuthorizationOperation(
                    generation: generation,
                    operationGeneration: operationGeneration
                )
            else {
                return
            }
            notificationAuthorizationState = state
            notificationFailure = nil
            if state == .authorized, previousState != .authorized {
                requestImmediateCheck()
            }
        } catch {
            guard
                isCurrentAuthorizationOperation(
                    generation: generation,
                    operationGeneration: operationGeneration
                )
            else {
                return
            }
            notificationFailure = .authorizationStatus
        }
        publishSnapshot()
    }

    func completeOnboarding() async {
        guard lifecycleState == .running, !storedState.hasCompletedOnboarding else {
            return
        }

        let generation = runtimeGeneration
        storedState = StoredMonitoringState(
            configuration: storedState.configuration,
            notificationEpisodeState: storedState.notificationEpisodeState,
            hasCompletedOnboarding: true
        )
        durableStateDidChange()
        publishSnapshot()
        await persistLatestStateIfNeeded(generation: generation)
    }

    private func requestImmediateCheck() {
        guard lifecycleState == .running else {
            return
        }

        cancelScheduledCheck()
        if isCheckInProgress {
            hasPendingCheck = true
            publishSnapshot()
            return
        }

        isCheckInProgress = true
        hasPendingCheck = false
        let generation = runtimeGeneration
        checkTask = Task { [weak self] in
            await self?.runCheckLoop(generation: generation)
        }
        publishSnapshot()
    }

    private func runCheckLoop(generation: UInt64) async {
        while isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled {
            hasPendingCheck = false
            let result = await performCheck(generation: generation)
            guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
                return
            }

            let completedAt = await wallClock.now()
            guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
                return
            }

            record(result: result, completedAt: completedAt)
            publishSnapshot()
            if hasPendingCheck {
                continue
            }

            isCheckInProgress = false
            checkTask = nil
            installScheduledCheck(after: completedAt, generation: generation)
            publishSnapshot()
            return
        }
    }

    private func performCheck(generation: UInt64) async -> CheckResult {
        await persistLatestStateIfNeeded(generation: generation)
        guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
            return .discarded
        }

        let checkConfigurationRevision = configurationRevision
        let configuration = storedState.configuration
        let authorizationState = notificationAuthorizationState
        let reading = await diskReader.readStartupVolume()
        guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
            return .discarded
        }
        guard checkConfigurationRevision == configurationRevision else {
            return .discarded
        }

        let evaluation = LowSpaceNotificationPolicy.evaluate(
            reading: reading,
            threshold: configuration.threshold,
            episodeState: storedState.notificationEpisodeState
        )

        if evaluation.nextEpisodeState != storedState.notificationEpisodeState {
            setEpisodeState(evaluation.nextEpisodeState)
            await persistLatestStateIfNeeded(generation: generation)
            guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
                return .discarded
            }
        }

        if case .submit(let candidate) = evaluation.notificationDirective,
            authorizationState == .authorized
        {
            do {
                try await notificationService.submit(candidate)
                guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
                    return .discarded
                }
                notificationFailure = nil
                setEpisodeState(candidate.episodeState(after: .accepted))
                await persistLatestStateIfNeeded(generation: generation)
                guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
                    return .discarded
                }
            } catch {
                guard isCurrent(generation: generation, lifecycle: .running), !Task.isCancelled else {
                    return .discarded
                }
                notificationFailure = .submission
            }
        } else if notificationFailure == .submission {
            notificationFailure = nil
        }

        return result(
            for: reading,
            originalAssessment: evaluation.assessment
        )
    }

    private func result(
        for reading: DiskSpaceReading,
        originalAssessment: DiskSpaceAssessment
    ) -> CheckResult {
        switch reading {
        case .failed(let failure):
            return .recorded(assessment: .unavailable(failure), successfulVolume: nil)
        case .available(let startupVolume):
            return .recorded(
                assessment: originalAssessment,
                successfulVolume: startupVolume
            )
        }
    }

    private func record(result: CheckResult, completedAt: Date) {
        guard case .recorded(let assessment, let successfulVolume) = result else {
            return
        }

        if let successfulVolume {
            latestAssessment = .available(
                startupVolume: successfulVolume,
                relationship: successfulVolume.availableCapacity.relationship(
                    to: storedState.configuration.threshold
                )
            )
            latestSuccessfulVolume = successfulVolume
            lastSuccessfulCheckAt = completedAt
        } else {
            latestAssessment = assessment
        }
    }

    private func setEpisodeState(_ episodeState: NotificationEpisodeState) {
        guard storedState.notificationEpisodeState != episodeState else {
            return
        }

        storedState = StoredMonitoringState(
            configuration: storedState.configuration,
            notificationEpisodeState: episodeState,
            hasCompletedOnboarding: storedState.hasCompletedOnboarding
        )
        durableStateDidChange()
    }

    private func durableStateDidChange() {
        durableRevision &+= 1
        needsPersistenceWrite = true
    }

    private func persistLatestStateIfNeeded(generation: UInt64) async {
        guard isCurrent(generation: generation, lifecycle: .running) else {
            return
        }
        guard activeConfigurationSave == nil, needsPersistenceWrite else {
            return
        }
        guard activePersistenceWrite == nil else {
            return
        }

        persistenceWriteGeneration &+= 1
        let writeGeneration = persistenceWriteGeneration
        activePersistenceWrite = writeGeneration
        defer {
            if activePersistenceWrite == writeGeneration {
                activePersistenceWrite = nil
            }
        }

        while isCurrent(generation: generation, lifecycle: .running),
            activeConfigurationSave == nil, needsPersistenceWrite, !Task.isCancelled
        {
            let revision = durableRevision
            let state = storedState
            needsPersistenceWrite = false
            do {
                try await repository.save(state)
                guard isCurrent(generation: generation, lifecycle: .running) else {
                    return
                }
                if revision == durableRevision {
                    needsPersistenceWrite = false
                    if persistenceFailure == .save {
                        persistenceFailure = nil
                    }
                } else {
                    needsPersistenceWrite = true
                }
            } catch {
                guard isCurrent(generation: generation, lifecycle: .running) else {
                    return
                }
                if revision == durableRevision {
                    needsPersistenceWrite = true
                    persistenceFailure = .save
                    publishSnapshot()
                    return
                }
                needsPersistenceWrite = true
            }
        }
    }

    private func installScheduledCheck(after completedAt: Date, generation: UInt64) {
        guard isCurrent(generation: generation, lifecycle: .running) else {
            return
        }

        scheduleGeneration &+= 1
        let currentScheduleGeneration = scheduleGeneration
        let interval = storedState.configuration.interval
        nextScheduledCheckAt = completedAt.addingTimeInterval(TimeInterval(interval.rawValue))
        let scheduler = scheduler
        scheduleTask = Task { [weak self] in
            do {
                try await scheduler.sleep(for: interval.duration)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            await self?.scheduledCheckFired(
                generation: generation,
                scheduleGeneration: currentScheduleGeneration
            )
        }
    }

    private func cancelScheduledCheck() {
        scheduleGeneration &+= 1
        scheduleTask?.cancel()
        scheduleTask = nil
        nextScheduledCheckAt = nil
    }

    private func scheduledCheckFired(
        generation: UInt64,
        scheduleGeneration: UInt64
    ) {
        guard isCurrent(generation: generation, lifecycle: .running),
            scheduleGeneration == self.scheduleGeneration
        else {
            return
        }

        scheduleTask = nil
        nextScheduledCheckAt = nil
        requestImmediateCheck()
    }

    private func startWakeTask(events: AsyncStream<Void>, generation: UInt64) {
        wakeTask = Task { [weak self] in
            for await _ in events {
                guard !Task.isCancelled else {
                    return
                }
                await self?.wakeReceived(generation: generation)
            }
        }
    }

    private func wakeReceived(generation: UInt64) {
        guard isCurrent(generation: generation, lifecycle: .running) else {
            return
        }
        requestImmediateCheck()
    }

    private func resetTransientStateForStart() {
        checkTask?.cancel()
        scheduleTask?.cancel()
        wakeTask?.cancel()
        checkTask = nil
        scheduleTask = nil
        wakeTask = nil
        isCheckInProgress = false
        hasPendingCheck = false
        isSavingConfiguration = false
        activeConfigurationSave = nil
        needsPersistenceWrite = false
        activePersistenceWrite = nil
        notificationAuthorizationState = .unknown
        persistenceFailure = nil
        notificationFailure = nil
        latestSuccessfulVolume = nil
        latestAssessment = nil
        lastSuccessfulCheckAt = nil
        nextScheduledCheckAt = nil
    }

    private func isCurrent(
        generation: UInt64,
        lifecycle: MonitoringLifecycleState
    ) -> Bool {
        runtimeGeneration == generation && lifecycleState == lifecycle
    }

    private func isCurrentConfigurationSave(
        generation: UInt64,
        saveGeneration: UInt64
    ) -> Bool {
        isCurrent(generation: generation, lifecycle: .running)
            && activeConfigurationSave == saveGeneration
    }

    private func isCurrentAuthorizationOperation(
        generation: UInt64,
        operationGeneration: UInt64
    ) -> Bool {
        isCurrent(generation: generation, lifecycle: .running)
            && authorizationOperationGeneration == operationGeneration
    }

    private func makeSnapshot() -> MonitoringSnapshot {
        MonitoringSnapshot(
            lifecycleState: lifecycleState,
            configuration: storedState.configuration,
            notificationEpisodeState: storedState.notificationEpisodeState,
            hasCompletedOnboarding: storedState.hasCompletedOnboarding,
            notificationAuthorizationState: notificationAuthorizationState,
            isCheckInProgress: isCheckInProgress,
            isSavingConfiguration: isSavingConfiguration,
            latestSuccessfulVolume: latestSuccessfulVolume,
            latestAssessment: latestAssessment,
            lastSuccessfulCheckAt: lastSuccessfulCheckAt,
            nextScheduledCheckAt: nextScheduledCheckAt,
            persistenceFailure: persistenceFailure,
            notificationFailure: notificationFailure
        )
    }

    private func publishSnapshot() {
        let snapshot = makeSnapshot()
        for continuation in snapshotContinuations.values {
            continuation.yield(snapshot)
        }
    }

    private func removeSnapshotContinuation(id: UUID) {
        snapshotContinuations[id] = nil
    }

    private enum CheckResult {
        case discarded
        case recorded(
            assessment: DiskSpaceAssessment,
            successfulVolume: StartupVolumeSnapshot?
        )
    }
}

private actor SerializedMonitoringStateRepository {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let repository: any MonitoringStateRepository
    private var isLocked = false
    private var waiters: [Waiter] = []

    init(repository: any MonitoringStateRepository) {
        self.repository = repository
    }

    func load() async throws -> StoredMonitoringState {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await repository.load()
    }

    func save(_ state: StoredMonitoringState) async throws {
        try await acquire()
        defer { release() }
        try Task.checkCancellation()
        try await repository.save(state)
    }

    private func acquire() async throws {
        try Task.checkCancellation()
        if !isLocked {
            isLocked = true
            return
        }

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: id)
            }
        }
    }

    private func release() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
