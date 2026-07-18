import SwiftUI

@MainActor
public struct DiskMeerkatSurfaceActions {
    public var openStatus: () -> Void
    public var openSettings: () -> Void
    public var quit: () -> Void

    public init(
        openStatus: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.openStatus = openStatus
        self.openSettings = openSettings
        self.quit = quit
    }
}

public struct DiskMeerkatMenuBarLabel: View {
    let model: DiskMeerkatPresentationModel

    public init(model: DiskMeerkatPresentationModel) {
        self.model = model
    }

    public var body: some View {
        Image(systemName: model.presentation.symbolName)
            .accessibilityLabel(model.presentation.statusAccessibilityLabel)
            .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuBarStatus)
    }
}

public struct DiskMeerkatMenuView: View {
    let model: DiskMeerkatPresentationModel
    let actions: DiskMeerkatSurfaceActions

    public init(
        model: DiskMeerkatPresentationModel,
        actions: DiskMeerkatSurfaceActions
    ) {
        self.model = model
        self.actions = actions
    }

    public var body: some View {
        let state = model.presentation

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                    Image(systemName: "internaldrive")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.tint)
                }
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("DiskMeerkat")
                        .font(.subheadline.weight(.semibold))
                    Text("Startup disk monitor")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                MonitoringStatusBadge(state: state)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuStatus)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                MonitoringCapacityHeroView(
                    state: state,
                    compact: true,
                    showsFacts: true,
                    capacityIdentifier: DiskMeerkatAccessibilityIdentifiers.menuCapacity
                )

                MonitoringScheduleStripView(state: state)

                if let notice = state.notices.first {
                    MonitoringNoticeView(notice: notice)
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await model.checkNow() }
                    } label: {
                        Label(
                            state.isCheckInProgress || model.isRequestingCheck
                                ? "Checking…" : "Check Now",
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canCheckNow)
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuCheckNow)

                    Button {
                        actions.openStatus()
                    } label: {
                        Text("Open Status")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuOpenStatus)
                }
                .controlSize(.regular)
            }
            .padding(16)

            Divider()

            HStack {
                Button("Settings", action: actions.openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuOpenSettings)
                Spacer()
                Button("Quit DiskMeerkat", action: actions.quit)
                    .keyboardShortcut("q", modifiers: .command)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuQuit)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .frame(width: 370)
    }
}

public struct DiskMeerkatOnboardingView: View {
    let model: DiskMeerkatPresentationModel

    public init(model: DiskMeerkatPresentationModel) {
        self.model = model
    }

    public var body: some View {
        let state = model.presentation

        if state.shouldShowOnboarding {
            OnboardingView(
                state: state,
                isUpdatingNotificationPermission: model.isUpdatingNotificationPermission,
                isCompleting: model.isCompletingOnboarding,
                enableNotifications: {
                    Task { await model.enableNotificationsAndCompleteOnboarding() }
                },
                openNotificationSettings: {
                    Task { await model.openNotificationSettings() }
                },
                dismiss: {
                    Task { await model.completeOnboarding() }
                }
            )
        }
    }
}

public struct DiskMeerkatStatusView: View {
    let model: DiskMeerkatPresentationModel
    let openSettings: () -> Void

    public init(
        model: DiskMeerkatPresentationModel,
        openSettings: @escaping () -> Void
    ) {
        self.model = model
        self.openSettings = openSettings
    }

    public var body: some View {
        let state = model.presentation

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Current status")
                                .font(.title2.weight(.semibold))
                            Text("Your startup disk is checked automatically in the background.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        MonitoringStatusBadge(state: state)
                    }

                    if state.shouldShowOnboarding {
                        DiskMeerkatOnboardingView(model: model)
                    }

                    MonitoringCapacityHeroView(state: state)

                    HStack(alignment: .top, spacing: 12) {
                        MonitoringInfoCard(title: "Monitoring", systemImage: "slider.horizontal.3") {
                            MonitoringInfoRow("Alert below") {
                                Text(thresholdValue(for: state))
                            }
                            MonitoringInfoRow("Check every") {
                                Text(state.intervalText)
                            }
                        }

                        MonitoringInfoCard(title: "Schedule", systemImage: "clock") {
                            MonitoringInfoRow("Last check") {
                                MonitoringRelativeDateView(
                                    date: state.lastSuccessfulCheckAt,
                                    fallback: "Not yet"
                                )
                            }
                            MonitoringInfoRow("Next check") {
                                MonitoringRelativeDateView(
                                    date: state.nextScheduledCheckAt,
                                    fallback: state.isCheckInProgress
                                        ? "After this check" : "Not scheduled"
                                )
                            }
                        }
                    }

                    if let suppressionExplanation = state.suppressionExplanation {
                        Label(suppressionExplanation, systemImage: "bell.badge")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.primary.opacity(0.045),
                                in: RoundedRectangle(cornerRadius: 11)
                            )
                    }

