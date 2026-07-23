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

    func text(localization: DiskMeerkatLocalization) -> LocalizedStringResource {
        switch self {
        case .stopped:
            localization.headlineStopped
        case .starting:
            localization.headlineStarting
        case .checking:
            localization.headlineChecking
        case .monitoring:
            localization.headlineMonitoring
        case .lowSpace:
            localization.headlineLowSpace
        case .lowSpaceAlertSent:
            localization.headlineLowSpaceAlertSent
        case .lowSpaceNotificationsOff:
            localization.headlineLowSpaceNotificationsOff
        case .lowSpaceDeliveryFailed:
            localization.headlineLowSpaceDeliveryFailed
        case .readFailed:
            localization.headlineReadFailed
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
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
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
    let title: LocalizedStringResource
    let detail: LocalizedStringResource

    var id: MonitoringNoticeKind {
        kind
    }
}

struct LaunchAtLoginPresentation: Equatable, Sendable {
    let actualState: LaunchAtLoginActualState?
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let isEnabled: Bool
    let canToggle: Bool
    let canOpenSettings: Bool
    let requiresAttention: Bool
}

enum MonitoringCapacityPresentationKind: Equatable, Sendable {
    case available
    case unavailable
    case checking
}

struct MonitoringPresentationState: Equatable, Sendable {
    let headline: MonitoringHeadline
    let headlineText: LocalizedStringResource
    let statusDetail: LocalizedStringResource
    let symbolName: String
    let statusAccessibilityLabel: String
    let volumeName: String
    let capacityKind: MonitoringCapacityPresentationKind
    let availableCapacityText: String?
    let availableSpaceText: LocalizedStringResource
    let capacityAccessibilityLabel: String
    let thresholdValueText: String
    let thresholdText: LocalizedStringResource
    let intervalText: LocalizedStringResource
    let lastSuccessfulCheckAt: Date?
    let nextScheduledCheckAt: Date?
    let notificationPermission: NotificationPermissionPresentation
    let launchAtLogin: LaunchAtLoginPresentation
    let notices: [MonitoringNotice]
    let suppressionExplanation: LocalizedStringResource?
    let isCheckInProgress: Bool
    let isSavingConfiguration: Bool
    let canCheckNow: Bool
    let shouldShowOnboarding: Bool

    init(
        snapshot: MonitoringSnapshot,
        launchAtLoginSnapshot: LaunchAtLoginSnapshot?,
        locale: Locale = .autoupdatingCurrent,
        localization: DiskMeerkatLocalization = .current,
        startupDiskName: String? = nil
    ) {
        let formatter = DiskCapacityFormatter(locale: locale)
        let headline = Self.headline(for: snapshot)
        let permission = Self.permission(for: snapshot, localization: localization)
        let login = Self.launchAtLogin(
            for: launchAtLoginSnapshot,
            localization: localization
        )
        let startupDiskName = startupDiskName ?? localization.resolve(localization.startupDisk)
        let volumeName = snapshot.latestSuccessfulVolume?.volumeName ?? startupDiskName
        let capacityKind: MonitoringCapacityPresentationKind
        let availableCapacityText: String?
        let availableSpaceText: LocalizedStringResource
        if let volume = snapshot.latestSuccessfulVolume {
            let formattedNumber = formatter.numberString(
                for: volume.availableCapacity,
                relativeTo: snapshot.configuration.threshold
            )
            let formattedCapacity = localization.resolve(
                localization.gigabytes(formattedNumber)
            )
            capacityKind = .available
            availableCapacityText = formattedCapacity
            availableSpaceText = localization.availableCapacity(formattedCapacity)
        } else if snapshot.lifecycleState == .stopped {
            capacityKind = .unavailable
            availableCapacityText = nil
            availableSpaceText = localization.availableSpaceUnavailable
        } else if case .unavailable = snapshot.latestAssessment {
            capacityKind = .unavailable
            availableCapacityText = nil
            availableSpaceText = localization.availableSpaceUnavailable
        } else {
            capacityKind = .checking
            availableCapacityText = nil
            availableSpaceText = localization.checkingDisk
        }
        let thresholdNumber = formatter.numberString(for: snapshot.configuration.threshold)
        let threshold = localization.resolve(localization.gigabytes(thresholdNumber))
        let statusDetail = Self.statusDetail(
            headline: headline,
            snapshot: snapshot,
            threshold: threshold,
            localization: localization
        )
        let notices = Self.notices(
            snapshot: snapshot,
            launchAtLoginSnapshot: launchAtLoginSnapshot,
            localization: localization
        )
        let requiresAttention =
            headline.requiresAttention || permission.requiresAttention || login.requiresAttention
            || !notices.isEmpty
        let headlineText = headline.text(localization: localization)
        let resolvedHeadline = localization.resolve(headlineText)
        let resolvedAvailableSpace = localization.resolve(availableSpaceText)

        self.headline = headline
        self.headlineText = headlineText
        self.statusDetail = statusDetail
        symbolName = requiresAttention ? "internaldrive.fill" : "internaldrive"
        statusAccessibilityLabel = localization.resolve(
            localization.statusAccessibilityLabel(
                headline: resolvedHeadline,
                availableSpace: resolvedAvailableSpace
            )
        )
        self.volumeName = volumeName
        self.capacityKind = capacityKind
        self.availableCapacityText = availableCapacityText
        self.availableSpaceText = availableSpaceText
        capacityAccessibilityLabel = localization.resolve(
            localization.capacityAccessibilityLabel(
                volumeName: volumeName,
                availableSpace: resolvedAvailableSpace
            )
        )
        thresholdValueText = threshold
        thresholdText = localization.alertBelow(threshold)
        intervalText = snapshot.configuration.interval.displayName(localization: localization)
        lastSuccessfulCheckAt = snapshot.lastSuccessfulCheckAt
        nextScheduledCheckAt = snapshot.nextScheduledCheckAt
        notificationPermission = permission
        launchAtLogin = login
        self.notices = notices
        if snapshot.notificationEpisodeState == .suppressed,
            case .available(_, .below) = snapshot.latestAssessment
        {
            suppressionExplanation = localization.suppressionExplanation(threshold)
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

        if snapshot.latestAssessment == nil {
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
        threshold: String,
        localization: DiskMeerkatLocalization
    ) -> LocalizedStringResource {
        switch headline {
        case .stopped:
            if snapshot.persistenceFailure == .load {
                localization.statusStoppedLoadFailed
            } else {
                localization.statusStopped
            }
        case .starting:
            localization.statusStarting
        case .checking:
            localization.statusChecking
        case .monitoring:
            localization.statusMonitoring(threshold)
        case .lowSpace:
            localization.statusLowSpace(threshold)
        case .lowSpaceAlertSent:
            localization.statusLowSpaceAlertSent
        case .lowSpaceNotificationsOff:
            localization.statusLowSpaceNotificationsOff
        case .lowSpaceDeliveryFailed:
            localization.statusLowSpaceDeliveryFailed
        case .readFailed:
            snapshot.latestSuccessfulVolume == nil
                ? localization.statusReadFailedNoValue
                : localization.statusReadFailedWithValue
        }
    }

    private static func permission(
        for snapshot: MonitoringSnapshot,
        localization: DiskMeerkatLocalization
    ) -> NotificationPermissionPresentation {
        switch snapshot.notificationAuthorizationState {
        case .notDetermined:
            NotificationPermissionPresentation(
                kind: .notDetermined,
                title: localization.permissionNotDeterminedTitle,
                detail: localization.permissionNotDeterminedDetail,
                canRequestAuthorization: true,
                canOpenSettings: false
            )
        case .authorized:
            NotificationPermissionPresentation(
                kind: .authorized,
                title: localization.permissionAuthorizedTitle,
                detail: localization.permissionAuthorizedDetail,
                canRequestAuthorization: false,
                canOpenSettings: false
            )
        case .denied:
            NotificationPermissionPresentation(
                kind: .denied,
                title: localization.permissionDeniedTitle,
                detail: localization.permissionDeniedDetail,
                canRequestAuthorization: false,
                canOpenSettings: true
            )
        case .unknown, .unavailable:
            NotificationPermissionPresentation(
                kind: .unavailable,
                title: localization.permissionUnavailableTitle,
                detail: localization.permissionUnavailableDetail,
                canRequestAuthorization: false,
                canOpenSettings: false
            )
        }
    }

    private static func launchAtLogin(
        for snapshot: LaunchAtLoginSnapshot?,
        localization: DiskMeerkatLocalization
    ) -> LaunchAtLoginPresentation {
        guard let snapshot else {
            return LaunchAtLoginPresentation(
                actualState: nil,
                title: localization.launchAtLoginLoadingTitle,
                detail: localization.launchAtLoginLoadingDetail,
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
                title: localization.launchAtLoginDisabledTitle,
                detail: localization.launchAtLoginDisabledDetail,
                isEnabled: false,
                canToggle: true,
                canOpenSettings: false,
                requiresAttention: false
            )
        case .enabled:
            base = LaunchAtLoginPresentation(
                actualState: .enabled,
                title: localization.launchAtLoginEnabledTitle,
                detail: localization.launchAtLoginEnabledDetail,
                isEnabled: true,
                canToggle: true,
                canOpenSettings: false,
                requiresAttention: false
            )
        case .requiresApproval:
            base = LaunchAtLoginPresentation(
                actualState: .requiresApproval,
                title: localization.launchAtLoginRequiresApprovalTitle,
                detail: localization.launchAtLoginRequiresApprovalDetail,
                isEnabled: false,
                canToggle: false,
                canOpenSettings: true,
                requiresAttention: true
            )
        case .unavailable:
            base = LaunchAtLoginPresentation(
                actualState: .unavailable,
                title: localization.launchAtLoginUnavailableTitle,
                detail: localization.launchAtLoginUnavailableDetail,
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
                title: localization.launchAtLoginChangedTitle,
                detail: localization.launchAtLoginChangedDetail,
                isEnabled: base.isEnabled,
                canToggle: base.canToggle,
                canOpenSettings: true,
                requiresAttention: true
            )
        case .enableFailed:
            return LaunchAtLoginPresentation(
                actualState: base.actualState,
                title: localization.launchAtLoginEnableFailedTitle,
                detail: localization.launchAtLoginEnableFailedDetail,
                isEnabled: base.isEnabled,
                canToggle: base.canToggle,
                canOpenSettings: true,
                requiresAttention: true
            )
        case .disableFailed:
            return LaunchAtLoginPresentation(
                actualState: base.actualState,
                title: localization.launchAtLoginDisableFailedTitle,
                detail: localization.launchAtLoginDisableFailedDetail,
                isEnabled: base.isEnabled,
                canToggle: base.canToggle,
                canOpenSettings: true,
                requiresAttention: true
            )
        }
    }

    private static func notices(
        snapshot: MonitoringSnapshot,
        launchAtLoginSnapshot: LaunchAtLoginSnapshot?,
        localization: DiskMeerkatLocalization
    ) -> [MonitoringNotice] {
        var notices: [MonitoringNotice] = []

        if case .unavailable = snapshot.latestAssessment {
            notices.append(
                MonitoringNotice(
                    kind: .diskRead,
                    title: localization.noticeDiskReadTitle,
                    detail: snapshot.latestSuccessfulVolume == nil
                        ? localization.noticeDiskReadNoValueDetail
                        : localization.noticeDiskReadWithValueDetail
                )
            )
        }

        if let failure = snapshot.persistenceFailure {
            let copy: (LocalizedStringResource, LocalizedStringResource)
            switch failure {
            case .load:
                copy = (
                    localization.noticePersistenceLoadTitle,
                    localization.noticePersistenceLoadDetail
                )
            case .save:
                copy = (
                    localization.noticePersistenceSaveTitle,
                    localization.noticePersistenceSaveDetail
                )
            case .configurationSave:
                copy = (
                    localization.noticeConfigurationSaveTitle,
                    localization.noticeConfigurationSaveDetail
                )
            }
            notices.append(
                MonitoringNotice(kind: .persistence, title: copy.0, detail: copy.1)
            )
        }

        if let failure = snapshot.notificationFailure {
            let copy: (LocalizedStringResource, LocalizedStringResource)
            switch failure {
            case .authorizationStatus:
                copy = (
                    localization.noticeNotificationStatusTitle,
                    localization.noticeNotificationStatusDetail
                )
            case .authorizationRequest:
                copy = (
                    localization.noticeNotificationPermissionTitle,
                    localization.noticeNotificationPermissionDetail
                )
            case .submission:
                copy = (
                    localization.noticeNotificationSubmissionTitle,
                    localization.noticeNotificationSubmissionDetail
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
            let presentation = launchAtLogin(
                for: launchAtLoginSnapshot,
                localization: localization
            )
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
    func displayName(
        localization: DiskMeerkatLocalization = .current
    ) -> LocalizedStringResource {
        switch self {
        case .oneMinute:
            localization.intervalMinutes(1)
        case .fiveMinutes:
            localization.intervalMinutes(5)
        case .fifteenMinutes:
            localization.intervalMinutes(15)
        case .thirtyMinutes:
            localization.intervalMinutes(30)
        case .oneHour:
            localization.intervalHours(1)
        case .sixHours:
            localization.intervalHours(6)
        case .twentyFourHours:
            localization.intervalHours(24)
        }
    }
}
