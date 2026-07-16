#if DEBUG
    import Foundation

    @MainActor
    enum DiskMeerkatPreviewFixtures {
        static func firstRunModel() -> DiskMeerkatPresentationModel {
            makeModel(
                snapshot: snapshot(
                    notificationAuthorizationState: .notDetermined,
                    isCheckInProgress: true,
                    hasCompletedOnboarding: false
                ),
                launchAtLoginState: .disabled
            )
        }

        static func healthyModel() -> DiskMeerkatPresentationModel {
            let volume = startupVolume(bytes: 82_400_000_000)
            return makeModel(
                snapshot: snapshot(
                    notificationAuthorizationState: .authorized,
                    latestSuccessfulVolume: volume,
                    latestAssessment: .available(
                        startupVolume: volume,
                        relationship: .above
                    ),
                    hasCompletedOnboarding: true
                ),
                launchAtLoginState: .enabled
            )
        }

        static func lowSpaceDeniedModel() -> DiskMeerkatPresentationModel {
            let volume = startupVolume(bytes: 18_400_000_000)
            return makeModel(
                snapshot: snapshot(
                    notificationAuthorizationState: .denied,
                    latestSuccessfulVolume: volume,
                    latestAssessment: .available(
                        startupVolume: volume,
                        relationship: .below
                    ),
                    hasCompletedOnboarding: true
                ),
                launchAtLoginState: .disabled
            )
        }

        static func readFailureModel() -> DiskMeerkatPresentationModel {
            let volume = startupVolume(bytes: 42_000_000_000)
            return makeModel(
                snapshot: snapshot(
                    notificationAuthorizationState: .authorized,
                    latestSuccessfulVolume: volume,
                    latestAssessment: .unavailable(.unavailable),
                    hasCompletedOnboarding: true
                ),
                launchAtLoginState: .requiresApproval
            )
        }

        static func invalidSettingsModel() -> DiskMeerkatPresentationModel {
            let model = healthyModel()
            model.beginSettingsEditing()
            model.settingsDraft.thresholdText = "20.5"
            return model
        }

        private static func makeModel(
            snapshot: MonitoringSnapshot,
            launchAtLoginState: LaunchAtLoginActualState
        ) -> DiskMeerkatPresentationModel {
            DiskMeerkatPresentationModel(
                snapshot: snapshot,
                runtimeClient: PreviewMonitoringRuntimeClient(snapshot: snapshot),
                launchAtLoginService: PreviewLaunchAtLoginService(
                    snapshot: LaunchAtLoginSnapshot(
                        actualState: launchAtLoginState,
                        problem: nil
                    )
                ),
                locale: Locale(identifier: "en_US"),
                openNotificationSettings: {}
            )
        }

        private static func snapshot(
            notificationAuthorizationState: NotificationAuthorizationState,
            isCheckInProgress: Bool = false,
            latestSuccessfulVolume: StartupVolumeSnapshot? = nil,
            latestAssessment: DiskSpaceAssessment? = nil,
            hasCompletedOnboarding: Bool
        ) -> MonitoringSnapshot {
            MonitoringSnapshot(
                lifecycleState: .running,
                configuration: .defaultValue,
                notificationEpisodeState: .armed,
                hasCompletedOnboarding: hasCompletedOnboarding,
                notificationAuthorizationState: notificationAuthorizationState,
                isCheckInProgress: isCheckInProgress,
                isSavingConfiguration: false,
                latestSuccessfulVolume: latestSuccessfulVolume,
                latestAssessment: latestAssessment,
                lastSuccessfulCheckAt: latestSuccessfulVolume == nil
                    ? nil : .now.addingTimeInterval(-120),
                nextScheduledCheckAt: isCheckInProgress
                    ? nil : .now.addingTimeInterval(780),
                persistenceFailure: nil,
                notificationFailure: nil
            )
        }

        private static func startupVolume(bytes: Int64) -> StartupVolumeSnapshot {
            StartupVolumeSnapshot(
                availableCapacity: try! DiskCapacity(bytes: bytes),
                volumeName: "Macintosh HD"
            )
        }
    }

    private actor PreviewMonitoringRuntimeClient: MonitoringPresentationRuntimeClient {
        private let snapshot: MonitoringSnapshot

        init(snapshot: MonitoringSnapshot) {
            self.snapshot = snapshot
        }

        func snapshots() async -> AsyncStream<MonitoringSnapshot> {
            let snapshot = snapshot
            return AsyncStream { continuation in
                continuation.yield(snapshot)
            }
        }

        func checkNow() async {}

        func saveConfiguration(
            _ configuration: MonitoringConfiguration
        ) async -> MonitoringConfigurationSaveOutcome {
            .saved
        }

        func requestNotificationAuthorization() async {}

        func refreshNotificationAuthorization() async {}

        func completeOnboarding() async {}
    }

    private actor PreviewLaunchAtLoginService: LaunchAtLoginService {
        private let snapshot: LaunchAtLoginSnapshot

        init(snapshot: LaunchAtLoginSnapshot) {
            self.snapshot = snapshot
        }

        func refresh() async -> LaunchAtLoginSnapshot {
            snapshot
        }

        func setEnabled(_ isEnabled: Bool) async -> LaunchAtLoginSnapshot {
            snapshot
        }

        func openSystemSettings() async {}
    }
#endif
