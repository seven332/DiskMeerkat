import Foundation
import Observation

protocol MonitoringPresentationRuntimeClient: Sendable {
    func snapshots() async -> AsyncStream<MonitoringSnapshot>
    func checkNow() async
    func saveConfiguration(
        _ configuration: MonitoringConfiguration
    ) async -> MonitoringConfigurationSaveOutcome
    func requestNotificationAuthorization() async
    func refreshNotificationAuthorization() async
    func completeOnboarding() async
}

struct MonitoringRuntimePresentationClient: MonitoringPresentationRuntimeClient {
    let runtime: MonitoringRuntime

    func snapshots() async -> AsyncStream<MonitoringSnapshot> {
        await runtime.snapshots()
    }

    func checkNow() async {
        await runtime.checkNow()
    }

    func saveConfiguration(
        _ configuration: MonitoringConfiguration
    ) async -> MonitoringConfigurationSaveOutcome {
        await runtime.saveConfiguration(configuration)
    }

    func requestNotificationAuthorization() async {
        await runtime.requestNotificationAuthorization()
    }

    func refreshNotificationAuthorization() async {
        await runtime.refreshNotificationAuthorization()
    }

    func completeOnboarding() async {
        await runtime.completeOnboarding()
    }
}

@MainActor
@Observable
public final class DiskMeerkatPresentationModel {
    private(set) var snapshot: MonitoringSnapshot
    private(set) var launchAtLoginSnapshot: LaunchAtLoginSnapshot?
    var settingsDraft: MonitoringSettingsDraft
    private(set) var isEditingSettings = false
    private(set) var settingsSaveError: String?
    private(set) var isSavingSettings = false
    private(set) var isRequestingCheck = false
    private(set) var isUpdatingNotificationPermission = false
    private(set) var isCompletingOnboarding = false
    private(set) var isUpdatingLaunchAtLogin = false

    @ObservationIgnored private let runtimeClient: any MonitoringPresentationRuntimeClient
    @ObservationIgnored private let launchAtLoginService: any LaunchAtLoginService
    @ObservationIgnored private let openNotificationSettingsAction: @Sendable () async -> Void
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var observationID: UUID?
    @ObservationIgnored private var initialRefreshTask: Task<Void, Never>?

    init(
        snapshot: MonitoringSnapshot,
        runtimeClient: any MonitoringPresentationRuntimeClient,
        launchAtLoginService: any LaunchAtLoginService,
        locale: Locale = .autoupdatingCurrent,
        openNotificationSettings: @escaping @Sendable () async -> Void
    ) {
        self.snapshot = snapshot
        self.runtimeClient = runtimeClient
        self.launchAtLoginService = launchAtLoginService
        self.locale = locale
        openNotificationSettingsAction = openNotificationSettings
        settingsDraft = MonitoringSettingsDraft(configuration: snapshot.configuration, locale: locale)

        startObservingSnapshots()
        initialRefreshTask = Task { [weak self] in
            await self?.refreshExternalState()
        }
    }

    isolated deinit {
        observationTask?.cancel()
        initialRefreshTask?.cancel()
    }

    func startObservingSnapshots() {
        guard observationTask == nil else {
            return
        }
        let id = UUID()
        observationID = id
        observationTask = Task { [weak self, runtimeClient] in
            let snapshots = await runtimeClient.snapshots()
            for await snapshot in snapshots {
                guard !Task.isCancelled else {
                    break
                }
                self?.receive(snapshot)
            }
            self?.finishObservingSnapshots(id: id)
        }
    }

    func stopObservingSnapshots() {
        observationID = nil
        observationTask?.cancel()
        observationTask = nil
    }

    var presentation: MonitoringPresentationState {
        MonitoringPresentationState(
            snapshot: snapshot,
            launchAtLoginSnapshot: launchAtLoginSnapshot,
            locale: locale
        )
    }

    var canSaveSettings: Bool {
        isEditingSettings
            && settingsDraft.validatedConfiguration != nil
            && settingsDraft.isDirty
            && !snapshot.isSavingConfiguration
            && !isSavingSettings
    }

    var canCheckNow: Bool {
        presentation.canCheckNow && !isRequestingCheck
    }

    func beginSettingsEditing() {
        guard !isEditingSettings else {
            return
        }
        settingsDraft.reset(to: snapshot.configuration)
        settingsSaveError = nil
        isEditingSettings = true
    }

