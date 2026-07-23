import Foundation
import XCTest

@testable import DiskMeerkatApp

final class MonitoringPresentationStateTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testStoppedStateNeverFabricatesCapacityOrCheckAvailability() {
        let state = presentation(snapshot: snapshot(lifecycleState: .stopped))

        XCTAssertEqual(state.headline, .stopped)
        XCTAssertEqual(state.volumeName, "Startup Disk")
        XCTAssertEqual(state.capacityKind, .unavailable)
        XCTAssertNil(state.availableCapacityText)
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "Available space unavailable")
        XCTAssertEqual(resolvedEnglish(state.statusDetail), "Monitoring is not running.")
        XCTAssertFalse(state.canCheckNow)
        XCTAssertTrue(state.shouldShowOnboarding)
        XCTAssertEqual(state.symbolName, "internaldrive.fill")
    }

    func testStartingAndFirstRunningCheckHaveExplicitProgressCopy() {
        var state = presentation(snapshot: snapshot(lifecycleState: .starting))
        XCTAssertEqual(state.headline, .starting)
        XCTAssertEqual(state.capacityKind, .checking)
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "Checking disk…")
        XCTAssertFalse(state.canCheckNow)

        state = presentation(
            snapshot: snapshot(
                lifecycleState: .running,
                isCheckInProgress: true
            )
        )
        XCTAssertEqual(state.headline, .checking)
        XCTAssertEqual(
            resolvedEnglish(state.statusDetail),
            "Reading available space on the startup disk."
        )
        XCTAssertTrue(state.isCheckInProgress)
        XCTAssertFalse(state.canCheckNow)
    }

    func testCheckInProgressRetainsTheLastSuccessfulCapacity() {
        let volume = startupVolume(gigabytes: 42, name: "Macintosh HD")
        let state = presentation(
            snapshot: snapshot(
                lifecycleState: .running,
                isCheckInProgress: true,
                latestSuccessfulVolume: volume,
                latestAssessment: .available(
                    startupVolume: volume,
                    relationship: .above
                )
            )
        )

        XCTAssertEqual(state.headline, .monitoring)
        XCTAssertEqual(state.volumeName, "Macintosh HD")
        XCTAssertEqual(state.capacityKind, .available)
        XCTAssertEqual(state.availableCapacityText, "42 GB")
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "42 GB available")
        XCTAssertEqual(
            resolvedEnglish(state.statusDetail),
            "DiskMeerkat will alert when available space falls below 20 GB."
        )
        XCTAssertTrue(state.isCheckInProgress)
        XCTAssertFalse(state.canCheckNow)
    }

    func testCheckInProgressDoesNotHideThePreviousLowSpaceOutcome() {
        let volume = startupVolume(gigabytes: 18)
        let state = presentation(
            snapshot: snapshot(
                lifecycleState: .running,
                notificationEpisodeState: .suppressed,
                hasCompletedOnboarding: true,
                notificationAuthorizationState: .authorized,
                isCheckInProgress: true,
                latestSuccessfulVolume: volume,
                latestAssessment: .available(
                    startupVolume: volume,
                    relationship: .below
                )
            )
        )

        XCTAssertEqual(state.headline, .lowSpaceAlertSent)
        XCTAssertEqual(state.availableCapacityText, "18 GB")
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "18 GB available")
        XCTAssertTrue(state.isCheckInProgress)
        XCTAssertFalse(state.canCheckNow)
    }

    func testHealthyAndBoundaryCapacityMapToMonitoring() {
        for relationship in [ThresholdRelationship.equal, .above] {
            let volume = startupVolume(gigabytes: relationship == .equal ? 20 : 21)
            let state = presentation(
                snapshot: snapshot(
                    lifecycleState: .running,
                    hasCompletedOnboarding: true,
                    notificationAuthorizationState: .authorized,
                    latestSuccessfulVolume: volume,
                    latestAssessment: .available(
                        startupVolume: volume,
                        relationship: relationship
                    )
                )
            )

            XCTAssertEqual(state.headline, .monitoring)
            XCTAssertEqual(state.symbolName, "internaldrive")
            XCTAssertTrue(state.canCheckNow)
            XCTAssertFalse(state.shouldShowOnboarding)
        }
    }

    func testLowSpaceCopyReflectsDeliveryPermissionAndEpisodeOutcomes() {
        let volume = startupVolume(gigabytes: 18)

        var state = presentation(
            snapshot: lowSpaceSnapshot(volume: volume, authorization: .authorized)
        )
        XCTAssertEqual(state.headline, .lowSpace)
        XCTAssertNil(state.suppressionExplanation)

        state = presentation(
            snapshot: lowSpaceSnapshot(
                volume: volume,
                episode: .suppressed,
                authorization: .authorized
            )
        )
        XCTAssertEqual(state.headline, .lowSpaceAlertSent)
        XCTAssertNotNil(state.suppressionExplanation)

        state = presentation(
            snapshot: lowSpaceSnapshot(volume: volume, authorization: .denied)
        )
        XCTAssertEqual(state.headline, .lowSpaceNotificationsOff)

        state = presentation(
            snapshot: lowSpaceSnapshot(
                volume: volume,
                authorization: .authorized,
                notificationFailure: .submission
            )
        )
        XCTAssertEqual(state.headline, .lowSpaceDeliveryFailed)
        XCTAssertEqual(state.notices.map(\.kind), [.notification])
    }

    func testDiskReadFailureKeepsLastSuccessfulValueAndAddsScopedNotice() {
        let volume = startupVolume(gigabytes: 52, name: "System")
        let state = presentation(
            snapshot: snapshot(
                lifecycleState: .running,
                hasCompletedOnboarding: true,
                notificationAuthorizationState: .authorized,
                latestSuccessfulVolume: volume,
                latestAssessment: .unavailable(.unavailable)
            )
        )

        XCTAssertEqual(state.headline, .readFailed)
        XCTAssertEqual(state.availableCapacityText, "52 GB")
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "52 GB available")
        XCTAssertEqual(state.notices.map(\.kind), [.diskRead])
        XCTAssertTrue(
            resolvedEnglish(state.notices[0].detail).contains("last successful value")
        )
    }

    func testMissingVolumeNameUsesTheStartupDiskFallback() {
        let volume = startupVolume(gigabytes: 52, name: nil)
        let state = presentation(
            snapshot: snapshot(
                lifecycleState: .running,
                latestSuccessfulVolume: volume,
                latestAssessment: .available(
                    startupVolume: volume,
                    relationship: .above
                )
            )
        )

        XCTAssertEqual(state.volumeName, "Startup Disk")
        XCTAssertEqual(state.capacityAccessibilityLabel, "Startup Disk, 52 GB available")
    }

    func testFirstDiskReadFailureShowsUnavailableInsteadOfChecking() {
        let state = presentation(
            snapshot: snapshot(
                lifecycleState: .running,
                latestAssessment: .unavailable(.unavailable)
            )
        )

        XCTAssertEqual(state.headline, .readFailed)
        XCTAssertEqual(state.capacityKind, .unavailable)
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "Available space unavailable")
        XCTAssertEqual(state.notices.map(\.kind), [.diskRead])
    }

    func testEveryNotificationAuthorizationStateHasTruthfulActions() {
        let cases:
            [(
                NotificationAuthorizationState,
                NotificationPermissionPresentationKind,
                Bool,
                Bool
            )] = [
                (.notDetermined, .notDetermined, true, false),
                (.authorized, .authorized, false, false),
                (.denied, .denied, false, true),
                (.unknown, .unavailable, false, false),
                (.unavailable, .unavailable, false, false),
            ]

        for (authorization, kind, canRequest, canOpenSettings) in cases {
            let state = presentation(
                snapshot: snapshot(notificationAuthorizationState: authorization)
            )
            XCTAssertEqual(state.notificationPermission.kind, kind)
            XCTAssertEqual(state.notificationPermission.canRequestAuthorization, canRequest)
            XCTAssertEqual(state.notificationPermission.canOpenSettings, canOpenSettings)
        }
    }

    func testPersistenceFailuresRemainScopedAndExplainTheCommittedState() {
        let cases: [(MonitoringPersistenceFailure, String)] = [
            (.load, "Couldn't load saved monitoring state"),
            (.save, "Couldn't save monitoring state"),
            (.configurationSave, "Couldn't save settings"),
        ]

        for (failure, title) in cases {
            let state = presentation(
                snapshot: snapshot(
                    lifecycleState: failure == .load ? .stopped : .running,
                    persistenceFailure: failure
                )
            )
            XCTAssertEqual(state.notices.map(\.kind), [.persistence])
            XCTAssertEqual(resolvedEnglish(state.notices[0].title), title)
        }
    }

    func testEveryNotificationFailureHasAScopedNotice() {
        let cases: [(MonitoringNotificationFailure, String)] = [
            (.authorizationStatus, "Couldn't read notification status"),
            (.authorizationRequest, "Couldn't update notification permission"),
            (.submission, "Couldn't send the low-space alert"),
        ]

        for (failure, title) in cases {
            let state = presentation(
                snapshot: snapshot(notificationFailure: failure)
            )

            XCTAssertEqual(state.notices.map(\.kind), [.notification])
            XCTAssertEqual(resolvedEnglish(state.notices[0].title), title)
        }
    }

    func testLaunchAtLoginPresentationUsesActualStateAndScopedProblems() {
        let loadingState = presentation(
            snapshot: snapshot(),
            launchAtLoginSnapshot: nil
        )
        XCTAssertNil(loadingState.launchAtLogin.actualState)
        XCTAssertFalse(loadingState.launchAtLogin.canToggle)
        XCTAssertFalse(loadingState.launchAtLogin.requiresAttention)

        let actualStateCases: [(LaunchAtLoginActualState, Bool, Bool, Bool, Bool)] = [
            (.disabled, false, true, false, false),
            (.enabled, true, true, false, false),
            (.requiresApproval, false, false, true, true),
            (.unavailable, false, false, true, true),
        ]

        for (actualState, isEnabled, canToggle, canOpenSettings, requiresAttention) in actualStateCases {
            let state = presentation(
                snapshot: snapshot(),
                launchAtLoginSnapshot: LaunchAtLoginSnapshot(
                    actualState: actualState,
                    problem: nil
                )
            )
            XCTAssertEqual(state.launchAtLogin.actualState, actualState)
            XCTAssertEqual(state.launchAtLogin.isEnabled, isEnabled)
            XCTAssertEqual(state.launchAtLogin.canToggle, canToggle)
            XCTAssertEqual(state.launchAtLogin.canOpenSettings, canOpenSettings)
            XCTAssertEqual(state.launchAtLogin.requiresAttention, requiresAttention)
            XCTAssertEqual(
                state.notices.map(\.kind),
                requiresAttention ? [.launchAtLogin] : []
            )
        }

        let problemCases: [(LaunchAtLoginProblem, String)] = [
            (.changedExternally, "Launch at Login changed in System Settings"),
            (.enableFailed, "Couldn't enable Launch at Login"),
            (.disableFailed, "Couldn't disable Launch at Login"),
        ]

        for (problem, title) in problemCases {
            let state = presentation(
                snapshot: snapshot(),
                launchAtLoginSnapshot: LaunchAtLoginSnapshot(
                    actualState: .disabled,
                    problem: problem
                )
            )
            XCTAssertFalse(state.launchAtLogin.isEnabled)
            XCTAssertTrue(state.launchAtLogin.canToggle)
            XCTAssertTrue(state.launchAtLogin.canOpenSettings)
            XCTAssertTrue(state.launchAtLogin.requiresAttention)
            XCTAssertEqual(resolvedEnglish(state.launchAtLogin.title), title)
            XCTAssertEqual(state.notices.map(\.kind), [.launchAtLogin])
        }
    }

    func testCapacityAndConfigurationUseRequestedLocale() {
        let volume = StartupVolumeSnapshot(
            availableCapacity: try! DiskCapacity(bytes: 19_500_000_000),
            volumeName: "Data"
        )
        let state = MonitoringPresentationState(
            snapshot: snapshot(
                lifecycleState: .running,
                latestSuccessfulVolume: volume,
                latestAssessment: .available(
                    startupVolume: volume,
                    relationship: .below
                )
            ),
            launchAtLoginSnapshot: nil,
            locale: Locale(identifier: "de_DE"),
            localization: englishLocalization
        )

        XCTAssertEqual(state.availableCapacityText, "19,5 GB")
        XCTAssertEqual(resolvedEnglish(state.availableSpaceText), "19,5 GB available")
        XCTAssertEqual(state.thresholdValueText, "20 GB")
        XCTAssertEqual(resolvedEnglish(state.thresholdText), "Alert below 20 GB")
    }

    func testEverySupportedIntervalHasConciseDisplayCopy() {
        let expected: [(CheckInterval, String)] = [
            (.oneMinute, "1 minute"),
            (.fiveMinutes, "5 minutes"),
            (.fifteenMinutes, "15 minutes"),
            (.thirtyMinutes, "30 minutes"),
            (.oneHour, "1 hour"),
            (.sixHours, "6 hours"),
            (.twentyFourHours, "24 hours"),
        ]

        for (interval, copy) in expected {
            let configuration = MonitoringConfiguration(
                threshold: .defaultValue,
                interval: interval
            )
            let state = presentation(snapshot: snapshot(configuration: configuration))
            XCTAssertEqual(resolvedEnglish(state.intervalText), copy)
        }
    }

    private func presentation(
        snapshot: MonitoringSnapshot,
        launchAtLoginSnapshot: LaunchAtLoginSnapshot? = nil
    ) -> MonitoringPresentationState {
        MonitoringPresentationState(
            snapshot: snapshot,
            launchAtLoginSnapshot: launchAtLoginSnapshot,
            locale: locale,
            localization: englishLocalization
        )
    }

    private func lowSpaceSnapshot(
        volume: StartupVolumeSnapshot,
        episode: NotificationEpisodeState = .armed,
        authorization: NotificationAuthorizationState,
        notificationFailure: MonitoringNotificationFailure? = nil
    ) -> MonitoringSnapshot {
        snapshot(
            lifecycleState: .running,
            notificationEpisodeState: episode,
            hasCompletedOnboarding: true,
            notificationAuthorizationState: authorization,
            latestSuccessfulVolume: volume,
            latestAssessment: .available(
                startupVolume: volume,
                relationship: .below
            ),
            notificationFailure: notificationFailure
        )
    }

    private func snapshot(
        lifecycleState: MonitoringLifecycleState = .running,
        configuration: MonitoringConfiguration = .defaultValue,
        notificationEpisodeState: NotificationEpisodeState = .armed,
        hasCompletedOnboarding: Bool = false,
        notificationAuthorizationState: NotificationAuthorizationState = .notDetermined,
        isCheckInProgress: Bool = false,
        isSavingConfiguration: Bool = false,
        latestSuccessfulVolume: StartupVolumeSnapshot? = nil,
        latestAssessment: DiskSpaceAssessment? = nil,
        lastSuccessfulCheckAt: Date? = nil,
        nextScheduledCheckAt: Date? = nil,
        persistenceFailure: MonitoringPersistenceFailure? = nil,
        notificationFailure: MonitoringNotificationFailure? = nil
    ) -> MonitoringSnapshot {
        MonitoringSnapshot(
            lifecycleState: lifecycleState,
            configuration: configuration,
            notificationEpisodeState: notificationEpisodeState,
            hasCompletedOnboarding: hasCompletedOnboarding,
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

    private func startupVolume(
        gigabytes: Int64,
        name: String? = "Macintosh HD"
    ) -> StartupVolumeSnapshot {
        StartupVolumeSnapshot(
            availableCapacity: try! DiskCapacity(
                bytes: gigabytes * DiskCapacity.bytesPerGigabyte
            ),
            volumeName: name
        )
    }
}
