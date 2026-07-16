import SwiftUI

struct MonitoringSummaryView: View {
    let state: MonitoringPresentationState
    var compact = false
    var capacityIdentifier = DiskMeerkatAccessibilityIdentifiers.statusCapacity

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(state.headline.text, systemImage: state.symbolName)
                    .font(compact ? .headline : .title2.weight(.semibold))
                    .foregroundStyle(state.headline.requiresAttention ? .orange : .primary)
                Spacer()
                if state.isCheckInProgress {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Checking disk")
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(state.volumeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(state.availableSpaceText)
                    .font(compact ? .title2.weight(.semibold) : .largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(state.capacityAccessibilityLabel)
            .accessibilityIdentifier(capacityIdentifier)

            Text(state.statusDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label(state.thresholdText, systemImage: "bell")
                Label(state.intervalText, systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(compact ? 0 : 20)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary.opacity(0.45))
            }
        }
    }
}

struct MonitoringScheduleView: View {
    let state: MonitoringPresentationState

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
            GridRow {
                Text("Last successful check")
                    .foregroundStyle(.secondary)
                if let date = state.lastSuccessfulCheckAt {
                    Text(date, style: .relative)
                        .monospacedDigit()
                } else {
                    Text("Not yet")
                }
            }
            GridRow {
                Text("Next check")
                    .foregroundStyle(.secondary)
                if state.isCheckInProgress {
                    Text("After the current check")
                } else if let date = state.nextScheduledCheckAt {
                    Text(date, style: .relative)
                        .monospacedDigit()
                } else {
                    Text("Not scheduled")
                }
            }
        }
        .font(.callout)
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
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permission.kind == .authorized ? "bell.badge.fill" : "bell.slash")
                .font(.title3)
                .foregroundStyle(permission.kind == .authorized ? .green : .orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(permission.title)
                    .font(.headline)
                Text(permission.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if permission.canRequestAuthorization {
                    Button("Enable Notifications", action: enable)
                        .disabled(isWorking)
                        .accessibilityIdentifier(enableIdentifier)
                } else if permission.canOpenSettings {
                    Button("Open System Settings", action: openSettings)
                        .disabled(isWorking)
                        .accessibilityIdentifier(openSettingsIdentifier)
                }
            }
            Spacer(minLength: 0)
            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Updating notification permission")
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
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
                .font(.title.weight(.semibold))
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
        .padding(22)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
