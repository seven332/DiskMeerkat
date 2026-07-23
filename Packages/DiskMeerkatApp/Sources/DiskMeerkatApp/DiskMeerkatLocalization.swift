import Foundation

struct DiskMeerkatLocalization: Equatable, Sendable {
    static let current = Self()
    static let english = Self(locale: Locale(identifier: "en"))
    static var resourceBundle: Bundle {
        Bundle.module
    }

    let locale: Locale?

    init(locale: Locale? = nil) {
        self.locale = locale
    }

    func resolve(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    func resource(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        comment: StaticString
    ) -> LocalizedStringResource {
        if let locale {
            return LocalizedStringResource(
                key,
                defaultValue: defaultValue,
                locale: locale,
                bundle: #bundle,
                comment: comment
            )
        }
        return LocalizedStringResource(
            key,
            defaultValue: defaultValue,
            bundle: #bundle,
            comment: comment
        )
    }
}

extension DiskMeerkatLocalization {
    var runtimeNotConnected: LocalizedStringResource {
        resource(
            "runtime.not-connected",
            defaultValue: "The app is not connected to its monitoring runtime yet.",
            comment: "Fallback message shown when the app shell has no monitoring model."
        )
    }

    var startupDisk: LocalizedStringResource {
        resource(
            "disk.startup",
            defaultValue: "Startup Disk",
            comment: "Fallback name for the macOS startup disk."
        )
    }

    func gigabytes(_ formattedNumber: String) -> LocalizedStringResource {
        resource(
            "capacity.gigabytes",
            defaultValue: "\(formattedNumber) GB",
            comment: "A formatted decimal number followed by the gigabyte unit."
        )
    }

    func availableCapacity(_ formattedCapacity: String) -> LocalizedStringResource {
        resource(
            "capacity.available",
            defaultValue: "\(formattedCapacity) available",
            comment: "Available disk capacity. The argument already includes the localized GB unit."
        )
    }

    var availableSpaceUnavailable: LocalizedStringResource {
        resource(
            "capacity.unavailable",
            defaultValue: "Available space unavailable",
            comment: "Shown when the startup disk capacity cannot be displayed."
        )
    }

    var checkingDisk: LocalizedStringResource {
        resource(
            "monitoring.checking-disk",
            defaultValue: "Checking disk…",
            comment: "Shown while DiskMeerkat reads the startup disk."
        )
    }

    func alertBelow(_ formattedThreshold: String) -> LocalizedStringResource {
        resource(
            "threshold.alert-below",
            defaultValue: "Alert below \(formattedThreshold)",
            comment: "Monitoring threshold summary. The argument includes a localized GB unit."
        )
    }

    func belowThreshold(_ formattedThreshold: String) -> LocalizedStringResource {
        resource(
            "threshold.below",
            defaultValue: "Below \(formattedThreshold)",
            comment: "Compact threshold summary. The argument includes a localized GB unit."
        )
    }

    func statusAccessibilityLabel(
        headline: String,
        availableSpace: String
    ) -> LocalizedStringResource {
        resource(
            "accessibility.status",
            defaultValue: "DiskMeerkat. \(headline). \(availableSpace).",
            comment: "Accessibility summary containing monitoring state and available disk space."
        )
    }

    func capacityAccessibilityLabel(
        volumeName: String,
        availableSpace: String
    ) -> LocalizedStringResource {
        resource(
            "accessibility.capacity",
            defaultValue: "\(volumeName), \(availableSpace)",
            comment: "Accessibility summary containing a disk name and its available capacity."
        )
    }

    func thresholdErrorAccessibilityLabel(_ error: String) -> LocalizedStringResource {
        resource(
            "accessibility.threshold-error",
            defaultValue: "Threshold error: \(error)",
            comment: "Accessibility label for a low-space threshold validation error."
        )
    }
}

extension DiskMeerkatLocalization {
    var headlineStopped: LocalizedStringResource {
        resource(
            "monitoring.headline.stopped",
            defaultValue: "Monitoring stopped",
            comment: "Headline shown when monitoring is stopped."
        )
    }

    var headlineStarting: LocalizedStringResource {
        resource(
            "monitoring.headline.starting",
            defaultValue: "Starting monitoring…",
            comment: "Headline shown while monitoring starts."
        )
    }

