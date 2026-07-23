import Foundation

public enum DiskMeerkatStartupDisposition: Equatable, Sendable {
    case none
    case showStatus
}

@MainActor
public final class DiskMeerkatApplicationController {
    public let model: DiskMeerkatPresentationModel

    private let runtime: MonitoringRuntime
    private var lifecycleState = LifecycleState.stopped
    private var lifecycleGeneration: UInt64 = 0
    private var runtimeStartTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var onboardingCompletionRequested = false
    private var onboardingCompletionTask: Task<Void, Never>?

    public convenience init(
        openNotificationSettings: @escaping @MainActor @Sendable () async -> Void
    ) {
        let runtime = MonitoringRuntime(
            diskReader: FoundationStartupVolumeReader(),
            repository: UserDefaultsMonitoringStateRepository(),
            notificationService: UserNotificationsMonitoringService(),
            scheduler: SuspendingMonitoringScheduler(),
            wallClock: SystemMonitoringWallClock(),
            wakeEventSource: WorkspaceWakeEventSource()
        )
        self.init(
            runtime: runtime,
            launchAtLoginService: MainAppLaunchAtLoginService(),
            openNotificationSettings: openNotificationSettings
        )
    }

    init(
        runtime: MonitoringRuntime,
        launchAtLoginService: any LaunchAtLoginService,
        locale: Locale = .autoupdatingCurrent,
        localization: DiskMeerkatLocalization = .current,
        openNotificationSettings: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.runtime = runtime
        model = DiskMeerkatPresentationModel(
            snapshot: Self.initialSnapshot,
            runtimeClient: MonitoringRuntimePresentationClient(runtime: runtime),
            launchAtLoginService: launchAtLoginService,
            locale: locale,
            localization: localization,
            openNotificationSettings: openNotificationSettings
        )
    }

    public func start() async -> DiskMeerkatStartupDisposition {
        guard lifecycleState == .stopped else {
            return .none
        }

        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        lifecycleState = .starting
        let task = Task { [runtime] in
            await runtime.start()
        }
        runtimeStartTask = task
        await task.value

        guard lifecycleGeneration == generation, lifecycleState == .starting else {
            return .none
        }

        lifecycleState = .started
        if onboardingCompletionRequested {
            beginOnboardingCompletionIfNeeded()
            await onboardingCompletionTask?.value
        }

        guard lifecycleGeneration == generation, lifecycleState == .started else {
            return .none
        }

        let snapshot = await runtime.currentSnapshot()
        guard lifecycleGeneration == generation, lifecycleState == .started else {
            return .none
        }
        return snapshot.hasCompletedOnboarding ? .none : .showStatus
    }

    public func statusWindowDidClose() {
        guard !onboardingCompletionRequested else {
            return
        }
        onboardingCompletionRequested = true
        beginOnboardingCompletionIfNeeded()
    }

    public func stop() async {
        if let stopTask {
            await stopTask.value
            return
        }
        guard lifecycleState != .stopped else {
            return
        }

        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        lifecycleState = .stopping
        let startTask = runtimeStartTask
        let completionTask = onboardingCompletionTask
        let shouldCompleteOnboarding = onboardingCompletionRequested
        let runtime = runtime
        let task = Task {
            await startTask?.value
            if let completionTask {
                await completionTask.value
            } else if shouldCompleteOnboarding {
                await runtime.completeOnboarding()
            }
            await runtime.stop()
        }
        stopTask = task
        await task.value

        guard lifecycleGeneration == generation else {
            return
        }
        lifecycleState = .stopped
        runtimeStartTask = nil
        stopTask = nil
    }

    private func beginOnboardingCompletionIfNeeded() {
        guard lifecycleState == .started, onboardingCompletionTask == nil else {
            return
        }
        onboardingCompletionTask = Task { [runtime] in
            await runtime.completeOnboarding()
        }
    }

    private static let initialSnapshot = MonitoringSnapshot(
        lifecycleState: .stopped,
        configuration: .defaultValue,
        notificationEpisodeState: .armed,
        hasCompletedOnboarding: false,
        notificationAuthorizationState: .unknown,
        isCheckInProgress: false,
        isSavingConfiguration: false,
        latestSuccessfulVolume: nil,
        latestAssessment: nil,
        lastSuccessfulCheckAt: nil,
        nextScheduledCheckAt: nil,
        persistenceFailure: nil,
        notificationFailure: nil
    )

    private enum LifecycleState {
        case stopped
        case starting
        case started
        case stopping
    }
}

