import Foundation

enum MonitoringHeadline: Equatable, Sendable {
    case stopped
    case starting
    case checking
    case monitoring
    case lowSpace
    case lowSpaceAlertSent
    case lowSpaceNotificationsOff
    case lowSpaceDeliveryFailed
    case readFailed

    var text: String {
        switch self {
        case .stopped:
            "Monitoring stopped"
        case .starting:
            "Starting monitoring…"
        case .checking:
            "Checking disk…"
        case .monitoring:
            "Monitoring"
        case .lowSpace:
            "Low disk space"
        case .lowSpaceAlertSent:
            "Low disk space · Alert sent"
        case .lowSpaceNotificationsOff:
            "Low disk space · Notifications are off"
        case .lowSpaceDeliveryFailed:
            "Low disk space · Couldn't send alert · Will retry"
        case .readFailed:
            "Couldn't check disk · Will retry"
        }
    }

    var requiresAttention: Bool {
        switch self {
        case .starting, .checking, .monitoring:
            false
        case .stopped, .lowSpace, .lowSpaceAlertSent, .lowSpaceNotificationsOff,
            .lowSpaceDeliveryFailed, .readFailed:
            true
        }
    }
}

enum NotificationPermissionPresentationKind: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

struct NotificationPermissionPresentation: Equatable, Sendable {
    let kind: NotificationPermissionPresentationKind
    let title: String
    let detail: String
    let canRequestAuthorization: Bool
    let canOpenSettings: Bool

    var requiresAttention: Bool {
        kind != .authorized
    }
}

enum MonitoringNoticeKind: String, Equatable, Hashable, Sendable {
    case diskRead
    case persistence
    case notification
    case launchAtLogin
}

struct MonitoringNotice: Equatable, Identifiable, Sendable {
    let kind: MonitoringNoticeKind
    let title: String
    let detail: String

    var id: MonitoringNoticeKind {
        kind
    }
}

struct LaunchAtLoginPresentation: Equatable, Sendable {
    let actualState: LaunchAtLoginActualState?
    let title: String
    let detail: String
    let isEnabled: Bool
    let canToggle: Bool
    let canOpenSettings: Bool
    let requiresAttention: Bool
}

struct MonitoringPresentationState: Equatable, Sendable {
    let headline: MonitoringHeadline
    let statusDetail: String
    let symbolName: String
    let statusAccessibilityLabel: String
    let volumeName: String
    let availableSpaceText: String
    let capacityAccessibilityLabel: String
    let thresholdText: String
    let intervalText: String
    let lastSuccessfulCheckAt: Date?
    let nextScheduledCheckAt: Date?
    let notificationPermission: NotificationPermissionPresentation
    let launchAtLogin: LaunchAtLoginPresentation
    let notices: [MonitoringNotice]
    let suppressionExplanation: String?
    let isCheckInProgress: Bool
    let isSavingConfiguration: Bool
    let canCheckNow: Bool
    let shouldShowOnboarding: Bool

    init(
        snapshot: MonitoringSnapshot,
        launchAtLoginSnapshot: LaunchAtLoginSnapshot?,
        locale: Locale = .autoupdatingCurrent,
        startupDiskName: String = String(localized: "Startup Disk")
    ) {
        let formatter = DiskCapacityFormatter(locale: locale)
        let headline = Self.headline(for: snapshot)
        let permission = Self.permission(for: snapshot)
        let login = Self.launchAtLogin(for: launchAtLoginSnapshot)
        let volumeName = snapshot.latestSuccessfulVolume?.volumeName ?? startupDiskName
        let availableSpaceText: String
        if let volume = snapshot.latestSuccessfulVolume {
            availableSpaceText =
                formatter.string(
                    for: volume.availableCapacity,
                    relativeTo: snapshot.configuration.threshold
                ) + " available"
        } else if snapshot.lifecycleState == .stopped {
            availableSpaceText = "Available space unavailable"
        } else if case .unavailable = snapshot.latestAssessment {
            availableSpaceText = "Available space unavailable"
        } else {
            availableSpaceText = "Checking disk…"
        }
        let threshold = formatter.string(for: snapshot.configuration.threshold)
        let statusDetail = Self.statusDetail(
            headline: headline,
            snapshot: snapshot,
            threshold: threshold
        )
        let notices = Self.notices(
            snapshot: snapshot,
            launchAtLoginSnapshot: launchAtLoginSnapshot
        )
        let requiresAttention =
            headline.requiresAttention || permission.requiresAttention || login.requiresAttention
            || !notices.isEmpty

        self.headline = headline
        self.statusDetail = statusDetail
        symbolName = requiresAttention ? "internaldrive.fill" : "internaldrive"
        statusAccessibilityLabel = "DiskMeerkat. \(headline.text). \(availableSpaceText)."
        self.volumeName = volumeName
        self.availableSpaceText = availableSpaceText
        capacityAccessibilityLabel = "\(volumeName), \(availableSpaceText)"
        thresholdText = "Alert below \(threshold)"
        intervalText = snapshot.configuration.interval.displayName
        lastSuccessfulCheckAt = snapshot.lastSuccessfulCheckAt
        nextScheduledCheckAt = snapshot.nextScheduledCheckAt
        notificationPermission = permission
        launchAtLogin = login
        self.notices = notices
        if snapshot.notificationEpisodeState == .suppressed,
            case .available(_, .below) = snapshot.latestAssessment
        {
            suppressionExplanation =
                "Another alert becomes eligible after available space rises above \(threshold) and later falls below it again."
        } else {
            suppressionExplanation = nil
        }
        isCheckInProgress = snapshot.isCheckInProgress
        isSavingConfiguration = snapshot.isSavingConfiguration
        canCheckNow = snapshot.lifecycleState == .running && !snapshot.isCheckInProgress
        shouldShowOnboarding = !snapshot.hasCompletedOnboarding
    }