    var headlineChecking: LocalizedStringResource {
        checkingDisk
    }

    var headlineMonitoring: LocalizedStringResource {
        resource(
            "monitoring.headline.monitoring",
            defaultValue: "Monitoring",
            comment: "Headline shown while disk monitoring is healthy."
        )
    }

    var headlineLowSpace: LocalizedStringResource {
        resource(
            "monitoring.headline.low-space",
            defaultValue: "Low disk space",
            comment: "Headline shown when available disk space is below the configured threshold."
        )
    }

    var headlineLowSpaceAlertSent: LocalizedStringResource {
        resource(
            "monitoring.headline.low-space-alert-sent",
            defaultValue: "Low disk space · Alert sent",
            comment: "Headline shown after a low-space alert was submitted."
        )
    }

    var headlineLowSpaceNotificationsOff: LocalizedStringResource {
        resource(
            "monitoring.headline.low-space-notifications-off",
            defaultValue: "Low disk space · Notifications are off",
            comment: "Headline shown for low disk space when notifications cannot be delivered."
        )
    }

    var headlineLowSpaceDeliveryFailed: LocalizedStringResource {
        resource(
            "monitoring.headline.low-space-delivery-failed",
            defaultValue: "Low disk space · Couldn't send alert · Will retry",
            comment: "Headline shown when a low-space notification submission failed."
        )
    }

    var headlineReadFailed: LocalizedStringResource {
        resource(
            "monitoring.headline.read-failed",
            defaultValue: "Couldn't check disk · Will retry",
            comment: "Headline shown when the startup disk could not be read."
        )
    }

    var statusStoppedLoadFailed: LocalizedStringResource {
        resource(
            "monitoring.status.stopped-load-failed",
            defaultValue: "Saved monitoring state couldn't be loaded.",
            comment: "Status detail shown when persisted monitoring state failed to load."
        )
    }

    var statusStopped: LocalizedStringResource {
        resource(
            "monitoring.status.stopped",
            defaultValue: "Monitoring is not running.",
            comment: "Status detail shown when monitoring is stopped."
        )
    }

    var statusStarting: LocalizedStringResource {
        resource(
            "monitoring.status.starting",
            defaultValue: "Restoring saved settings and notification status.",
            comment: "Status detail shown while monitoring starts."
        )
    }

    var statusChecking: LocalizedStringResource {
        resource(
            "monitoring.status.checking",
            defaultValue: "Reading available space on the startup disk.",
            comment: "Status detail shown while reading the startup disk."
        )
    }

    func statusMonitoring(_ threshold: String) -> LocalizedStringResource {
        resource(
            "monitoring.status.monitoring",
            defaultValue: "DiskMeerkat will alert when available space falls below \(threshold).",
            comment: "Healthy status detail. The argument is the localized low-space threshold."
        )
    }

    func statusLowSpace(_ threshold: String) -> LocalizedStringResource {
        resource(
            "monitoring.status.low-space",
            defaultValue: "Available space is below \(threshold).",
            comment: "Low-space status detail. The argument is the localized threshold."
        )
    }

    var statusLowSpaceAlertSent: LocalizedStringResource {
        resource(
            "monitoring.status.low-space-alert-sent",
            defaultValue: "An alert was submitted for this low-space episode.",
            comment: "Status detail shown after a low-space alert was submitted."
        )
    }

    var statusLowSpaceNotificationsOff: LocalizedStringResource {
        resource(
            "monitoring.status.low-space-notifications-off",
            defaultValue: "Monitoring continues, but DiskMeerkat cannot currently send alerts.",
            comment: "Status detail shown when monitoring continues without notification permission."
        )
    }

    var statusLowSpaceDeliveryFailed: LocalizedStringResource {
        resource(
            "monitoring.status.low-space-delivery-failed",
            defaultValue: "Monitoring continues and a later eligible check may retry the alert.",
            comment: "Status detail shown after low-space notification delivery failed."
        )
    }

    var statusReadFailedNoValue: LocalizedStringResource {
        resource(
            "monitoring.status.read-failed-no-value",
            defaultValue: "No successful disk reading is available yet.",
            comment: "Status detail shown when every startup disk read has failed."
        )
    }

