import Foundation
import XCTest

@testable import DiskMeerkatApp

@MainActor
final class DiskMeerkatApplicationControllerTests: XCTestCase {
    func testOneControllerStartsAndStopsOneRuntimeWithoutDuplicateWork() async throws {
        let fixture = try makeFixture(hasCompletedOnboarding: false)
        let repository = try XCTUnwrap(fixture.testRepository)

        let firstDisposition = await fixture.controller.start()
        let repeatedDisposition = await fixture.controller.start()
        await fixture.scheduler.waitForSleepCount(1)

        XCTAssertEqual(firstDisposition, .showStatus)
        XCTAssertEqual(repeatedDisposition, .none)
        await assertEqual(await repository.loadCount, 1)
        await assertEqual(await fixture.diskReader.counts().read, 1)
        await assertEqual(await fixture.scheduler.pendingSleepCount(), 1)

        await fixture.controller.stop()
        await waitUntil {
            await fixture.scheduler.pendingSleepCount() == 0
        }

        await assertEqual(
            await fixture.runtime.currentSnapshot().lifecycleState,
            .stopped
        )
        await assertEqual(await fixture.scheduler.pendingSleepCount(), 0)
    }

    func testCompletedOnboardingSuppressesAutomaticStatusPresentation() async throws {
        let fixture = try makeFixture(hasCompletedOnboarding: true)

        await assertEqual(await fixture.controller.start(), .none)
        await fixture.controller.stop()
    }

    func testStatusWindowClosePersistsOnboardingWithoutRequestingPermission() async throws {
        let fixture = try makeFixture(hasCompletedOnboarding: false)
        let repository = try XCTUnwrap(fixture.testRepository)
        _ = await fixture.controller.start()

        fixture.controller.statusWindowDidClose()
        await repository.waitForSaveCount(1)

        await assertTrue(await repository.savedState().hasCompletedOnboarding)
        await assertEqual(await fixture.notifications.requestCount(), 0)
        await assertEqual(await fixture.diskReader.counts().read, 1)
        await fixture.controller.stop()
    }

    func testStopDuringStartWaitsForDismissalAndRejectsLatePresentation() async throws {
        let state = StoredMonitoringState(
            configuration: .defaultValue,
            notificationEpisodeState: .armed,
            hasCompletedOnboarding: false
        )
        let repository = SuspendedLoadMonitoringStateRepository(state: state)
        let fixture = try makeFixture(repository: repository)
        let start = Task { await fixture.controller.start() }
        await repository.waitForLoad()

        fixture.controller.statusWindowDidClose()
        let stop = Task { await fixture.controller.stop() }
        await repository.resumeLoad()

        await assertEqual(await start.value, .none)
        await stop.value
        await repository.waitForSaveCount(1)
        await assertTrue(await repository.savedState().hasCompletedOnboarding)
        await assertEqual(
            await fixture.runtime.currentSnapshot().lifecycleState,
            .stopped
        )
    }

    func testDebugFixturesReachTheirControlledPresentationStates() async {
        let expectations: [(DiskMeerkatApplicationFixture, DiskMeerkatStartupDisposition)] = [
            (.firstRun, .showStatus),
            (.healthy, .none),
            (.permissionDenied, .none),
            (.readFailure, .none),
        ]

        for (fixture, expectedDisposition) in expectations {
            let controller = DiskMeerkatApplicationController(
                fixture: fixture,
                openNotificationSettings: {}
            )
            await assertEqual(await controller.start(), expectedDisposition)
            await waitUntil {
                switch fixture {
                case .firstRun, .healthy, .permissionDenied:
                    controller.model.snapshot.latestSuccessfulVolume != nil
                case .readFailure:
                    controller.model.snapshot.latestAssessment == .unavailable(.unavailable)
                }
            }

            switch fixture {
            case .firstRun:
                XCTAssertTrue(controller.model.presentation.shouldShowOnboarding)
                XCTAssertEqual(
                    controller.model.presentation.notificationPermission.kind,
                    .notDetermined
                )
            case .healthy:
                XCTAssertEqual(controller.model.presentation.headline, .monitoring)
                XCTAssertEqual(
                    controller.model.presentation.notificationPermission.kind,
                    .authorized
                )
            case .permissionDenied:
                XCTAssertEqual(
                    controller.model.presentation.notificationPermission.kind,
                    .denied
                )
            case .readFailure:
                XCTAssertEqual(controller.model.presentation.headline, .readFailed)
                XCTAssertEqual(
                    controller.model.presentation.availableSpaceText,
                    controller.model.localization.availableSpaceUnavailable
                )
            }
            await controller.stop()
        }
    }