                    ForEach(state.notices) { notice in
                        MonitoringNoticeView(notice: notice)
                    }

                    if !state.shouldShowOnboarding {
                        NotificationPermissionView(
                            permission: state.notificationPermission,
                            isWorking: model.isUpdatingNotificationPermission,
                            enable: {
                                Task { await model.enableNotifications() }
                            },
                            openSettings: {
                                Task { await model.openNotificationSettings() }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }

            Divider()

            HStack(spacing: 8) {
                Button("Settings", action: openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button {
                    Task { await model.checkNow() }
                } label: {
                    Label(
                        state.isCheckInProgress || model.isRequestingCheck
                            ? "Checking…" : "Check Now",
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canCheckNow)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.statusCheckNow)
            }
            .controlSize(.regular)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
        }
        .frame(
            minWidth: 560,
            idealWidth: 640,
            maxWidth: .infinity,
            minHeight: 480,
            idealHeight: 540,
            maxHeight: .infinity
        )
        .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.statusRoot)
        .task {
            await model.refreshExternalState()
        }
    }

    private func thresholdValue(for state: MonitoringPresentationState) -> String {
        state.thresholdText.replacingOccurrences(of: "Alert below ", with: "")
    }
}

public struct DiskMeerkatSettingsView: View {
    let model: DiskMeerkatPresentationModel
    @Environment(\.dismiss) private var dismiss

    public init(model: DiskMeerkatPresentationModel) {
        self.model = model
    }