    var statusReadFailedWithValue: LocalizedStringResource {
        resource(
            "monitoring.status.read-failed-with-value",
            defaultValue: "The last successful value remains visible.",
            comment: "Status detail shown when a stale successful disk value remains available."
        )
    }

    func suppressionExplanation(_ threshold: String) -> LocalizedStringResource {
        resource(
            "monitoring.suppression-explanation",
            defaultValue:
                "Another alert becomes eligible after available space rises above \(threshold) and later falls below it again.",
            comment: "Explains when another low-space alert can be delivered."
        )
    }
}

extension DiskMeerkatLocalization {
    var permissionNotDeterminedTitle: LocalizedStringResource {
        resource(
            "permission.not-determined.title",
            defaultValue: "Notifications are not enabled",
            comment: "Title shown before notification permission has been requested."
        )
    }

    var permissionNotDeterminedDetail: LocalizedStringResource {
        resource(
            "permission.not-determined.detail",
            defaultValue: "Enable notifications to receive low-space alerts.",
            comment: "Explains why DiskMeerkat requests notification permission."
        )
    }

    var permissionAuthorizedTitle: LocalizedStringResource {
        resource(
            "permission.authorized.title",
            defaultValue: "Notifications are enabled",
            comment: "Title shown when notification permission is available."
        )
    }

    var permissionAuthorizedDetail: LocalizedStringResource {
        resource(
            "permission.authorized.detail",
            defaultValue: "DiskMeerkat can submit low-space alerts.",
            comment: "Explains enabled notification behavior."
        )
    }

    var permissionDeniedTitle: LocalizedStringResource {
        resource(
            "permission.denied.title",
            defaultValue: "Notifications are off",
            comment: "Title shown when notification permission is denied."
        )
    }

    var permissionDeniedDetail: LocalizedStringResource {
        resource(
            "permission.denied.detail",
            defaultValue: "Monitoring continues. Allow alerts in System Settings if you want notifications.",
            comment: "Explains how to enable notifications after permission was denied."
        )
    }

    var permissionUnavailableTitle: LocalizedStringResource {
        resource(
            "permission.unavailable.title",
            defaultValue: "Notification status is unavailable",
            comment: "Title shown when notification permission status cannot be read."
        )
    }

    var permissionUnavailableDetail: LocalizedStringResource {
        resource(
            "permission.unavailable.detail",
            defaultValue: "Monitoring continues without relying on notification permission.",
            comment: "Explains behavior when notification permission status is unavailable."
        )
    }
}

extension DiskMeerkatLocalization {
    var launchAtLoginLoadingTitle: LocalizedStringResource {
        resource(
            "launch-at-login.loading.title",
            defaultValue: "Launch at Login status is loading",
            comment: "Title shown while reading the macOS Open at Login state."
        )
    }

    var launchAtLoginLoadingDetail: LocalizedStringResource {
        resource(
            "launch-at-login.loading.detail",
            defaultValue: "DiskMeerkat is reading the current system setting.",
            comment: "Detail shown while reading the macOS Open at Login state."
        )
    }

    var launchAtLoginDisabledTitle: LocalizedStringResource {
        resource(
            "launch-at-login.disabled.title",
            defaultValue: "Launch at Login is off",
            comment: "Title shown when DiskMeerkat does not open at login."
        )
    }

    var launchAtLoginDisabledDetail: LocalizedStringResource {
        resource(
            "launch-at-login.disabled.detail",
            defaultValue: "DiskMeerkat starts only when you open it.",
            comment: "Detail shown when DiskMeerkat does not open at login."
        )
    }

    var launchAtLoginEnabledTitle: LocalizedStringResource {
        resource(
            "launch-at-login.enabled.title",
            defaultValue: "Launch at Login is on",
            comment: "Title shown when DiskMeerkat opens at login."
        )
    }

    var launchAtLoginEnabledDetail: LocalizedStringResource {
        resource(
            "launch-at-login.enabled.detail",
            defaultValue: "DiskMeerkat starts after you sign in.",
            comment: "Detail shown when DiskMeerkat opens at login."
        )
    }

