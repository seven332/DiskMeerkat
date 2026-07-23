import Foundation
import UserNotifications

enum UserNotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case unavailable
}

struct UserNotificationRequestDescriptor: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let usesDefaultSound: Bool
}

protocol UserNotificationCenterClient: Sendable {
    func authorizationStatus() async throws -> UserNotificationAuthorizationStatus
    func requestAuthorization() async throws -> UserNotificationAuthorizationStatus
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async
    func add(_ request: UserNotificationRequestDescriptor) async throws
}

actor SystemUserNotificationCenterClient: UserNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async throws -> UserNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> UserNotificationAuthorizationStatus {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return try await authorizationStatus()
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func add(_ request: UserNotificationRequestDescriptor) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        if request.usesDefaultSound {
            content.sound = .default
        }

        let systemRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        )
        try await center.add(systemRequest)
    }

    nonisolated static func map(
        _ status: UNAuthorizationStatus
    ) -> UserNotificationAuthorizationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorized
        case .provisional:
            .provisional
        @unknown default:
            .unavailable
        }
    }
}

struct UserNotificationsMonitoringService: MonitoringNotificationService {
    static let lowSpaceRequestIdentifier = "DiskMeerkat.low-space"

    private let client: any UserNotificationCenterClient
    private let formatter: DiskCapacityFormatter
    private let localization: DiskMeerkatLocalization
    private let startupDiskName: String?

    init(
        client: any UserNotificationCenterClient,
        locale: Locale = .autoupdatingCurrent,
        localization: DiskMeerkatLocalization = .current,
        startupDiskName: String? = nil
    ) {
        self.client = client
        formatter = DiskCapacityFormatter(locale: locale)
        self.localization = localization
        self.startupDiskName = startupDiskName
    }

    init(locale: Locale = .autoupdatingCurrent) {
        self.init(client: SystemUserNotificationCenterClient(), locale: locale)
    }

    func authorizationState() async throws -> NotificationAuthorizationState {
        try await map(client.authorizationStatus())
    }

    func requestAuthorization() async throws -> NotificationAuthorizationState {
        try await map(client.requestAuthorization())
    }

    func removeDeliveredLowSpaceNotification() async {
        await client.removeDeliveredNotifications(
            withIdentifiers: [Self.lowSpaceRequestIdentifier]
        )
    }

    func submit(_ candidate: LowSpaceNotificationCandidate) async throws {
        let volumeName =
            candidate.volumeName
            ?? startupDiskName
            ?? localization.resolve(localization.startupDisk)
        let availableCapacity = localization.resolve(
            localization.gigabytes(
                formatter.numberString(
                    for: candidate.availableCapacity,
                    relativeTo: candidate.threshold
                )
            )
        )
        let threshold = localization.resolve(
            localization.gigabytes(
                formatter.numberString(for: candidate.threshold)
            )
        )
        let request = UserNotificationRequestDescriptor(
            identifier: Self.lowSpaceRequestIdentifier,
            title: localization.resolve(localization.notificationTitle),
            body: localization.resolve(
                localization.notificationBody(
                    volumeName: volumeName,
                    availableCapacity: availableCapacity,
                    threshold: threshold
                )
            ),
            usesDefaultSound: true
        )
        try await client.add(request)
    }

    private func map(
        _ status: UserNotificationAuthorizationStatus
    ) -> NotificationAuthorizationState {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized, .provisional:
            .authorized
        case .unavailable:
            .unavailable
        }
    }
}