    private func makeFixture(
        hasCompletedOnboarding: Bool
    ) throws -> ApplicationControllerFixture {
        let state = StoredMonitoringState(
            configuration: .defaultValue,
            notificationEpisodeState: .armed,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
        let repository = TestMonitoringStateRepository(state: state)
        var fixture = try makeFixture(repository: repository)
        fixture.testRepository = repository
        return fixture
    }

    private func makeFixture(
        repository: any MonitoringStateRepository
    ) throws -> ApplicationControllerFixture {
        let diskReader = TestStartupVolumeReader(
            readings: [
                .available(
                    StartupVolumeSnapshot(
                        availableCapacity: try DiskCapacity(bytes: 82_400_000_000),
                        volumeName: "Macintosh HD"
                    )
                )
            ]
        )
        let notifications = TestMonitoringNotificationService(state: .notDetermined)
        let scheduler = TestMonitoringScheduler()
        let runtime = MonitoringRuntime(
            diskReader: diskReader,
            repository: repository,
            notificationService: notifications,
            scheduler: scheduler,
            wallClock: TestMonitoringWallClock(),
            wakeEventSource: TestMonitoringWakeEventSource()
        )
        let controller = DiskMeerkatApplicationController(
            runtime: runtime,
            launchAtLoginService: TestApplicationLaunchAtLoginService(),
            locale: Locale(identifier: "en_US"),
            openNotificationSettings: {}
        )
        return ApplicationControllerFixture(
            controller: controller,
            runtime: runtime,
            diskReader: diskReader,
            notifications: notifications,
            scheduler: scheduler,
            testRepository: nil
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Condition was not met", file: file, line: line)
    }
}

private struct ApplicationControllerFixture {
    let controller: DiskMeerkatApplicationController
    let runtime: MonitoringRuntime
    let diskReader: TestStartupVolumeReader
    let notifications: TestMonitoringNotificationService
    let scheduler: TestMonitoringScheduler
    var testRepository: TestMonitoringStateRepository?
}

private actor TestApplicationLaunchAtLoginService: LaunchAtLoginService {
    func refresh() async -> LaunchAtLoginSnapshot {
        LaunchAtLoginSnapshot(actualState: .disabled, problem: nil)
    }

    func setEnabled(_ isEnabled: Bool) async -> LaunchAtLoginSnapshot {
        LaunchAtLoginSnapshot(actualState: isEnabled ? .enabled : .disabled, problem: nil)
    }

    func openSystemSettings() async {}
}

private actor SuspendedLoadMonitoringStateRepository: MonitoringStateRepository {
    private var state: StoredMonitoringState
    private var loadContinuation: CheckedContinuation<StoredMonitoringState, Never>?
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []
    private var saveWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var savedStates: [StoredMonitoringState] = []

    init(state: StoredMonitoringState) {
        self.state = state
    }

    func load() async throws -> StoredMonitoringState {
        let waiters = loadWaiters
        loadWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        return await withCheckedContinuation { continuation in
            loadContinuation = continuation
        }
    }

    func save(_ state: StoredMonitoringState) async throws {
        self.state = state
        savedStates.append(state)
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for (expectedCount, continuation) in saveWaiters {
            if savedStates.count >= expectedCount {
                continuation.resume()
            } else {
                remaining.append((expectedCount, continuation))
            }
        }
        saveWaiters = remaining
    }

    func waitForLoad() async {
        guard loadContinuation == nil else {
            return
        }
        await withCheckedContinuation { continuation in
            loadWaiters.append(continuation)
        }
    }

    func resumeLoad() {
        loadContinuation?.resume(returning: state)
        loadContinuation = nil
    }

    func waitForSaveCount(_ expectedCount: Int) async {
        guard savedStates.count < expectedCount else {
            return
        }
        await withCheckedContinuation { continuation in
            saveWaiters.append((expectedCount, continuation))
        }
    }

    func savedState() -> StoredMonitoringState {
        state
    }
}

@MainActor
private func assertEqual<T: Equatable>(
    _ expression: @autoclosure () async -> T,
    _ expected: T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let value = await expression()
    XCTAssertEqual(value, expected, file: file, line: line)
}

@MainActor
private func assertTrue(
    _ expression: @autoclosure () async -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let value = await expression()
    XCTAssertTrue(value, file: file, line: line)
}