    var launchAtLoginRequiresApprovalTitle: LocalizedStringResource {
        resource(
            "launch-at-login.requires-approval.title",
            defaultValue: "Launch at Login needs approval",
            comment: "Title shown when macOS requires approval for Open at Login."
        )
    }

    var launchAtLoginRequiresApprovalDetail: LocalizedStringResource {
        resource(
            "launch-at-login.requires-approval.detail",
            defaultValue: "Review DiskMeerkat in Login Items in System Settings.",
            comment: "Explains where to approve DiskMeerkat as a login item."
        )
    }

    var launchAtLoginUnavailableTitle: LocalizedStringResource {
        resource(
            "launch-at-login.unavailable.title",
            defaultValue: "Launch at Login is unavailable",
            comment: "Title shown when the macOS login-item service is unavailable."
        )
    }

    var launchAtLoginUnavailableDetail: LocalizedStringResource {
        resource(
            "launch-at-login.unavailable.detail",
            defaultValue: "The system login-item service couldn't be accessed.",
            comment: "Detail shown when the macOS login-item service is unavailable."
        )
    }

    var launchAtLoginChangedTitle: LocalizedStringResource {
        resource(
            "launch-at-login.changed.title",
            defaultValue: "Launch at Login changed in System Settings",
            comment: "Title shown when Open at Login changed outside DiskMeerkat."
        )
    }

    var launchAtLoginChangedDetail: LocalizedStringResource {
        resource(
            "launch-at-login.changed.detail",
            defaultValue: "DiskMeerkat refreshed the switch to match the actual system state.",
            comment: "Explains that an externally changed login-item switch was refreshed."
        )
    }

    var launchAtLoginEnableFailedTitle: LocalizedStringResource {
        resource(
            "launch-at-login.enable-failed.title",
            defaultValue: "Couldn't enable Launch at Login",
            comment: "Title shown when enabling Open at Login fails."
        )
    }

    var launchAtLoginEnableFailedDetail: LocalizedStringResource {
        resource(
            "launch-at-login.enable-failed.detail",
            defaultValue: "The switch still shows the actual system state. Try again or review Login Items.",
            comment: "Recovery guidance after enabling Open at Login fails."
        )
    }

    var launchAtLoginDisableFailedTitle: LocalizedStringResource {
        resource(
            "launch-at-login.disable-failed.title",
            defaultValue: "Couldn't disable Launch at Login",
            comment: "Title shown when disabling Open at Login fails."
        )
    }

    var launchAtLoginDisableFailedDetail: LocalizedStringResource {
        resource(
            "launch-at-login.disable-failed.detail",
            defaultValue: "The switch still shows the actual system state. Try again or review Login Items.",
            comment: "Recovery guidance after disabling Open at Login fails."
        )
    }
}

extension DiskMeerkatLocalization {
    var noticeDiskReadTitle: LocalizedStringResource {
        resource(
            "notice.disk-read.title",
            defaultValue: "Couldn't check the startup disk",
            comment: "Problem title shown when the startup disk cannot be read."
        )
    }

    var noticeDiskReadNoValueDetail: LocalizedStringResource {
        resource(
            "notice.disk-read.no-value.detail",
            defaultValue: "DiskMeerkat will retry on the next check.",
            comment: "Recovery detail when no successful startup disk reading exists."
        )
    }

    var noticeDiskReadWithValueDetail: LocalizedStringResource {
        resource(
            "notice.disk-read.with-value.detail",
            defaultValue: "The last successful value is shown. DiskMeerkat will retry.",
            comment: "Recovery detail when a stale successful startup disk reading is shown."
        )
    }

    var noticePersistenceLoadTitle: LocalizedStringResource {
        resource(
            "notice.persistence.load.title",
            defaultValue: "Couldn't load saved monitoring state",
            comment: "Problem title shown when persisted monitoring state cannot be loaded."
        )
    }

    var noticePersistenceLoadDetail: LocalizedStringResource {
        resource(
            "notice.persistence.load.detail",
            defaultValue: "Monitoring is stopped so the problem can be reviewed safely.",
            comment: "Detail shown after persisted monitoring state fails to load."
        )
    }