    private static func headline(for snapshot: MonitoringSnapshot) -> MonitoringHeadline {
        switch snapshot.lifecycleState {
        case .stopped:
            return .stopped
        case .starting:
            return .starting
        case .running:
            break
        }

        if snapshot.isCheckInProgress || snapshot.latestAssessment == nil {
            return .checking
        }

        switch snapshot.latestAssessment {
        case .available(_, let relationship):
            guard relationship == .below else {
                return .monitoring
            }
            if snapshot.notificationFailure == .submission {
                return .lowSpaceDeliveryFailed
            }
            if snapshot.notificationAuthorizationState != .authorized {
                return .lowSpaceNotificationsOff
            }
            if snapshot.notificationEpisodeState == .suppressed {
                return .lowSpaceAlertSent
            }
            return .lowSpace
        case .unavailable:
            return .readFailed
        case nil:
            return .checking
        }
    }

    private static func statusDetail(
        headline: MonitoringHeadline,
        snapshot: MonitoringSnapshot,
        threshold: String
    ) -> String {
        switch headline {
        case .stopped:
            if snapshot.persistenceFailure == .load {
                "Saved monitoring state couldn't be loaded."
            } else {
                "Monitoring is not running."
            }
        case .starting:
            "Restoring saved settings and notification status."
        case .checking:
            "The previous successful value stays visible while the check runs."
        case .monitoring:
            "DiskMeerkat will alert when available space falls below \(threshold)."
        case .lowSpace:
            "Available space is below \(threshold)."
        case .lowSpaceAlertSent:
            "An alert was submitted for this low-space episode."
        case .lowSpaceNotificationsOff:
            "Monitoring continues, but DiskMeerkat cannot currently send alerts."
        case .lowSpaceDeliveryFailed:
            "Monitoring continues and a later eligible check may retry the alert."
        case .readFailed:
            snapshot.latestSuccessfulVolume == nil
                ? "No successful disk reading is available yet."
                : "The last successful value remains visible."
        }
    }

    private static func permission(
        for snapshot: MonitoringSnapshot
    ) -> NotificationPermissionPresentation {
        switch snapshot.notificationAuthorizationState {
        case .notDetermined:
            NotificationPermissionPresentation(
                kind: .notDetermined,
                title: "Notifications are not enabled",
                detail: "Enable notifications to receive low-space alerts.",
                canRequestAuthorization: true,
                canOpenSettings: false
            )
        case .authorized:
            NotificationPermissionPresentation(
                kind: .authorized,
                title: "Notifications are enabled",
                detail: "DiskMeerkat can submit low-space alerts.",
                canRequestAuthorization: false,
                canOpenSettings: false
            )
        case .denied:
            NotificationPermissionPresentation(
                kind: .denied,
                title: "Notifications are off",
                detail: "Monitoring continues. Allow alerts in System Settings if you want notifications.",
                canRequestAuthorization: false,
                canOpenSettings: true
            )
        case .unknown, .unavailable:
            NotificationPermissionPresentation(
                kind: .unavailable,
                title: "Notification status is unavailable",
                detail: "Monitoring continues without relying on notification permission.",
                canRequestAuthorization: false,
                canOpenSettings: false
            )
        }
    }

