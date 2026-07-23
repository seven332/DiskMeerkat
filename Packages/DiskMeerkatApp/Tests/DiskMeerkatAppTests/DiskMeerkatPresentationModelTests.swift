import Foundation
import XCTest

@testable import DiskMeerkatApp

@MainActor
final class DiskMeerkatPresentationModelTests: XCTestCase {
    func testSnapshotUpdatesCommittedStateWithoutOverwritingAnActiveDraft() async throws {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await waitForInitialRefresh(runtime: runtime, launchService: launchService)

        model.beginSettingsEditing()
        model.settingsDraft.thresholdText = "30"
        let newConfiguration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 25),
            interval: .oneHour
        )
        await runtime.send(snapshot(configuration: newConfiguration))
        await waitUntil { model.snapshot.configuration == newConfiguration }

        XCTAssertEqual(model.settingsDraft.thresholdText, "30")
        XCTAssertEqual(model.settingsDraft.interval, .fifteenMinutes)

        model.cancelSettingsEditing()
        XCTAssertEqual(model.settingsDraft.thresholdText, "25")
        XCTAssertEqual(model.settingsDraft.interval, .oneHour)
    }

    func testSnapshotUpdatesDraftWhenSettingsAreNotBeingEdited() async throws {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        let configuration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 80),
            interval: .twentyFourHours
        )

        await runtime.send(snapshot(configuration: configuration))
        await waitUntil { model.snapshot.configuration == configuration }

        XCTAssertEqual(model.settingsDraft.thresholdText, "80")
        XCTAssertEqual(model.settingsDraft.interval, .twentyFourHours)
        XCTAssertFalse(model.settingsDraft.isDirty)
    }

    func testSnapshotObservationStartAndStopAreIdempotentAndRestartable() async throws {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await waitUntil { await runtime.calls().snapshotSubscriptions == 1 }

        model.startObservingSnapshots()
        await Task.yield()
        let callsAfterDuplicateStart = await runtime.calls()
        XCTAssertEqual(callsAfterDuplicateStart.snapshotSubscriptions, 1)

        let firstConfiguration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 30),
            interval: .oneHour
        )
        await runtime.send(snapshot(configuration: firstConfiguration))
        await waitUntil { model.snapshot.configuration == firstConfiguration }

        model.stopObservingSnapshots()
        let secondConfiguration = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 40),
            interval: .sixHours
        )
        await runtime.send(snapshot(configuration: secondConfiguration))
        await Task.yield()
        XCTAssertEqual(model.snapshot.configuration, firstConfiguration)

        model.startObservingSnapshots()
        await waitUntil { await runtime.calls().snapshotSubscriptions == 2 }
        await runtime.send(snapshot(configuration: secondConfiguration))
        await waitUntil { model.snapshot.configuration == secondConfiguration }
    }

    func testCheckNowRoutesOnlyWhenRuntimeStateAllowsIt() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(
            snapshot: snapshot(lifecycleState: .stopped),
            runtime: runtime,
            launchService: launchService
        )

        await model.checkNow()
        var runtimeCalls = await runtime.calls()
        XCTAssertEqual(runtimeCalls.checkNow, 0)

        await runtime.send(snapshot(lifecycleState: .running, isCheckInProgress: true))
        await waitUntil { model.snapshot.isCheckInProgress }
        await model.checkNow()
        runtimeCalls = await runtime.calls()
        XCTAssertEqual(runtimeCalls.checkNow, 0)

        await runtime.send(snapshot())
        await waitUntil { model.presentation.canCheckNow }
        await model.checkNow()
        runtimeCalls = await runtime.calls()
        XCTAssertEqual(runtimeCalls.checkNow, 1)
    }

    func testCheckNowPreventsDuplicateRequestsWhileSubmissionIsPending() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await runtime.suspendNextCheck()

        let firstCheck = Task { await model.checkNow() }
        await waitUntil { model.isRequestingCheck }
        XCTAssertFalse(model.canCheckNow)

        await model.checkNow()
        let calls = await runtime.calls()
        XCTAssertEqual(calls.checkNow, 1)

        await runtime.completePendingCheck()
        await firstCheck.value
        XCTAssertFalse(model.isRequestingCheck)
    }

    func testInvalidAndUnchangedDraftsNeverInvokeSave() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)

        model.beginSettingsEditing()
        XCTAssertFalse(model.canSaveSettings)
        var didSave = await model.saveSettings()
        XCTAssertFalse(didSave)

        model.settingsDraft.thresholdText = "20 GB"
        XCTAssertFalse(model.canSaveSettings)
        didSave = await model.saveSettings()
        let runtimeCalls = await runtime.calls()
        XCTAssertFalse(didSave)
        XCTAssertTrue(runtimeCalls.savedConfigurations.isEmpty)
    }

    func testSuccessfulSaveRoutesValidatedConfigurationAndEndsEditing() async {
        let runtime = RecordingPresentationRuntimeClient(saveOutcomes: [.saved])
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)

        model.beginSettingsEditing()
        model.settingsDraft.thresholdText = "35"
        model.settingsDraft.interval = .sixHours

        XCTAssertTrue(model.canSaveSettings)
        let didSave = await model.saveSettings()
        XCTAssertTrue(didSave)

        let saved = await runtime.calls().savedConfigurations
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].threshold.gigabytes, 35)
        XCTAssertEqual(saved[0].interval, .sixHours)
        XCTAssertFalse(model.isEditingSettings)
        XCTAssertNil(model.settingsSaveError)
        XCTAssertFalse(model.settingsDraft.isDirty)
    }

    func testFailedSaveKeepsDraftAndExplainsThatCommittedValuesRemainActive() async {
        let runtime = RecordingPresentationRuntimeClient(saveOutcomes: [.failed])
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)

        model.beginSettingsEditing()
        model.settingsDraft.thresholdText = "35"

        let didSave = await model.saveSettings()
        XCTAssertFalse(didSave)
        XCTAssertTrue(model.isEditingSettings)
        XCTAssertEqual(model.settingsDraft.thresholdText, "35")
        XCTAssertTrue(model.settingsDraft.isDirty)
        XCTAssertEqual(
            resolvedEnglish(model.settingsSaveError),
            "Couldn't save settings. Your previous settings remain active."
        )
        XCTAssertEqual(model.snapshot.configuration, .defaultValue)
    }

    func testUnavailableSaveOutcomesKeepTheDraftAndExplainTheReason() async {
        let cases: [(MonitoringConfigurationSaveOutcome, String)] = [
            (.notRunning, "Monitoring is not running, so settings couldn't be saved."),
            (.alreadySaving, "Another settings save is still in progress."),
        ]

        for (outcome, message) in cases {
            let runtime = RecordingPresentationRuntimeClient(saveOutcomes: [outcome])
            let launchService = RecordingLaunchAtLoginService()
            let model = makeModel(runtime: runtime, launchService: launchService)
            model.beginSettingsEditing()
            model.settingsDraft.thresholdText = "35"

            let didSave = await model.saveSettings()

            XCTAssertFalse(didSave)
            XCTAssertTrue(model.isEditingSettings)
            XCTAssertEqual(model.settingsDraft.thresholdText, "35")
            XCTAssertEqual(resolvedEnglish(model.settingsSaveError), message)
        }
    }

    func testSaveGuardPreventsDuplicateSubmissionWhileARequestIsPending() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await runtime.suspendNextSave()
        model.beginSettingsEditing()
        model.settingsDraft.thresholdText = "35"

        let firstSave = Task { await model.saveSettings() }
        await waitUntil { model.isSavingSettings }

        XCTAssertFalse(model.canSaveSettings)
        let secondDidSave = await model.saveSettings()
        let pendingCalls = await runtime.calls()
        XCTAssertFalse(secondDidSave)
        XCTAssertEqual(pendingCalls.savedConfigurations.count, 1)

        await runtime.completePendingSave(with: .saved)
        let firstDidSave = await firstSave.value
        XCTAssertTrue(firstDidSave)
        XCTAssertFalse(model.isSavingSettings)
    }

    func testNotificationPromptIsOnlyRoutedFromEligibleExplicitAction() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await waitForInitialRefresh(runtime: runtime, launchService: launchService)

        var calls = await runtime.calls()
        XCTAssertEqual(calls.requestAuthorization, 0)
        XCTAssertEqual(calls.refreshAuthorization, 1)

        await model.enableNotifications()
        calls = await runtime.calls()
        XCTAssertEqual(calls.requestAuthorization, 1)

        await runtime.send(snapshot(notificationAuthorizationState: .denied))
        await waitUntil { model.snapshot.notificationAuthorizationState == .denied }
        await model.enableNotifications()
        calls = await runtime.calls()
        XCTAssertEqual(calls.requestAuthorization, 1)
    }

    func testNotificationPromptPreventsDuplicateRequestsWhilePending() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await runtime.suspendNextAuthorizationRequest()

        let firstRequest = Task { await model.enableNotifications() }
        await waitUntil { model.isUpdatingNotificationPermission }

        await model.enableNotifications()
        let calls = await runtime.calls()
        XCTAssertEqual(calls.requestAuthorization, 1)

        await runtime.completePendingAuthorizationRequest()
        await firstRequest.value
        XCTAssertFalse(model.isUpdatingNotificationPermission)
    }

    func testDeniedPermissionOpensInjectedSettingsThenRefreshes() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let settingsActions = AsyncActionRecorder()
        let model = makeModel(
            snapshot: snapshot(notificationAuthorizationState: .denied),
            runtime: runtime,
            launchService: launchService,
            openNotificationSettings: {
                await settingsActions.record()
            }
        )
        await waitForInitialRefresh(runtime: runtime, launchService: launchService)

        await model.openNotificationSettings()

        let settingsActionCount = await settingsActions.count()
        let runtimeCalls = await runtime.calls()
        XCTAssertEqual(settingsActionCount, 1)
        XCTAssertEqual(runtimeCalls.refreshAuthorization, 2)
    }

    func testOnboardingActionsDoNotMakePermissionARequirement() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)

        await model.completeOnboarding()
        var calls = await runtime.calls()
        XCTAssertEqual(calls.completeOnboarding, 1)
        XCTAssertEqual(calls.requestAuthorization, 0)

        let secondRuntime = RecordingPresentationRuntimeClient()
        let secondModel = makeModel(runtime: secondRuntime, launchService: launchService)
        await secondModel.enableNotificationsAndCompleteOnboarding()
        calls = await secondRuntime.calls()
        XCTAssertEqual(calls.requestAuthorization, 1)
        XCTAssertEqual(calls.completeOnboarding, 1)
    }

    func testOnboardingPreventsDuplicateCompletionWhilePending() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await runtime.suspendNextOnboardingCompletion()

        let firstCompletion = Task { await model.completeOnboarding() }
        await waitUntil { model.isCompletingOnboarding }

        await model.completeOnboarding()
        let calls = await runtime.calls()
        XCTAssertEqual(calls.completeOnboarding, 1)

        await runtime.completePendingOnboarding()
        await firstCompletion.value
        XCTAssertFalse(model.isCompletingOnboarding)
    }

    func testLaunchAtLoginUsesReturnedActualStateAndRoutesSystemSettings() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService(
            refreshSnapshots: [
                LaunchAtLoginSnapshot(actualState: .disabled, problem: nil),
                LaunchAtLoginSnapshot(actualState: .enabled, problem: nil),
            ],
            setSnapshots: [
                LaunchAtLoginSnapshot(actualState: .requiresApproval, problem: nil)
            ]
        )
        let model = makeModel(runtime: runtime, launchService: launchService)
        await waitUntil { model.launchAtLoginSnapshot?.actualState == .disabled }

        await model.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(model.launchAtLoginSnapshot?.actualState, .requiresApproval)
        XCTAssertFalse(model.presentation.launchAtLogin.isEnabled)
        XCTAssertTrue(model.presentation.launchAtLogin.canOpenSettings)

        await model.openLaunchAtLoginSettings()
        let calls = await launchService.calls()
        XCTAssertEqual(calls.setValues, [true])
        XCTAssertEqual(calls.openSettings, 1)
        XCTAssertEqual(model.launchAtLoginSnapshot?.actualState, .enabled)
    }

    func testLaunchAtLoginPreventsDuplicateMutationsWhilePending() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await waitUntil { model.launchAtLoginSnapshot?.actualState == .disabled }
        await launchService.suspendNextSet()

        let firstMutation = Task { await model.setLaunchAtLoginEnabled(true) }
        await waitUntil { model.isUpdatingLaunchAtLogin }

        await model.setLaunchAtLoginEnabled(true)
        let calls = await launchService.calls()
        XCTAssertEqual(calls.setValues, [true])

        await launchService.completePendingSet(
            with: LaunchAtLoginSnapshot(actualState: .enabled, problem: nil)
        )
        await firstMutation.value
        XCTAssertEqual(model.launchAtLoginSnapshot?.actualState, .enabled)
        XCTAssertFalse(model.isUpdatingLaunchAtLogin)
    }

    func testLaunchAtLoginRefreshPreventsAConcurrentMutation() async {
        let runtime = RecordingPresentationRuntimeClient()
        let launchService = RecordingLaunchAtLoginService()
        let model = makeModel(runtime: runtime, launchService: launchService)
        await waitUntil { model.launchAtLoginSnapshot?.actualState == .disabled }
        await launchService.suspendNextRefresh()

        let refresh = Task { await model.refreshExternalState() }
        await waitUntil { model.isUpdatingLaunchAtLogin }
        await model.setLaunchAtLoginEnabled(true)
        let pendingCalls = await launchService.calls()
        XCTAssertTrue(pendingCalls.setValues.isEmpty)

        await launchService.completePendingRefresh(
            with: LaunchAtLoginSnapshot(actualState: .disabled, problem: nil)
        )
        await refresh.value
        XCTAssertEqual(model.launchAtLoginSnapshot?.actualState, .disabled)
        XCTAssertFalse(model.isUpdatingLaunchAtLogin)
    }

    private func makeModel(
        snapshot: MonitoringSnapshot? = nil,
        runtime: RecordingPresentationRuntimeClient,
        launchService: RecordingLaunchAtLoginService,
        openNotificationSettings: @escaping @Sendable () async -> Void = {}
    ) -> DiskMeerkatPresentationModel {
        DiskMeerkatPresentationModel(
            snapshot: snapshot ?? self.snapshot(),
            runtimeClient: runtime,
            launchAtLoginService: launchService,
            locale: Locale(identifier: "en_US"),
            localization: englishLocalization,
            openNotificationSettings: openNotificationSettings
        )
    }

    private func waitForInitialRefresh(
        runtime: RecordingPresentationRuntimeClient,
        launchService: RecordingLaunchAtLoginService
    ) async {
        await waitUntil {
            let runtimeCalls = await runtime.calls()
            let launchCalls = await launchService.calls()
            return runtimeCalls.refreshAuthorization >= 1 && launchCalls.refresh >= 1
        }
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Condition was not met", file: file, line: line)
    }

    private func snapshot(
        lifecycleState: MonitoringLifecycleState = .running,
        configuration: MonitoringConfiguration = .defaultValue,
        notificationAuthorizationState: NotificationAuthorizationState = .notDetermined,
        isCheckInProgress: Bool = false
    ) -> MonitoringSnapshot {
        MonitoringSnapshot(
            lifecycleState: lifecycleState,
            configuration: configuration,
            notificationEpisodeState: .armed,
            hasCompletedOnboarding: false,
            notificationAuthorizationState: notificationAuthorizationState,
            isCheckInProgress: isCheckInProgress,
            isSavingConfiguration: false,
            latestSuccessfulVolume: nil,
            latestAssessment: nil,
            lastSuccessfulCheckAt: nil,
            nextScheduledCheckAt: nil,
            persistenceFailure: nil,
            notificationFailure: nil
        )
    }
}