    var noticePersistenceSaveTitle: LocalizedStringResource {
        resource(
            "notice.persistence.save.title",
            defaultValue: "Couldn't save monitoring state",
            comment: "Problem title shown when runtime monitoring state cannot be saved."
        )
    }

    var noticePersistenceSaveDetail: LocalizedStringResource {
        resource(
            "notice.persistence.save.detail",
            defaultValue: "In-memory monitoring continues and DiskMeerkat will retry.",
            comment: "Detail shown after runtime monitoring state fails to save."
        )
    }

    var noticeConfigurationSaveTitle: LocalizedStringResource {
        resource(
            "notice.configuration-save.title",
            defaultValue: "Couldn't save settings",
            comment: "Problem title shown when monitoring settings cannot be saved."
        )
    }

    var noticeConfigurationSaveDetail: LocalizedStringResource {
        resource(
            "notice.configuration-save.detail",
            defaultValue: "The previous settings and schedule remain active.",
            comment: "Detail shown after monitoring settings fail to save."
        )
    }

    var noticeNotificationStatusTitle: LocalizedStringResource {
        resource(
            "notice.notification-status.title",
            defaultValue: "Couldn't read notification status",
            comment: "Problem title shown when notification permission cannot be read."
        )
    }

    var noticeNotificationStatusDetail: LocalizedStringResource {
        resource(
            "notice.notification-status.detail",
            defaultValue: "Disk monitoring continues. Try refreshing notification status later.",
            comment: "Recovery detail after notification permission cannot be read."
        )
    }

    var noticeNotificationPermissionTitle: LocalizedStringResource {
        resource(
            "notice.notification-permission.title",
            defaultValue: "Couldn't update notification permission",
            comment: "Problem title shown when notification permission cannot be requested."
        )
    }

    var noticeNotificationPermissionDetail: LocalizedStringResource {
        resource(
            "notice.notification-permission.detail",
            defaultValue: "Disk monitoring continues without changing the current permission.",
            comment: "Recovery detail after notification permission cannot be updated."
        )
    }

    var noticeNotificationSubmissionTitle: LocalizedStringResource {
        resource(
            "notice.notification-submission.title",
            defaultValue: "Couldn't send the low-space alert",
            comment: "Problem title shown when a low-space notification cannot be submitted."
        )
    }

    var noticeNotificationSubmissionDetail: LocalizedStringResource {
        resource(
            "notice.notification-submission.detail",
            defaultValue: "The episode remains eligible and a later check may retry.",
            comment: "Recovery detail after a low-space notification submission fails."
        )
    }
}

extension DiskMeerkatLocalization {
    func intervalMinutes(_ count: Int) -> LocalizedStringResource {
        if count == 1 {
            return resource(
                "interval.minute.one",
                defaultValue: "1 minute",
                comment: "A monitoring interval of exactly one minute."
            )
        }
        return resource(
            "interval.minute.other",
            defaultValue: "\(count) minutes",
            comment: "A monitoring interval measured in multiple minutes."
        )
    }

    func intervalHours(_ count: Int) -> LocalizedStringResource {
        if count == 1 {
            return resource(
                "interval.hour.one",
                defaultValue: "1 hour",
                comment: "A monitoring interval of exactly one hour."
            )
        }
        return resource(
            "interval.hour.other",
            defaultValue: "\(count) hours",
            comment: "A monitoring interval measured in multiple hours."
        )
    }

    var validationThresholdRequired: LocalizedStringResource {
        resource(
            "validation.threshold.required",
            defaultValue: "Enter a low-space threshold.",
            comment: "Validation message for an empty low-space threshold."
        )
    }

    var validationThresholdWholeNumber: LocalizedStringResource {
        resource(
            "validation.threshold.whole-number",
            defaultValue: "Enter a whole number of decimal GB.",
            comment: "Validation message for a low-space threshold that is not a whole number."
        )
    }

    var validationThresholdRange: LocalizedStringResource {
        resource(
            "validation.threshold.range",
            defaultValue: "Enter a value from 1 through 1,000,000 GB.",
            comment: "Validation message for a low-space threshold outside the supported range."
        )
    }