    func cancelSettingsEditing() {
        guard isEditingSettings else {
            return
        }
        settingsDraft.reset(to: snapshot.configuration)
        settingsSaveError = nil
        isEditingSettings = false
    }

    @discardableResult
    func saveSettings() async -> Bool {
        guard canSaveSettings, let configuration = settingsDraft.validatedConfiguration else {
            return false
        }

        settingsSaveError = nil
        isSavingSettings = true
        defer { isSavingSettings = false }
        switch await runtimeClient.saveConfiguration(configuration) {
        case .saved:
            settingsDraft.reset(to: configuration)
            isEditingSettings = false
            return true
        case .failed:
            settingsSaveError = "Couldn't save settings. Your previous settings remain active."
        case .notRunning:
            settingsSaveError = "Monitoring is not running, so settings couldn't be saved."
        case .alreadySaving:
            settingsSaveError = "Another settings save is still in progress."
        }
        return false
    }

    func checkNow() async {
        guard canCheckNow else {
            return
        }
        isRequestingCheck = true
        defer { isRequestingCheck = false }
        await runtimeClient.checkNow()
    }

    func enableNotifications() async {
        guard
            presentation.notificationPermission.canRequestAuthorization,
            !isUpdatingNotificationPermission
        else {
            return
        }
        isUpdatingNotificationPermission = true
        defer { isUpdatingNotificationPermission = false }
        await runtimeClient.requestNotificationAuthorization()
    }

    func refreshNotificationAuthorization() async {
        await runtimeClient.refreshNotificationAuthorization()
    }

    func openNotificationSettings() async {
        guard
            presentation.notificationPermission.canOpenSettings,
            !isUpdatingNotificationPermission
        else {
            return
        }
        isUpdatingNotificationPermission = true
        defer { isUpdatingNotificationPermission = false }
        await openNotificationSettingsAction()
        await runtimeClient.refreshNotificationAuthorization()
    }

    func completeOnboarding() async {
        await performOnboardingCompletion(shouldEnableNotifications: false)
    }

    func enableNotificationsAndCompleteOnboarding() async {
        await performOnboardingCompletion(shouldEnableNotifications: true)
    }

    func refreshExternalState() async {
        async let notificationRefresh: Void = runtimeClient.refreshNotificationAuthorization()
        await refreshLaunchAtLogin()
        await notificationRefresh
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) async {
        guard
            presentation.launchAtLogin.canToggle,
            !isUpdatingLaunchAtLogin,
            presentation.launchAtLogin.isEnabled != isEnabled
        else {
            return
        }
        isUpdatingLaunchAtLogin = true
        defer { isUpdatingLaunchAtLogin = false }
        launchAtLoginSnapshot = await launchAtLoginService.setEnabled(isEnabled)
    }

    func openLaunchAtLoginSettings() async {
        guard presentation.launchAtLogin.canOpenSettings, !isUpdatingLaunchAtLogin else {
            return
        }
        isUpdatingLaunchAtLogin = true
        defer { isUpdatingLaunchAtLogin = false }
        await launchAtLoginService.openSystemSettings()
        launchAtLoginSnapshot = await launchAtLoginService.refresh()
    }

    private func receive(_ snapshot: MonitoringSnapshot) {
        self.snapshot = snapshot
        if !isEditingSettings {
            settingsDraft.reset(to: snapshot.configuration)
        }
    }

    private func performOnboardingCompletion(
        shouldEnableNotifications: Bool
    ) async {
        guard presentation.shouldShowOnboarding, !isCompletingOnboarding else {
            return
        }
        isCompletingOnboarding = true
        defer { isCompletingOnboarding = false }
        if shouldEnableNotifications {
            await enableNotifications()
        }
        await runtimeClient.completeOnboarding()
    }

    private func refreshLaunchAtLogin() async {
        guard !isUpdatingLaunchAtLogin else {
            return
        }
        isUpdatingLaunchAtLogin = true
        defer { isUpdatingLaunchAtLogin = false }
        launchAtLoginSnapshot = await launchAtLoginService.refresh()
    }

    private func finishObservingSnapshots(id: UUID) {
        guard observationID == id else {
            return
        }
        observationID = nil
        observationTask = nil
    }
}