private struct PresentationRuntimeCalls: Sendable {
    var snapshotSubscriptions = 0
    var checkNow = 0
    var savedConfigurations: [MonitoringConfiguration] = []
    var requestAuthorization = 0
    var refreshAuthorization = 0
    var completeOnboarding = 0
}

private actor RecordingPresentationRuntimeClient: MonitoringPresentationRuntimeClient {
    private var continuations: [UUID: AsyncStream<MonitoringSnapshot>.Continuation] = [:]
    private var latestSnapshot: MonitoringSnapshot?
    private var saveOutcomes: [MonitoringConfigurationSaveOutcome]
    private var shouldSuspendNextSave = false
    private var pendingSave: CheckedContinuation<MonitoringConfigurationSaveOutcome, Never>?
    private var shouldSuspendNextCheck = false
    private var pendingCheck: CheckedContinuation<Void, Never>?
    private var shouldSuspendNextAuthorizationRequest = false
    private var pendingAuthorizationRequest: CheckedContinuation<Void, Never>?
    private var shouldSuspendNextOnboardingCompletion = false
    private var pendingOnboardingCompletion: CheckedContinuation<Void, Never>?
    private var recordedCalls = PresentationRuntimeCalls()

    init(saveOutcomes: [MonitoringConfigurationSaveOutcome] = []) {
        self.saveOutcomes = saveOutcomes
    }

    func snapshots() async -> AsyncStream<MonitoringSnapshot> {
        recordedCalls.snapshotSubscriptions += 1
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: MonitoringSnapshot.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.removeContinuation(id: id)
            }
        }
        continuations[id] = continuation
        if let latestSnapshot {
            continuation.yield(latestSnapshot)
        }
        return stream
    }

    func checkNow() async {
        recordedCalls.checkNow += 1
        if shouldSuspendNextCheck {
            shouldSuspendNextCheck = false
            await withCheckedContinuation { continuation in
                pendingCheck = continuation
            }
        }
    }

    func saveConfiguration(
        _ configuration: MonitoringConfiguration
    ) async -> MonitoringConfigurationSaveOutcome {
        recordedCalls.savedConfigurations.append(configuration)
        if shouldSuspendNextSave {
            shouldSuspendNextSave = false
            return await withCheckedContinuation { continuation in
                pendingSave = continuation
            }
        }
        guard !saveOutcomes.isEmpty else {
            return .saved
        }
        return saveOutcomes.removeFirst()
    }

    func requestNotificationAuthorization() async {
        recordedCalls.requestAuthorization += 1
        if shouldSuspendNextAuthorizationRequest {
            shouldSuspendNextAuthorizationRequest = false
            await withCheckedContinuation { continuation in
                pendingAuthorizationRequest = continuation
            }
        }
    }

    func refreshNotificationAuthorization() async {
        recordedCalls.refreshAuthorization += 1
    }

    func completeOnboarding() async {
        recordedCalls.completeOnboarding += 1
        if shouldSuspendNextOnboardingCompletion {
            shouldSuspendNextOnboardingCompletion = false
            await withCheckedContinuation { continuation in
                pendingOnboardingCompletion = continuation
            }
        }
    }

    func send(_ snapshot: MonitoringSnapshot) {
        latestSnapshot = snapshot
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    func suspendNextSave() {
        shouldSuspendNextSave = true
    }

    func suspendNextCheck() {
        shouldSuspendNextCheck = true
    }

    func completePendingCheck() {
        pendingCheck?.resume()
        pendingCheck = nil
    }

    func suspendNextAuthorizationRequest() {
        shouldSuspendNextAuthorizationRequest = true
    }

    func completePendingAuthorizationRequest() {
        pendingAuthorizationRequest?.resume()
        pendingAuthorizationRequest = nil
    }

    func suspendNextOnboardingCompletion() {
        shouldSuspendNextOnboardingCompletion = true
    }

    func completePendingOnboarding() {
        pendingOnboardingCompletion?.resume()
        pendingOnboardingCompletion = nil
    }

    func completePendingSave(with outcome: MonitoringConfigurationSaveOutcome) {
        pendingSave?.resume(returning: outcome)
        pendingSave = nil
    }

    func calls() -> PresentationRuntimeCalls {
        recordedCalls
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

private struct LaunchAtLoginServiceCalls: Sendable {
    var refresh = 0
    var setValues: [Bool] = []
    var openSettings = 0
}

private actor RecordingLaunchAtLoginService: LaunchAtLoginService {
    private var refreshSnapshots: [LaunchAtLoginSnapshot]
    private var setSnapshots: [LaunchAtLoginSnapshot]
    private var latestSnapshot: LaunchAtLoginSnapshot
    private var recordedCalls = LaunchAtLoginServiceCalls()
    private var shouldSuspendNextRefresh = false
    private var pendingRefresh: CheckedContinuation<LaunchAtLoginSnapshot, Never>?
    private var shouldSuspendNextSet = false
    private var pendingSet: CheckedContinuation<LaunchAtLoginSnapshot, Never>?

    init(
        refreshSnapshots: [LaunchAtLoginSnapshot] = [
            LaunchAtLoginSnapshot(actualState: .disabled, problem: nil)
        ],
        setSnapshots: [LaunchAtLoginSnapshot] = []
    ) {
        precondition(!refreshSnapshots.isEmpty)
        self.refreshSnapshots = refreshSnapshots
        self.setSnapshots = setSnapshots
        latestSnapshot = refreshSnapshots.last!
    }

    func refresh() async -> LaunchAtLoginSnapshot {
        recordedCalls.refresh += 1
        if shouldSuspendNextRefresh {
            shouldSuspendNextRefresh = false
            return await withCheckedContinuation { continuation in
                pendingRefresh = continuation
            }
        }
        if !refreshSnapshots.isEmpty {
            latestSnapshot = refreshSnapshots.removeFirst()
        }
        return latestSnapshot
    }

    func setEnabled(_ isEnabled: Bool) async -> LaunchAtLoginSnapshot {
        recordedCalls.setValues.append(isEnabled)
        if shouldSuspendNextSet {
            shouldSuspendNextSet = false
            return await withCheckedContinuation { continuation in
                pendingSet = continuation
            }
        }
        if !setSnapshots.isEmpty {
            latestSnapshot = setSnapshots.removeFirst()
        }
        return latestSnapshot
    }

    func openSystemSettings() async {
        recordedCalls.openSettings += 1
    }

    func calls() -> LaunchAtLoginServiceCalls {
        recordedCalls
    }

    func suspendNextRefresh() {
        shouldSuspendNextRefresh = true
    }

    func completePendingRefresh(with snapshot: LaunchAtLoginSnapshot) {
        latestSnapshot = snapshot
        pendingRefresh?.resume(returning: snapshot)
        pendingRefresh = nil
    }

    func suspendNextSet() {
        shouldSuspendNextSet = true
    }

    func completePendingSet(with snapshot: LaunchAtLoginSnapshot) {
        latestSnapshot = snapshot
        pendingSet?.resume(returning: snapshot)
        pendingSet = nil
    }
}

private actor AsyncActionRecorder {
    private var callCount = 0

    func record() {
        callCount += 1
    }

    func count() -> Int {
        callCount
    }
}