    private static func launchAtLogin(
        for snapshot: LaunchAtLoginSnapshot?
    ) -> LaunchAtLoginPresentation {
        guard let snapshot else {
            return LaunchAtLoginPresentation(
                actualState: nil,
                title: "Launch at Login status is loading",
                detail: "DiskMeerkat is reading the current system setting.",
                isEnabled: false,
                canToggle: false,
                canOpenSettings: false,
                requiresAttention: false
            )
        }

        let base: LaunchAtLoginPresentation
        switch snapshot.actualState {
        case .disabled:
            base = LaunchAtLoginPresentation(
                actualState: .disabled,
                title: "Launch at Login is off",
                detail: "DiskMeerkat starts only when you open it.",
                isEnabled: false,
                canToggle: true,
                canOpenSettings: false,
                requiresAttention: false
            )
        case .enabled:
            base = LaunchAtLoginPresentation(
                actualState: .enabled,
                title: "Launch at Login is on",
                detail: "DiskMeerkat starts after you sign in.",
                isEnabled: true,
                canToggle: true,
                canOpenSettings: false,
                requiresAttention: false
            )
        case .requiresApproval:
            base = LaunchAtLoginPresentation(
                actualState: .requiresApproval,
                title: "Launch at Login needs approval",
                detail: "Review DiskMeerkat in Login Items in System Settings.",
                isEnabled: false,
                canToggle: false,
                canOpenSettings: true,
                requiresAttention: true
            )
        case .unavailable:
            base = LaunchAtLoginPresentation(
                actualState: .unavailable,
                title: "Launch at Login is unavailable",
                detail: "The system login-item service couldn't be accessed.",
                isEnabled: false,
                canToggle: false,
                canOpenSettings: true,
                requiresAttention: true
            )
        }

        guard let problem = snapshot.problem else {
            return base
        }
        switch problem {
        case .changedExternally:
            return LaunchAtLoginPresentation(
                actualState: base.actualState,
                title: "Launch at Login changed in System Settings",
                detail: "DiskMeerkat refreshed the switch to match the actual system state.",
                isEnabled: base.isEnabled,
                canToggle: base.canToggle,
                canOpenSettings: true,
                requiresAttention: true
            )
        case .enableFailed:
            return LaunchAtLoginPresentation(
                actualState: base.actualState,
                title: "Couldn't enable Launch at Login",
                detail: "The switch still shows the actual system state. Try again or review Login Items.",
                isEnabled: base.isEnabled,
                canToggle: base.canToggle,
                canOpenSettings: true,
                requiresAttention: true
            )
        case .disableFailed:
            return LaunchAtLoginPresentation(
                actualState: base.actualState,
                title: "Couldn't disable Launch at Login",
                detail: "The switch still shows the actual system state. Try again or review Login Items.",
                isEnabled: base.isEnabled,
                canToggle: base.canToggle,
                canOpenSettings: true,
                requiresAttention: true
            )
        }
    }

    private static func notices(
        snapshot: MonitoringSnapshot,
        launchAtLoginSnapshot: LaunchAtLoginSnapshot?
    ) -> [MonitoringNotice] {
        var notices: [MonitoringNotice] = []

        if case .unavailable = snapshot.latestAssessment {
            notices.append(
                MonitoringNotice(
                    kind: .diskRead,
                    title: "Couldn't check the startup disk",
                    detail: snapshot.latestSuccessfulVolume == nil
                        ? "DiskMeerkat will retry on the next check."
                        : "The last successful value is shown. DiskMeerkat will retry."
                )
            )
        }

        if let failure = snapshot.persistenceFailure {
            let copy: (String, String)
            switch failure {
            case .load:
                copy = (
                    "Couldn't load saved monitoring state",
                    "Monitoring is stopped so the problem can be reviewed safely."
                )
            case .save:
                copy = (
                    "Couldn't save monitoring state",
                    "In-memory monitoring continues and DiskMeerkat will retry."
                )
            case .configurationSave:
                copy = (
                    "Couldn't save settings",
                    "The previous settings and schedule remain active."
                )
            }
            notices.append(
                MonitoringNotice(kind: .persistence, title: copy.0, detail: copy.1)
            )
        }

        if let failure = snapshot.notificationFailure {
            let copy: (String, String)
            switch failure {
            case .authorizationStatus:
                copy = (
                    "Couldn't read notification status",
                    "Disk monitoring continues. Try refreshing notification status later."
                )
            case .authorizationRequest:
                copy = (
                    "Couldn't update notification permission",
                    "Disk monitoring continues without changing the current permission."
                )
            case .submission:
                copy = (
                    "Couldn't send the low-space alert",
                    "The episode remains eligible and a later check may retry."
                )
            }
            notices.append(
                MonitoringNotice(kind: .notification, title: copy.0, detail: copy.1)
            )
        }

        if let launchAtLoginSnapshot,
            launchAtLoginSnapshot.actualState == .requiresApproval
                || launchAtLoginSnapshot.actualState == .unavailable
                || launchAtLoginSnapshot.problem != nil
        {
            let presentation = launchAtLogin(for: launchAtLoginSnapshot)
            notices.append(
                MonitoringNotice(
                    kind: .launchAtLogin,
                    title: presentation.title,
                    detail: presentation.detail
                )
            )
        }

        return notices
    }
}

extension CheckInterval {
    var displayName: String {
        switch self {
        case .fiveMinutes:
            "5 minutes"
        case .fifteenMinutes:
            "15 minutes"
        case .thirtyMinutes:
            "30 minutes"
        case .oneHour:
            "1 hour"
        case .sixHours:
            "6 hours"
        case .twentyFourHours:
            "24 hours"
        }
    }
}