    var settingsSaveFailed: LocalizedStringResource {
        resource(
            "settings.save-error.failed",
            defaultValue: "Couldn't save settings. Your previous settings remain active.",
            comment: "Error shown when saving monitoring settings fails."
        )
    }

    var settingsSaveNotRunning: LocalizedStringResource {
        resource(
            "settings.save-error.not-running",
            defaultValue: "Monitoring is not running, so settings couldn't be saved.",
            comment: "Error shown when settings cannot be saved because monitoring is stopped."
        )
    }

    var settingsSaveAlreadySaving: LocalizedStringResource {
        resource(
            "settings.save-error.already-saving",
            defaultValue: "Another settings save is still in progress.",
            comment: "Error shown when another settings save is already in progress."
        )
    }
}

extension DiskMeerkatLocalization {
    var badgeStopped: LocalizedStringResource {
        resource("badge.stopped", defaultValue: "Stopped", comment: "Compact stopped status badge.")
    }

    var badgeStarting: LocalizedStringResource {
        resource("badge.starting", defaultValue: "Starting", comment: "Compact starting status badge.")
    }

    var badgeChecking: LocalizedStringResource {
        resource("badge.checking", defaultValue: "Checking", comment: "Compact checking status badge.")
    }

    var badgeMonitoring: LocalizedStringResource {
        resource("badge.monitoring", defaultValue: "Monitoring", comment: "Compact healthy monitoring badge.")
    }

    var badgeLowSpace: LocalizedStringResource {
        resource("badge.low-space", defaultValue: "Low space", comment: "Compact low-space status badge.")
    }

    var badgeCheckFailed: LocalizedStringResource {
        resource("badge.check-failed", defaultValue: "Check failed", comment: "Compact disk-check failure badge.")
    }

    var accessibilityCheckingDisk: LocalizedStringResource {
        resource(
            "accessibility.checking-disk",
            defaultValue: "Checking disk",
            comment: "Accessibility label for an in-progress disk check."
        )
    }

    var accessibilityUpdatingNotificationPermission: LocalizedStringResource {
        resource(
            "accessibility.updating-notification-permission",
            defaultValue: "Updating notification permission",
            comment: "Accessibility label for notification permission progress."
        )
    }

    var accessibilitySavingSettings: LocalizedStringResource {
        resource(
            "accessibility.saving-settings",
            defaultValue: "Saving settings",
            comment: "Accessibility label for settings save progress."
        )
    }

    var accessibilityThreshold: LocalizedStringResource {
        resource(
            "accessibility.threshold",
            defaultValue: "Low-space threshold in decimal gigabytes",
            comment: "Accessibility label for the low-space threshold field."
        )
    }
}

extension DiskMeerkatLocalization {
    var capacitySubtitleAvailable: LocalizedStringResource {
        resource(
            "capacity.subtitle.available",
            defaultValue: "available",
            comment: "Compact subtitle below an available-capacity value."
        )
    }

    var capacitySubtitleAvailableOnStartupDisk: LocalizedStringResource {
        resource(
            "capacity.subtitle.available-on-startup-disk",
            defaultValue: "available on the startup disk",
            comment: "Subtitle below an available-capacity value."
        )
    }

    var capacitySubtitleOnStartupDisk: LocalizedStringResource {
        resource(
            "capacity.subtitle.on-startup-disk",
            defaultValue: "on the startup disk",
            comment: "Subtitle below an unavailable or checking startup-disk capacity."
        )
    }

    var scheduleLastCheck: LocalizedStringResource {
        resource("schedule.last-check", defaultValue: "Last check", comment: "Label for the last disk check time.")
    }

    var scheduleNextCheck: LocalizedStringResource {
        resource("schedule.next-check", defaultValue: "Next check", comment: "Label for the next disk check time.")
    }

    var scheduleNotYet: LocalizedStringResource {
        resource("schedule.not-yet", defaultValue: "Not yet", comment: "Shown before the first successful disk check.")
    }

    var scheduleAfterThisCheck: LocalizedStringResource {
        resource(
            "schedule.after-this-check",
            defaultValue: "After this check",
            comment: "Shown for the next check time while a disk check is in progress."
        )
    }

