import SwiftUI

struct MonitoringStatusBadge: View {
    let state: MonitoringPresentationState

    var body: some View {
        MonitoringInlineBadge(text: badgeText, tint: tint)
    }

    private var badgeText: String {
        switch state.headline {
        case .stopped:
            "Stopped"
        case .starting:
            "Starting"
        case .checking:
            "Checking"
        case .monitoring:
            "Monitoring"
        case .lowSpace, .lowSpaceAlertSent, .lowSpaceNotificationsOff,
            .lowSpaceDeliveryFailed:
            "Low space"
        case .readFailed:
            "Check failed"
        }
    }

    private var tint: Color {
        switch state.headline {
        case .starting, .checking:
            .accentColor
        case .monitoring:
            .green
        case .stopped, .lowSpace, .lowSpaceAlertSent, .lowSpaceNotificationsOff,
            .lowSpaceDeliveryFailed, .readFailed:
            .orange
        }
    }
}

struct MonitoringInlineBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.11), in: Capsule())
    }
}

struct MonitoringSummaryView: View {
    let state: MonitoringPresentationState
    var compact = false
    var capacityIdentifier = DiskMeerkatAccessibilityIdentifiers.statusCapacity

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 14) {
            HStack {
                MonitoringStatusBadge(state: state)
                Spacer()
                if state.isCheckInProgress {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Checking disk")
                }
            }

            MonitoringCapacityHeroView(
                state: state,
                compact: compact,
                showsFacts: compact,
                capacityIdentifier: capacityIdentifier
            )
        }
    }
}

struct MonitoringCapacityHeroView: View {
    let state: MonitoringPresentationState
    var compact = false
    var showsFacts = false
    var capacityIdentifier = DiskMeerkatAccessibilityIdentifiers.statusCapacity

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.volumeName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(capacityValueText)
                        .font(.system(size: compact ? 30 : 36, weight: .semibold))
                        .tracking(-1.1)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text(capacityCaptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(state.capacityAccessibilityLabel)
                .accessibilityIdentifier(capacityIdentifier)

                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                        .fill(heroTint.opacity(0.11))
                    Image(systemName: state.symbolName)
                        .font(.system(size: compact ? 23 : 29, weight: .medium))
                        .foregroundStyle(heroTint)
                }
                .frame(width: compact ? 52 : 68, height: compact ? 52 : 68)
                .accessibilityHidden(true)
            }

            if !compact && state.headline != .monitoring {
                Text(state.headline.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(heroTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(state.statusDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if showsFacts {
                HStack(spacing: 8) {
                    MonitoringFactPill(text: state.thresholdText, systemImage: "bell")
                    MonitoringFactPill(text: state.intervalText, systemImage: "clock")
                }
            }
        }
        .padding(compact ? 0 : 19)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
        }
        .overlay {
            if !compact {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09))
            }
        }
    }

    private var heroTint: Color {
        state.headline.requiresAttention ? .orange : .accentColor
    }

    private var capacityValueText: String {
        let suffix = " available"
        guard state.availableSpaceText.hasSuffix(suffix) else {
            return state.availableSpaceText
        }
        return String(state.availableSpaceText.dropLast(suffix.count))
    }

    private var capacityCaptionText: String {
        state.availableSpaceText.hasSuffix(" available")
            ? (compact ? "available" : "available on the startup disk")
            : "on the startup disk"
    }
}

struct MonitoringFactPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.055), in: Capsule())
    }
}

struct MonitoringScheduleStripView: View {
    let state: MonitoringPresentationState

    var body: some View {
        HStack(spacing: 12) {
            scheduleItem(title: "Last check", date: state.lastSuccessfulCheckAt, fallback: "Not yet")
            Divider()
                .frame(height: 32)
            scheduleItem(
                title: "Next check",
                date: state.nextScheduledCheckAt,
                fallback: state.isCheckInProgress ? "After this check" : "Not scheduled"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private func scheduleItem(title: String, date: Date?, fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            MonitoringRelativeDateView(date: date, fallback: fallback)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MonitoringRelativeDateView: View {
    let date: Date?
    let fallback: String

    var body: some View {
        if let date {
            Text(date, style: .relative)
                .monospacedDigit()
        } else {
            Text(fallback)
        }
    }
}

struct MonitoringInfoCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.hierarchical)
                .tint(.accentColor)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.primary.opacity(0.09))
        }
    }
}

