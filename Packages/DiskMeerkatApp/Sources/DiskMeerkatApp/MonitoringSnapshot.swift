import Foundation

enum MonitoringLifecycleState: Equatable, Sendable {
    case stopped
    case starting
    case running
}

enum MonitoringPersistenceFailure: Equatable, Sendable {
    case load
    case save
    case configurationSave
}

enum MonitoringNotificationFailure: Equatable, Sendable {
    case authorizationStatus
    case authorizationRequest
    case submission
}

enum MonitoringConfigurationSaveOutcome: Equatable, Sendable {
    case saved
    case failed
    case notRunning
    case alreadySaving
}

struct MonitoringSnapshot: Equatable, Sendable {
    let lifecycleState: MonitoringLifecycleState
    let configuration: MonitoringConfiguration
    let notificationEpisodeState: NotificationEpisodeState
    let hasCompletedOnboarding: Bool
    let notificationAuthorizationState: NotificationAuthorizationState
    let isCheckInProgress: Bool
    let isSavingConfiguration: Bool
    let latestSuccessfulVolume: StartupVolumeSnapshot?
    let latestAssessment: DiskSpaceAssessment?
    let lastSuccessfulCheckAt: Date?
    let nextScheduledCheckAt: Date?
    let persistenceFailure: MonitoringPersistenceFailure?
    let notificationFailure: MonitoringNotificationFailure?
}
