import Foundation

enum NotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case unavailable
    case authorized
}

protocol MonitoringNotificationService: Sendable {
    func authorizationState() async throws -> NotificationAuthorizationState
    func requestAuthorization() async throws -> NotificationAuthorizationState
    func submit(_ candidate: LowSpaceNotificationCandidate) async throws
}

protocol MonitoringScheduler: Sendable {
    func sleep(for duration: Duration) async throws
}

protocol MonitoringWallClock: Sendable {
    func now() async -> Date
}

protocol MonitoringWakeEventSource: Sendable {
    func events() async -> AsyncStream<Void>
}