struct MonitoringInfoRow<Value: View>: View {
    let label: String
    let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            value
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .padding(.top, 7)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

struct MonitoringNoticeView: View {
    let notice: MonitoringNotice

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(notice.title)
                    .font(.headline)
                Text(notice.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(.orange.opacity(0.16))
        }
    }
}

struct NotificationPermissionView: View {
    let permission: NotificationPermissionPresentation
    let isWorking: Bool
    let enable: () -> Void
    let openSettings: () -> Void
    var enableIdentifier = DiskMeerkatAccessibilityIdentifiers.statusEnableNotifications
    var openSettingsIdentifier =
        DiskMeerkatAccessibilityIdentifiers.statusOpenNotificationSettings

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(permissionTint.opacity(0.11))
                Image(systemName: permission.kind == .authorized ? "bell.badge.fill" : "bell.slash")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(permissionTint)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.caption.weight(.semibold))
                Text(permission.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            permissionAction
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.primary.opacity(0.09))
        }
    }

    @ViewBuilder
    private var permissionAction: some View {
        if isWorking {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Updating notification permission")
        } else if permission.kind == .authorized {
            MonitoringInlineBadge(text: "Ready", tint: .green)
        } else if permission.canRequestAuthorization {
            Button("Enable", action: enable)
                .accessibilityIdentifier(enableIdentifier)
        } else if permission.canOpenSettings {
            Button("Open Settings", action: openSettings)
                .accessibilityIdentifier(openSettingsIdentifier)
        } else {
            MonitoringInlineBadge(text: "Unavailable", tint: .orange)
        }
    }

    private var permissionTint: Color {
        permission.kind == .authorized ? .green : .orange
    }
}

struct OnboardingView: View {
    let state: MonitoringPresentationState
    let isUpdatingNotificationPermission: Bool
    let isCompleting: Bool
    let enableNotifications: () -> Void
    let openNotificationSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Welcome to DiskMeerkat", systemImage: "internaldrive")
                .font(.title2.weight(.semibold))
            Text("DiskMeerkat watches your startup disk and alerts you when available space falls below your limit.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Monitoring")
                        .foregroundStyle(.secondary)
                    Text(state.volumeName)
                }
                GridRow {
                    Text("Low-space alert")
                        .foregroundStyle(.secondary)
                    Text(state.thresholdText.replacingOccurrences(of: "Alert below ", with: "Below "))
                }
                GridRow {
                    Text("Check interval")
                        .foregroundStyle(.secondary)
                    Text(state.intervalText)
                }
            }

            HStack {
                if state.notificationPermission.canRequestAuthorization {
                    Button("Enable Notifications", action: enableNotifications)
                        .buttonStyle(.borderedProminent)
                        .disabled(isUpdatingNotificationPermission || isCompleting)
                        .accessibilityIdentifier(
                            DiskMeerkatAccessibilityIdentifiers.statusEnableNotifications
                        )
                } else if state.notificationPermission.canOpenSettings {
                    Button("Open Notification Settings", action: openNotificationSettings)
                        .disabled(isUpdatingNotificationPermission || isCompleting)
                        .accessibilityIdentifier(
                            DiskMeerkatAccessibilityIdentifiers.statusOpenNotificationSettings
                        )
                }
                Button(
                    state.notificationPermission.kind == .authorized ? "Continue" : "Not Now",
                    action: dismiss
                )
                .disabled(isCompleting)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier(
                    DiskMeerkatAccessibilityIdentifiers.statusDismissOnboarding
                )
            }
        }
        .padding(20)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.blue.opacity(0.13))
        }
    }
}