#if DEBUG
    public enum DiskMeerkatApplicationFixture: String, Sendable {
        case firstRun = "first-run"
        case healthy
        case permissionDenied = "permission-denied"
        case readFailure = "read-failure"
    }

    extension DiskMeerkatApplicationController {
        public convenience init(
            fixture: DiskMeerkatApplicationFixture,
            openNotificationSettings: @escaping @MainActor @Sendable () async -> Void
        ) {
            let fixtureValues = FixtureValues(fixture: fixture)
            let runtime = MonitoringRuntime(
                diskReader: FixtureStartupVolumeReader(reading: fixtureValues.reading),
                repository: FixtureMonitoringStateRepository(state: fixtureValues.storedState),
                notificationService: FixtureMonitoringNotificationService(
                    state: fixtureValues.notificationAuthorizationState
                ),
                scheduler: FixtureMonitoringScheduler(),
                wallClock: FixtureMonitoringWallClock(now: Date.now),
                wakeEventSource: FixtureMonitoringWakeEventSource()
            )
            self.init(
                runtime: runtime,
                launchAtLoginService: FixtureLaunchAtLoginService(),
                locale: Locale(identifier: "en_US"),
                openNotificationSettings: openNotificationSettings
            )
        }
    }

    private struct FixtureValues {
        let reading: DiskSpaceReading
        let storedState: StoredMonitoringState
        let notificationAuthorizationState: NotificationAuthorizationState

        init(fixture: DiskMeerkatApplicationFixture) {
            let hasCompletedOnboarding: Bool
            switch fixture {
            case .firstRun:
                hasCompletedOnboarding = false
                notificationAuthorizationState = .notDetermined
                reading = Self.healthyReading
            case .healthy:
                hasCompletedOnboarding = true
                notificationAuthorizationState = .authorized
                reading = Self.healthyReading
            case .permissionDenied:
                hasCompletedOnboarding = true
                notificationAuthorizationState = .denied
                reading = Self.healthyReading
            case .readFailure:
                hasCompletedOnboarding = true
                notificationAuthorizationState = .authorized
                reading = .failed(.unavailable)
            }
            storedState = StoredMonitoringState(
                configuration: .defaultValue,
                notificationEpisodeState: .armed,
                hasCompletedOnboarding: hasCompletedOnboarding
            )
        }

        private static let healthyReading = DiskSpaceReading.available(
            StartupVolumeSnapshot(
                availableCapacity: try! DiskCapacity(bytes: 82_400_000_000),
                volumeName: "Macintosh HD"
            )
        )
    }

    private actor FixtureStartupVolumeReader: StartupVolumeReader {
        private let reading: DiskSpaceReading

        init(reading: DiskSpaceReading) {
            self.reading = reading
        }

        func readStartupVolume() async -> DiskSpaceReading {
            reading
        }
    }

    private actor FixtureMonitoringStateRepository: MonitoringStateRepository {
        private var state: StoredMonitoringState

        init(state: StoredMonitoringState) {
            self.state = state
        }

        func load() async throws -> StoredMonitoringState {
            state
        }

        func save(_ state: StoredMonitoringState) async throws {
            self.state = state
        }
    }

    private actor FixtureMonitoringNotificationService: MonitoringNotificationService {
        private var state: NotificationAuthorizationState

        init(state: NotificationAuthorizationState) {
            self.state = state
        }

        func authorizationState() async throws -> NotificationAuthorizationState {
            state
        }

        func requestAuthorization() async throws -> NotificationAuthorizationState {
            if state == .notDetermined {
                state = .authorized
            }
            return state
        }

        func removeDeliveredLowSpaceNotification() async {}

        func submit(_ candidate: LowSpaceNotificationCandidate) async throws {}
    }

    private actor FixtureMonitoringScheduler: MonitoringScheduler {
        private struct PendingSleep {
            let id: UUID
            let continuation: CheckedContinuation<Void, any Error>
        }

        private var pendingSleeps: [PendingSleep] = []

        func sleep(for duration: Duration) async throws {
            let id = UUID()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, any Error>) in
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        pendingSleeps.append(PendingSleep(id: id, continuation: continuation))
                    }
                }
            } onCancel: {
                Task {
                    await self.cancel(id: id)
                }
            }
        }

        private func cancel(id: UUID) {
            guard let index = pendingSleeps.firstIndex(where: { $0.id == id }) else {
                return
            }
            pendingSleeps.remove(at: index).continuation.resume(
                throwing: CancellationError()
            )
        }
    }

    private struct FixtureMonitoringWallClock: MonitoringWallClock {
        let now: Date

        func now() async -> Date {
            now
        }
    }

    private actor FixtureMonitoringWakeEventSource: MonitoringWakeEventSource {
        func events() async -> AsyncStream<Void> {
            AsyncStream { _ in }
        }
    }

    private actor FixtureLaunchAtLoginService: LaunchAtLoginService {
        private var state = LaunchAtLoginActualState.disabled

        func refresh() async -> LaunchAtLoginSnapshot {
            LaunchAtLoginSnapshot(actualState: state, problem: nil)
        }

        func setEnabled(_ isEnabled: Bool) async -> LaunchAtLoginSnapshot {
            state = isEnabled ? .enabled : .disabled
            return LaunchAtLoginSnapshot(actualState: state, problem: nil)
        }

        func openSystemSettings() async {}
    }
#endif