    var scheduleNotScheduled: LocalizedStringResource {
        resource(
            "schedule.not-scheduled",
            defaultValue: "Not scheduled",
            comment: "Shown when no next disk check is scheduled."
        )
    }
}

extension DiskMeerkatLocalization {
    var actionReady: LocalizedStringResource {
        resource("action.ready", defaultValue: "Ready", comment: "Badge indicating a feature is ready.")
    }

    var actionEnable: LocalizedStringResource {
        resource("action.enable", defaultValue: "Enable", comment: "Button that enables a feature.")
    }

    var actionOpenSettings: LocalizedStringResource {
        resource(
            "action.open-settings",
            defaultValue: "Open Settings",
            comment: "Button that opens the relevant macOS System Settings pane."
        )
    }

    var actionUnavailable: LocalizedStringResource {
        resource(
            "action.unavailable", defaultValue: "Unavailable", comment: "Badge indicating a feature is unavailable.")
    }

    var actionEnabled: LocalizedStringResource {
        resource("action.enabled", defaultValue: "Enabled", comment: "Badge indicating a feature is enabled.")
    }

    var actionSettings: LocalizedStringResource {
        resource("action.settings", defaultValue: "Settings", comment: "Button that opens DiskMeerkat Settings.")
    }

    var actionCancel: LocalizedStringResource {
        resource("action.cancel", defaultValue: "Cancel", comment: "Button that discards Settings edits.")
    }

    var actionSave: LocalizedStringResource {
        resource("action.save", defaultValue: "Save", comment: "Button that saves Settings edits.")
    }

    var actionCheckNow: LocalizedStringResource {
        resource("action.check-now", defaultValue: "Check Now", comment: "Button that starts a disk check immediately.")
    }

    var actionChecking: LocalizedStringResource {
        resource(
            "action.checking", defaultValue: "Checking…", comment: "Disabled action label while a disk check runs.")
    }

    var actionContinue: LocalizedStringResource {
        resource("action.continue", defaultValue: "Continue", comment: "Button that completes onboarding.")
    }

    var actionNotNow: LocalizedStringResource {
        resource(
            "action.not-now", defaultValue: "Not Now", comment: "Button that defers an optional onboarding action.")
    }
}

extension DiskMeerkatLocalization {
    var menuSubtitle: LocalizedStringResource {
        resource(
            "menu.subtitle",
            defaultValue: "Startup disk monitor",
            comment: "Subtitle below the DiskMeerkat name in the menu."
        )
    }

    var menuOpenStatus: LocalizedStringResource {
        resource("menu.open-status", defaultValue: "Open Status", comment: "Button that opens the status window.")
    }

    var menuQuit: LocalizedStringResource {
        resource("menu.quit", defaultValue: "Quit DiskMeerkat", comment: "Button that quits DiskMeerkat.")
    }

    var statusCurrent: LocalizedStringResource {
        resource("status.current", defaultValue: "Current status", comment: "Heading in the status window.")
    }

    var statusAutomaticChecks: LocalizedStringResource {
        resource(
            "status.automatic-checks",
            defaultValue: "Your startup disk is checked automatically in the background.",
            comment: "Explains automatic background disk checks."
        )
    }

    var statusMonitoringSection: LocalizedStringResource {
        resource("status.monitoring", defaultValue: "Monitoring", comment: "Monitoring information card title.")
    }

    var statusAlertBelow: LocalizedStringResource {
        resource("status.alert-below", defaultValue: "Alert below", comment: "Label for the low-space threshold value.")
    }

    var statusCheckEvery: LocalizedStringResource {
        resource("status.check-every", defaultValue: "Check every", comment: "Label for the monitoring interval value.")
    }

    var statusScheduleSection: LocalizedStringResource {
        resource("status.schedule", defaultValue: "Schedule", comment: "Schedule information card title.")
    }
}

extension DiskMeerkatLocalization {
    var onboardingTitle: LocalizedStringResource {
        resource("onboarding.title", defaultValue: "Welcome to DiskMeerkat", comment: "Onboarding welcome title.")
    }

    var onboardingDetail: LocalizedStringResource {
        resource(
            "onboarding.detail",
            defaultValue:
                "DiskMeerkat watches your startup disk and alerts you when available space falls below your limit.",
            comment: "Short explanation of DiskMeerkat during onboarding."
        )
    }