    public var body: some View {
        @Bindable var model = model
        let state = model.presentation

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    DiskMeerkatSettingsSection(title: "Monitoring") {
                        DiskMeerkatSettingsRow(title: "Startup disk") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(state.volumeName)
                                    .fontWeight(.semibold)
                                Text(state.availableSpaceText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        DiskMeerkatSettingsDivider()

                        DiskMeerkatSettingsRow(
                            title: "Alert threshold",
                            detail: "Notify when available space is below this value."
                        ) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TextField("Threshold", text: $model.settingsDraft.thresholdText)
                                    .frame(width: 74)
                                    .multilineTextAlignment(.trailing)
                                    .accessibilityLabel("Low-space threshold in decimal gigabytes")
                                    .accessibilityIdentifier(
                                        DiskMeerkatAccessibilityIdentifiers.settingsThreshold
                                    )
                                Text("GB")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = model.settingsDraft.thresholdError {
                            Text(error.message)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.horizontal, 13)
                                .padding(.bottom, 8)
                                .accessibilityLabel("Threshold error: \(error.message)")
                        }

                        DiskMeerkatSettingsDivider()

                        DiskMeerkatSettingsRow(title: "Check interval") {
                            Picker("Check interval", selection: $model.settingsDraft.interval) {
                                ForEach(CheckInterval.allCases, id: \.rawValue) { interval in
                                    Text(interval.displayName)
                                        .tag(interval)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            .accessibilityIdentifier(
                                DiskMeerkatAccessibilityIdentifiers.settingsInterval
                            )
                        }
                    }
                    .disabled(model.isSavingSettings || state.isSavingConfiguration)

                    DiskMeerkatSettingsSection(title: "Notifications") {
                        DiskMeerkatSettingsRow(
                            title: "Low-space alerts",
                            detail: state.notificationPermission.title
                        ) {
                            settingsNotificationAction
                        }
                    }

                    DiskMeerkatSettingsSection(title: "Startup") {
                        DiskMeerkatSettingsRow(
                            title: "Launch at Login",
                            detail: state.launchAtLogin.title
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { state.launchAtLogin.isEnabled },
                                    set: { isEnabled in
                                        Task { await model.setLaunchAtLoginEnabled(isEnabled) }
                                    }
                                )
                            )
                            .labelsHidden()
                            .disabled(
                                !state.launchAtLogin.canToggle || model.isUpdatingLaunchAtLogin
                            )
                            .accessibilityIdentifier(
                                DiskMeerkatAccessibilityIdentifiers.settingsLaunchAtLogin
                            )
                        }

                        if state.launchAtLogin.canOpenSettings {
                            DiskMeerkatSettingsDivider()
                            DiskMeerkatSettingsRow(
                                title: "Login Items",
                                detail: state.launchAtLogin.detail
                            ) {
                                Button("Open Settings") {
                                    Task { await model.openLaunchAtLoginSettings() }
                                }
                                .disabled(model.isUpdatingLaunchAtLogin)
                                .accessibilityIdentifier(
                                    DiskMeerkatAccessibilityIdentifiers.settingsOpenLoginSettings
                                )
                            }
                        }
                    }

                    if let error = model.settingsSaveError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 17)
            }

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    model.cancelSettingsEditing()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isSavingSettings || state.isSavingConfiguration)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsCancel)

                if model.isSavingSettings || state.isSavingConfiguration {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Saving settings")
                }

                Button("Save") {
                    Task {
                        if await model.saveSettings() {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSaveSettings)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsSave)
            }
            .controlSize(.regular)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
        }
        .frame(width: 500, height: 470)
        .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsRoot)
        .onAppear {
            model.beginSettingsEditing()
        }
        .onDisappear {
            model.cancelSettingsEditing()
        }
        .task {
            await model.refreshExternalState()
        }
    }

    @ViewBuilder
    private var settingsNotificationAction: some View {
        let permission = model.presentation.notificationPermission

        if model.isUpdatingNotificationPermission {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Updating notification permission")
        } else if permission.kind == .authorized {
            MonitoringInlineBadge(text: "Enabled", tint: .green)
        } else if permission.canRequestAuthorization {
            Button("Enable") {
                Task { await model.enableNotifications() }
            }
            .accessibilityIdentifier(
                DiskMeerkatAccessibilityIdentifiers.settingsEnableNotifications
            )
        } else if permission.canOpenSettings {
            Button("Open Settings") {
                Task { await model.openNotificationSettings() }
            }
            .accessibilityIdentifier(
                DiskMeerkatAccessibilityIdentifiers.settingsOpenNotificationSettings
            )
        } else {
            MonitoringInlineBadge(text: "Unavailable", tint: .orange)
        }
    }
}

private struct DiskMeerkatSettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            VStack(spacing: 0) {
                content
            }
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.09))
            }
        }
    }
}

private struct DiskMeerkatSettingsRow<Control: View>: View {
    let title: String
    let detail: String?
    let control: Control

    init(
        title: String,
        detail: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
    }
}

private struct DiskMeerkatSettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 13)
    }
}

#if DEBUG
    #Preview("Menu · Healthy") {
        DiskMeerkatMenuView(
            model: DiskMeerkatPreviewFixtures.healthyModel(),
            actions: DiskMeerkatSurfaceActions(
                openStatus: {},
                openSettings: {},
                quit: {}
            )
        )
    }

    #Preview("Status · First run") {
        DiskMeerkatStatusView(
            model: DiskMeerkatPreviewFixtures.firstRunModel(),
            openSettings: {}
        )
    }

    #Preview("Status · Low space, notifications off") {
        DiskMeerkatStatusView(
            model: DiskMeerkatPreviewFixtures.lowSpaceDeniedModel(),
            openSettings: {}
        )
    }

    #Preview("Status · Read failure") {
        DiskMeerkatStatusView(
            model: DiskMeerkatPreviewFixtures.readFailureModel(),
            openSettings: {}
        )
    }

    #Preview("Settings · Invalid threshold") {
        DiskMeerkatSettingsView(
            model: DiskMeerkatPreviewFixtures.invalidSettingsModel()
        )
    }
#endif
