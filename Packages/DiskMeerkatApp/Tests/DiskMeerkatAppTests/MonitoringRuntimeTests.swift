import Foundation
import XCTest

@testable import DiskMeerkatApp

final class MonitoringRuntimeTests: XCTestCase {
    func testStartRestoresSuppressionAndSchedulesFromCompletion() async throws {
        let threshold = try LowSpaceThreshold(gigabytes: 100)
        let restoredState = StoredMonitoringState(
            configuration: MonitoringConfiguration(
                threshold: threshold,
                interval: .oneHour
            ),
            notificationEpisodeState: .suppressed,
            hasCompletedOnboarding: true
        )
        let volume = try startupVolume(gigabytes: 90)
        let completedAt = Date(timeIntervalSince1970: 10_000)
        let fixture = makeFixture(
            state: restoredState,
            authorization: .authorized,
            readings: [.available(volume)],
            dates: [completedAt]
        )

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)

        let snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.lifecycleState, .running)
        XCTAssertEqual(snapshot.configuration, restoredState.configuration)
        XCTAssertEqual(snapshot.notificationEpisodeState, .suppressed)
        XCTAssertTrue(snapshot.hasCompletedOnboarding)
        XCTAssertEqual(snapshot.latestSuccessfulVolume, volume)
        XCTAssertEqual(
            snapshot.latestAssessment,
            .available(startupVolume: volume, relationship: .below)
        )
        XCTAssertEqual(snapshot.lastSuccessfulCheckAt, completedAt)
        XCTAssertEqual(
            snapshot.nextScheduledCheckAt,
            completedAt.addingTimeInterval(3_600)
        )
        await assertEqual(await fixture.notifications.submissionCount(), 0)
        await assertEqual(await fixture.scheduler.durations(), [.seconds(3_600)])
    }

    func testActiveTriggersCoalesceIntoOneFollowUpBeforeScheduling() async throws {
        let firstVolume = try startupVolume(gigabytes: 30)
        let secondVolume = try startupVolume(gigabytes: 29)
        let fixture = makeFixture(
            dates: [
                Date(timeIntervalSince1970: 1_000),
                Date(timeIntervalSince1970: 2_000),
            ]
        )

        await fixture.runtime.start()
        await fixture.diskReader.waitForReadCount(1)
        await fixture.runtime.checkNow()
        await fixture.runtime.checkNow()
        await fixture.wakeEventSource.sendWake()

        var counts = await fixture.diskReader.counts()
        XCTAssertEqual(counts.read, 1)
        XCTAssertEqual(counts.maximumActive, 1)

        await fixture.diskReader.enqueue(.available(firstVolume))
        await fixture.diskReader.waitForReadCount(2)
        await assertEqual(await fixture.scheduler.durations(), [])

        await fixture.diskReader.enqueue(.available(secondVolume))
        await fixture.scheduler.waitForSleepCount(1)

        counts = await fixture.diskReader.counts()
        XCTAssertEqual(counts.read, 2)
        XCTAssertEqual(counts.maximumActive, 1)
        await assertEqual(await fixture.scheduler.durations(), [.seconds(900)])
        await assertEqual(
            await fixture.runtime.currentSnapshot().latestSuccessfulVolume,
            secondVolume
        )
    }

    func testAValidScheduleFireRunsOneCheckAndCreatesOneNewWait() async throws {
        let firstDate = Date(timeIntervalSince1970: 5_000)
        let secondDate = Date(timeIntervalSince1970: 8_000)
        let fixture = makeFixture(
            readings: [
                .available(try startupVolume(gigabytes: 30)),
                .available(try startupVolume(gigabytes: 29)),
            ],
            dates: [firstDate, secondDate]
        )

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        await fixture.scheduler.fireNext()
        await fixture.scheduler.waitForSleepCount(2)

        await assertEqual(await fixture.diskReader.counts().read, 2)
        await assertEqual(
            await fixture.scheduler.durations(),
            [.seconds(900), .seconds(900)]
        )
        await assertEqual(
            await fixture.runtime.currentSnapshot().nextScheduledCheckAt,
            secondDate.addingTimeInterval(900)
        )
    }

    func testConfigurationIsPersistedBeforeItAppliesAndReplacesTheSchedule() async throws {
        let fixture = makeFixture(
            readings: [
                .available(try startupVolume(gigabytes: 30)),
                .available(try startupVolume(gigabytes: 29)),
            ]
        )
        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        await fixture.repository.suspendNextSave()
        let configuration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 50),
            interval: .oneHour
        )

        let saveTask = Task {
            await fixture.runtime.saveConfiguration(configuration)
        }
        await fixture.repository.waitForSaveCount(1)

        var snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertTrue(snapshot.isSavingConfiguration)
        XCTAssertEqual(snapshot.configuration, .defaultValue)
        await assertEqual(await fixture.diskReader.counts().read, 1)

        await fixture.repository.completePendingSave(success: true)
        await assertEqual(await saveTask.value, .saved)
        await fixture.scheduler.waitForSleepCount(2)

        snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertFalse(snapshot.isSavingConfiguration)
        XCTAssertEqual(snapshot.configuration, configuration)
        XCTAssertEqual(snapshot.nextScheduledCheckAt?.timeIntervalSince1970, 4_600)
        await assertEqual(
            await fixture.scheduler.durations(),
            [.seconds(900), .seconds(3_600)]
        )
        await assertEqual(await fixture.repository.savedState().configuration, configuration)
    }

    func testConfigurationFailureKeepsThePreviousStateScheduleAndCheckCount() async throws {
        let fixture = makeFixture(
            readings: [.available(try startupVolume(gigabytes: 30))]
        )
        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        await fixture.repository.failNextSaves()
        let configuration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 50),
            interval: .oneHour
        )

        let outcome = await fixture.runtime.saveConfiguration(configuration)

        let snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(snapshot.configuration, .defaultValue)
        XCTAssertEqual(snapshot.persistenceFailure, .configurationSave)
        XCTAssertEqual(snapshot.nextScheduledCheckAt?.timeIntervalSince1970, 1_900)
        await assertEqual(await fixture.diskReader.counts().read, 1)
        await assertEqual(await fixture.scheduler.pendingSleepCount(), 1)
        await assertEqual(await fixture.scheduler.durations(), [.seconds(900)])
    }

    func testConfigurationCommittedDuringAReadDiscardsTheOldThresholdResult() async throws {
        let fixture = makeFixture(authorization: .authorized)
        await fixture.runtime.start()
        await fixture.diskReader.waitForReadCount(1)
        let newConfiguration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 10),
            interval: .fifteenMinutes
        )

        await assertEqual(
            await fixture.runtime.saveConfiguration(newConfiguration),
            .saved
        )
        let volume = try startupVolume(gigabytes: 15)
        await fixture.diskReader.enqueue(.available(volume))
        await fixture.diskReader.waitForReadCount(2)
        await fixture.diskReader.enqueue(.available(volume))
        await fixture.scheduler.waitForSleepCount(1)

        let snapshot = await fixture.runtime.currentSnapshot()
        await assertEqual(await fixture.notifications.submissionCount(), 0)
        XCTAssertEqual(snapshot.configuration, newConfiguration)
        XCTAssertEqual(
            snapshot.latestAssessment,
            .available(startupVolume: volume, relationship: .above)
        )
    }

    func testDeniedPermissionDoesNotCheckAndLaterGrantCoalescesOneCheck() async throws {
        let fixture = makeFixture(
            authorization: .notDetermined,
            readings: [
                .available(try startupVolume(gigabytes: 30)),
                .available(try startupVolume(gigabytes: 29)),
            ]
        )
        await fixture.notifications.setRequestedState(.denied)
        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)

        await fixture.runtime.requestNotificationAuthorization()
        await assertEqual(await fixture.diskReader.counts().read, 1)
        await assertEqual(
            await fixture.runtime.currentSnapshot().notificationAuthorizationState,
            .denied
        )

        await fixture.notifications.setAuthorizationState(.authorized)
        await fixture.runtime.refreshNotificationAuthorization()
        await fixture.scheduler.waitForSleepCount(2)

        await assertEqual(await fixture.notifications.requestCount(), 1)
        await assertEqual(await fixture.diskReader.counts().read, 2)
        await assertEqual(
            await fixture.runtime.currentSnapshot().notificationAuthorizationState,
            .authorized
        )
    }

    func testNotificationEpisodeSuppressesRearmsAndSubmitsAgain() async throws {
        let fixture = makeFixture(
            authorization: .authorized,
            readings: [
                .available(try startupVolume(gigabytes: 10)),
                .available(try startupVolume(gigabytes: 9)),
                .available(try startupVolume(gigabytes: 21)),
                .available(try startupVolume(gigabytes: 10)),
            ]
        )

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(2)
        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(3)
        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(4)

        let saves = await fixture.repository.saves()
        await assertEqual(await fixture.notifications.submissionCount(), 2)
        XCTAssertEqual(
            saves.map(\.notificationEpisodeState),
            [
                .suppressed,
                .armed,
                .suppressed,
            ])
        await assertEqual(
            await fixture.runtime.currentSnapshot().notificationEpisodeState,
            .suppressed
        )
    }

    func testSubmissionFailureStaysArmedAndRetriesOnALaterCheck() async throws {
        let fixture = makeFixture(
            authorization: .authorized,
            readings: [
                .available(try startupVolume(gigabytes: 10)),
                .available(try startupVolume(gigabytes: 9)),
            ]
        )
        await fixture.notifications.failNextSubmissions()

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        var snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.notificationEpisodeState, .armed)
        XCTAssertEqual(snapshot.notificationFailure, .submission)

        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(2)

        snapshot = await fixture.runtime.currentSnapshot()
        await assertEqual(await fixture.notifications.submissionCount(), 2)
        XCTAssertEqual(snapshot.notificationEpisodeState, .suppressed)
        XCTAssertNil(snapshot.notificationFailure)
        await assertEqual(await fixture.repository.saves().count, 1)
    }

    func testDiskFailureKeepsTheLastSuccessfulVolumeAndEpisodeState() async throws {
        let firstVolume = try startupVolume(gigabytes: 30)
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = Date(timeIntervalSince1970: 2_000)
        let fixture = makeFixture(
            readings: [
                .available(firstVolume),
                .failed(.unavailable),
            ],
            dates: [firstDate, secondDate]
        )

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(2)

        let snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.latestSuccessfulVolume, firstVolume)
        XCTAssertEqual(snapshot.latestAssessment, .unavailable(.unavailable))
        XCTAssertEqual(snapshot.lastSuccessfulCheckAt, firstDate)
        XCTAssertEqual(snapshot.notificationEpisodeState, .armed)
        await assertEqual(await fixture.notifications.submissionCount(), 0)
    }

    func testSuppressionPersistenceFailureNeverResubmitsAndRetriesUntilSaved() async throws {
        let fixture = makeFixture(
            authorization: .authorized,
            readings: [
                .available(try startupVolume(gigabytes: 10)),
                .available(try startupVolume(gigabytes: 9)),
                .available(try startupVolume(gigabytes: 8)),
            ]
        )
        await fixture.repository.failNextSaves(2)

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)
        var snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.notificationEpisodeState, .suppressed)
        XCTAssertEqual(snapshot.persistenceFailure, .save)

        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(2)
        snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.notificationEpisodeState, .suppressed)
        XCTAssertEqual(snapshot.persistenceFailure, .save)

        await fixture.runtime.checkNow()
        await fixture.scheduler.waitForSleepCount(3)
        snapshot = await fixture.runtime.currentSnapshot()
        await assertEqual(await fixture.notifications.submissionCount(), 1)
        await assertEqual(await fixture.repository.saves().count, 3)
        XCTAssertNil(snapshot.persistenceFailure)
        await assertEqual(
            await fixture.repository.savedState().notificationEpisodeState,
            .suppressed
        )
    }

    func testOnboardingCompletionPersistsWithoutRequestingACheck() async throws {
        let fixture = makeFixture(
            readings: [.available(try startupVolume(gigabytes: 30))]
        )
        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)

        await fixture.runtime.completeOnboarding()
        await fixture.repository.waitForSaveCount(1)

        await assertTrue(await fixture.runtime.currentSnapshot().hasCompletedOnboarding)
        await assertTrue(await fixture.repository.savedState().hasCompletedOnboarding)
        await assertEqual(await fixture.diskReader.counts().read, 1)
    }

    func testLoadFailureStaysStoppedAndASecondStartRetries() async throws {
        let fixture = makeFixture(
            loadFailures: 1,
            readings: [.available(try startupVolume(gigabytes: 30))]
        )

        await fixture.runtime.start()
        var snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.lifecycleState, .stopped)
        XCTAssertEqual(snapshot.persistenceFailure, .load)
        await assertEqual(await fixture.diskReader.counts().read, 0)
        await assertEqual(await fixture.scheduler.durations(), [])

        await fixture.runtime.start()
        await fixture.scheduler.waitForSleepCount(1)

        snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.lifecycleState, .running)
        XCTAssertNil(snapshot.persistenceFailure)
        await assertEqual(await fixture.repository.loadCount, 2)
        await assertEqual(await fixture.diskReader.counts().read, 1)
    }

    func testConfigurationAndAcceptedSubmissionPersistTheLatestAggregateInOrder() async throws {
        let fixture = makeFixture(authorization: .authorized)
        await fixture.notifications.suspendNextSubmission()
        await fixture.repository.suspendNextSave()
        await fixture.runtime.start()
        await fixture.diskReader.waitForReadCount(1)
        await fixture.diskReader.enqueue(.available(try startupVolume(gigabytes: 5)))
        await fixture.notifications.waitForSubmissionCount(1)
        let configuration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 10),
            interval: .oneHour
        )

        let saveTask = Task {
            await fixture.runtime.saveConfiguration(configuration)
        }
        await fixture.repository.waitForSaveCount(1)
        await fixture.notifications.completePendingSubmission(success: true)
        await fixture.scheduler.waitForSleepCount(1)
        await assertEqual(
            await fixture.runtime.currentSnapshot().notificationEpisodeState,
            .suppressed
        )

        await fixture.repository.completePendingSave(success: true)
        await assertEqual(await saveTask.value, .saved)
        await fixture.repository.waitForSaveCount(2)
        await fixture.diskReader.waitForReadCount(2)
        await fixture.diskReader.enqueue(.available(try startupVolume(gigabytes: 5)))
        await fixture.scheduler.waitForSleepCount(2)

        let saves = await fixture.repository.saves()
        XCTAssertEqual(saves[0].configuration, configuration)
        XCTAssertEqual(saves[0].notificationEpisodeState, .armed)
        XCTAssertEqual(saves[1].configuration, configuration)
        XCTAssertEqual(saves[1].notificationEpisodeState, .suppressed)
        await assertEqual(await fixture.repository.savedState(), saves[1])
    }

    func testSnapshotStreamPublishesLatestStateAndLateReadCannotMutateAfterStop() async throws {
        let fixture = makeFixture()
        let stream = await fixture.runtime.snapshots()
        var snapshots = stream.makeAsyncIterator()
        await assertEqual(await snapshots.next()?.lifecycleState, .stopped)

        await fixture.runtime.start()
        await fixture.diskReader.waitForReadCount(1)
        let runningSnapshot = await snapshots.next()
        XCTAssertEqual(runningSnapshot?.lifecycleState, .running)
        XCTAssertEqual(runningSnapshot?.isCheckInProgress, true)

        await fixture.runtime.stop()
        let stoppedSnapshot = await snapshots.next()
        XCTAssertEqual(stoppedSnapshot?.lifecycleState, .stopped)
        XCTAssertEqual(stoppedSnapshot?.isCheckInProgress, false)
        XCTAssertNil(stoppedSnapshot?.nextScheduledCheckAt)

        await fixture.diskReader.enqueue(.available(try startupVolume(gigabytes: 30)))
        await fixture.diskReader.waitUntilInactive()
        for _ in 0..<3 {
            await Task.yield()
        }

        let finalSnapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(finalSnapshot.lifecycleState, .stopped)
        XCTAssertNil(finalSnapshot.latestSuccessfulVolume)
        await assertEqual(await fixture.wallClock.calls(), 0)
        await assertEqual(await fixture.scheduler.durations(), [])
    }

    func testAcceptedSubmissionReturningAfterStopCannotSuppressPersistOrSchedule() async throws {
        let fixture = makeFixture(
            authorization: .authorized,
            readings: [.available(try startupVolume(gigabytes: 10))]
        )
        await fixture.notifications.suspendNextSubmission()
        await fixture.runtime.start()
        await fixture.notifications.waitForSubmissionCount(1)

        await fixture.runtime.stop()
        await fixture.notifications.completePendingSubmission(success: true)
        for _ in 0..<3 {
            await Task.yield()
        }

        let snapshot = await fixture.runtime.currentSnapshot()
        XCTAssertEqual(snapshot.lifecycleState, .stopped)
        XCTAssertEqual(snapshot.notificationEpisodeState, .armed)
        await assertEqual(await fixture.repository.saves(), [])
        await assertEqual(await fixture.wallClock.calls(), 0)
        await assertEqual(await fixture.scheduler.durations(), [])
    }

    func testCanceledScheduleThatReturnsLateDoesNotRunAfterStop() async throws {
        let scheduler = TestMonitoringScheduler(ignoresCancellation: true)
        let fixture = makeFixture(
            readings: [.available(try startupVolume(gigabytes: 30))],
            scheduler: scheduler
        )
        await fixture.runtime.start()
        await scheduler.waitForSleepCount(1)

        await fixture.runtime.stop()
        await scheduler.fireNext()
        for _ in 0..<3 {
            await Task.yield()
        }

        await assertEqual(await fixture.diskReader.counts().read, 1)
        await assertEqual(await fixture.runtime.currentSnapshot().lifecycleState, .stopped)
    }

    private func assertEqual<T: Equatable>(
        _ expression: @autoclosure () async -> T,
        _ expected: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let value = await expression()
        XCTAssertEqual(value, expected, file: file, line: line)
    }

    private func assertTrue(
        _ expression: @autoclosure () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let value = await expression()
        XCTAssertTrue(value, file: file, line: line)
    }

    private func makeFixture(
        state: StoredMonitoringState = .defaultValue,
        loadFailures: Int = 0,
        authorization: NotificationAuthorizationState = .denied,
        readings: [DiskSpaceReading] = [],
        dates: [Date] = [Date(timeIntervalSince1970: 1_000)],
        scheduler: TestMonitoringScheduler = TestMonitoringScheduler()
    ) -> RuntimeFixture {
        let diskReader = TestStartupVolumeReader(readings: readings)
        let repository = TestMonitoringStateRepository(
            state: state,
            loadFailures: loadFailures
        )
        let notifications = TestMonitoringNotificationService(state: authorization)
        let wallClock = TestMonitoringWallClock(dates: dates)
        let wakeEventSource = TestMonitoringWakeEventSource()
        let runtime = MonitoringRuntime(
            diskReader: diskReader,
            repository: repository,
            notificationService: notifications,
            scheduler: scheduler,
            wallClock: wallClock,
            wakeEventSource: wakeEventSource
        )
        return RuntimeFixture(
            runtime: runtime,
            diskReader: diskReader,
            repository: repository,
            notifications: notifications,
            scheduler: scheduler,
            wallClock: wallClock,
            wakeEventSource: wakeEventSource
        )
    }

    private func startupVolume(gigabytes: Int64) throws -> StartupVolumeSnapshot {
        StartupVolumeSnapshot(
            availableCapacity: try DiskCapacity(
                bytes: gigabytes * DiskCapacity.bytesPerGigabyte
            ),
            volumeName: "Macintosh HD"
        )
    }

    private struct RuntimeFixture {
        let runtime: MonitoringRuntime
        let diskReader: TestStartupVolumeReader
        let repository: TestMonitoringStateRepository
        let notifications: TestMonitoringNotificationService
        let scheduler: TestMonitoringScheduler
        let wallClock: TestMonitoringWallClock
        let wakeEventSource: TestMonitoringWakeEventSource
    }
}