    var onboardingMonitoring: LocalizedStringResource {
        resource("onboarding.monitoring", defaultValue: "Monitoring", comment: "Onboarding monitoring status label.")
    }

    var onboardingLowSpaceAlert: LocalizedStringResource {
        resource("onboarding.low-space-alert", defaultValue: "Low-space alert", comment: "Onboarding threshold label.")
    }

    var onboardingCheckInterval: LocalizedStringResource {
        resource("onboarding.check-interval", defaultValue: "Check interval", comment: "Onboarding interval label.")
    }

    var onboardingEnableNotifications: LocalizedStringResource {
        resource(
            "onboarding.enable-notifications",
            defaultValue: "Enable Notifications",
            comment: "Onboarding button that requests notification permission."
        )
    }

    var onboardingOpenNotificationSettings: LocalizedStringResource {
        resource(
            "onboarding.open-notification-settings",
            defaultValue: "Open Notification Settings",
            comment: "Onboarding button that opens macOS notification settings."
        )
    }
}

extension DiskMeerkatLocalization {
    var settingsMonitoringSection: LocalizedStringResource {
        resource(
            "settings.section.monitoring", defaultValue: "Monitoring", comment: "Settings monitoring section title.")
    }

    var settingsStartupDisk: LocalizedStringResource {
        resource("settings.startup-disk", defaultValue: "Startup disk", comment: "Settings label for the startup disk.")
    }

    var settingsAlertThreshold: LocalizedStringResource {
        resource(
            "settings.alert-threshold",
            defaultValue: "Alert threshold",
            comment: "Settings label for the low-space threshold."
        )
    }

    var settingsAlertThresholdDetail: LocalizedStringResource {
        resource(
            "settings.alert-threshold.detail",
            defaultValue: "Notify when available space is below this value.",
            comment: "Settings help text for the low-space threshold."
        )
    }

    var settingsThresholdField: LocalizedStringResource {
        resource(
            "settings.threshold-field",
            defaultValue: "Threshold",
            comment: "Placeholder and label for the low-space threshold field."
        )
    }

    var settingsGigabytesUnit: LocalizedStringResource {
        resource("settings.gigabytes-unit", defaultValue: "GB", comment: "Gigabyte unit beside the threshold field.")
    }

    var settingsCheckInterval: LocalizedStringResource {
        resource(
            "settings.check-interval",
            defaultValue: "Check interval",
            comment: "Settings label for the automatic disk-check interval."
        )
    }

    var settingsNotificationsSection: LocalizedStringResource {
        resource(
            "settings.section.notifications",
            defaultValue: "Notifications",
            comment: "Settings notification section title."
        )
    }

    var settingsLowSpaceAlerts: LocalizedStringResource {
        resource(
            "settings.low-space-alerts", defaultValue: "Low-space alerts", comment: "Settings notification row title.")
    }

    var settingsStartupSection: LocalizedStringResource {
        resource("settings.section.startup", defaultValue: "Startup", comment: "Settings startup section title.")
    }

    var settingsLaunchAtLogin: LocalizedStringResource {
        resource(
            "settings.launch-at-login",
            defaultValue: "Launch at Login",
            comment: "Settings label for opening DiskMeerkat at login."
        )
    }

    var settingsLoginItems: LocalizedStringResource {
        resource(
            "settings.login-items",
            defaultValue: "Login Items",
            comment: "Settings label for the macOS Login Items pane."
        )
    }
}

extension DiskMeerkatLocalization {
    var notificationTitle: LocalizedStringResource {
        resource(
            "notification.low-space.title",
            defaultValue: "Disk space is low",
            comment: "Title of an immediate low-space notification."
        )
    }

    func notificationBody(
        volumeName: String,
        availableCapacity: String,
        threshold: String
    ) -> LocalizedStringResource {
        resource(
            "notification.low-space.body",
            defaultValue:
                "\(volumeName) has \(availableCapacity) available, below your \(threshold) limit.",
            comment:
                "Body of an immediate low-space notification. Arguments are disk name, available capacity, and threshold."
        )
    }
}
