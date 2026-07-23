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
                    Text(verbatim: "DiskMeerkat")
                        .font(.subheadline.weight(.semibold))
                    Text(DiskMeerkatLocalization.current.menuSubtitle)
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
                                ? DiskMeerkatLocalization.current.actionChecking
                                : DiskMeerkatLocalization.current.actionCheckNow,
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuCheckNow)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canCheckNow)
                    .keyboardShortcut("r", modifiers: .command)

                    Button {
                        actions.openStatus()
                    } label: {
                        Text(DiskMeerkatLocalization.current.menuOpenStatus)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuOpenStatus)
                }
                .controlSize(.regular)
            }
            .padding(16)

            Divider()

            HStack {
                Button(action: actions.openSettings) {
                    Text(DiskMeerkatLocalization.current.actionSettings)
                }
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuOpenSettings)
                Spacer()
                Button(action: actions.quit) {
                    Text(DiskMeerkatLocalization.current.menuQuit)
                }
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
                            Text(DiskMeerkatLocalization.current.statusCurrent)
                                .font(.title2.weight(.semibold))
                            Text(DiskMeerkatLocalization.current.statusAutomaticChecks)
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
                        MonitoringInfoCard(
                            title: DiskMeerkatLocalization.current.statusMonitoringSection,
                            systemImage: "slider.horizontal.3"
                        ) {
                            MonitoringInfoRow(
                                DiskMeerkatLocalization.current.statusAlertBelow
                            ) {
                                Text(state.thresholdValueText)
                            }
                            MonitoringInfoRow(
                                DiskMeerkatLocalization.current.statusCheckEvery
                            ) {
                                Text(state.intervalText)
                            }
                        }

                        MonitoringInfoCard(
                            title: DiskMeerkatLocalization.current.statusScheduleSection,
                            systemImage: "clock"
                        ) {
                            MonitoringInfoRow(
                                DiskMeerkatLocalization.current.scheduleLastCheck
                            ) {
                                MonitoringRelativeDateView(
                                    date: state.lastSuccessfulCheckAt,
                                    fallback: DiskMeerkatLocalization.current.scheduleNotYet
                                )
                            }
                            MonitoringInfoRow(
                                DiskMeerkatLocalization.current.scheduleNextCheck
                            ) {
                                MonitoringRelativeDateView(
                                    date: state.nextScheduledCheckAt,
                                    fallback: state.isCheckInProgress
                                        ? DiskMeerkatLocalization.current.scheduleAfterThisCheck
                                        : DiskMeerkatLocalization.current.scheduleNotScheduled
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
                Button(action: openSettings) {
                    Text(DiskMeerkatLocalization.current.actionSettings)
                }
                .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button {
                    Task { await model.checkNow() }
                } label: {
                    Label(
                        state.isCheckInProgress || model.isRequestingCheck
                            ? DiskMeerkatLocalization.current.actionChecking
                            : DiskMeerkatLocalization.current.actionCheckNow,
                        systemImage: "arrow.clockwise"
                    )
                }
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.statusCheckNow)
                .buttonStyle(.borderedProminent)
                .disabled(!model.canCheckNow)
                .keyboardShortcut("r", modifiers: .command)
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
                    DiskMeerkatSettingsSection(
                        title: DiskMeerkatLocalization.current.settingsMonitoringSection
                    ) {
                        DiskMeerkatSettingsRow(
                            title: DiskMeerkatLocalization.current.settingsStartupDisk
                        ) {
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
                            title: DiskMeerkatLocalization.current.settingsAlertThreshold,
                            detail: DiskMeerkatLocalization.current.settingsAlertThresholdDetail
                        ) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TextField(text: $model.settingsDraft.thresholdText) {
                                    Text(DiskMeerkatLocalization.current.settingsThresholdField)
                                }
                                .frame(width: 74)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel(
                                    DiskMeerkatLocalization.current.accessibilityThreshold
                                )
                                .accessibilityIdentifier(
                                    DiskMeerkatAccessibilityIdentifiers.settingsThreshold
                                )
                                Text(DiskMeerkatLocalization.current.settingsGigabytesUnit)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = model.settingsDraft.thresholdError {
                            let message = error.message(localization: model.localization)
                            let resolvedMessage = model.localization.resolve(message)
                            Text(message)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.horizontal, 13)
                                .padding(.bottom, 8)
                                .accessibilityLabel(
                                    model.localization.thresholdErrorAccessibilityLabel(
                                        resolvedMessage
                                    )
                                )
                        }

                        DiskMeerkatSettingsDivider()

                        DiskMeerkatSettingsRow(
                            title: DiskMeerkatLocalization.current.settingsCheckInterval
                        ) {
                            Picker(
                                DiskMeerkatLocalization.current.settingsCheckInterval,
                                selection: $model.settingsDraft.interval
                            ) {
                                ForEach(CheckInterval.allCases, id: \.rawValue) { interval in
                                    Text(interval.displayName(localization: model.localization))
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

                    DiskMeerkatSettingsSection(
                        title: DiskMeerkatLocalization.current.settingsNotificationsSection
                    ) {
                        DiskMeerkatSettingsRow(
                            title: DiskMeerkatLocalization.current.settingsLowSpaceAlerts,
                            detail: state.notificationPermission.title
                        ) {
                            settingsNotificationAction
                        }
                    }

                    DiskMeerkatSettingsSection(
                        title: DiskMeerkatLocalization.current.settingsStartupSection
                    ) {
                        DiskMeerkatSettingsRow(
                            title: DiskMeerkatLocalization.current.settingsLaunchAtLogin,
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
                                title: DiskMeerkatLocalization.current.settingsLoginItems,
                                detail: state.launchAtLogin.detail
                            ) {
                                Button {
                                    Task { await model.openLaunchAtLoginSettings() }
                                } label: {
                                    Text(DiskMeerkatLocalization.current.actionOpenSettings)
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
                Button {
                    model.cancelSettingsEditing()
                    dismiss()
                } label: {
                    Text(DiskMeerkatLocalization.current.actionCancel)
                }
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsCancel)
                .keyboardShortcut(.cancelAction)
                .disabled(model.isSavingSettings || state.isSavingConfiguration)

                if model.isSavingSettings || state.isSavingConfiguration {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(
                            DiskMeerkatLocalization.current.accessibilitySavingSettings
                        )
                }

                Button {
                    Task {
                        if await model.saveSettings() {
                            dismiss()
                        }
                    }
                } label: {
                    Text(DiskMeerkatLocalization.current.actionSave)
                }
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsSave)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSaveSettings)
            }
            .controlSize(.regular)
            .accessibilityElement(children: .contain)
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
                .accessibilityLabel(
                    DiskMeerkatLocalization.current.accessibilityUpdatingNotificationPermission
                )
        } else if permission.kind == .authorized {
            MonitoringInlineBadge(
                text: DiskMeerkatLocalization.current.actionEnabled,
                tint: .green
            )
        } else if permission.canRequestAuthorization {
            Button {
                Task { await model.enableNotifications() }
            } label: {
                Text(DiskMeerkatLocalization.current.actionEnable)
            }
            .accessibilityIdentifier(
                DiskMeerkatAccessibilityIdentifiers.settingsEnableNotifications
            )
        } else if permission.canOpenSettings {
            Button {
                Task { await model.openNotificationSettings() }
            } label: {
                Text(DiskMeerkatLocalization.current.actionOpenSettings)
            }
            .accessibilityIdentifier(
                DiskMeerkatAccessibilityIdentifiers.settingsOpenNotificationSettings
            )
        } else {
            MonitoringInlineBadge(
                text: DiskMeerkatLocalization.current.actionUnavailable,
                tint: .orange
            )
        }
    }
}

private struct DiskMeerkatSettingsSection<Content: View>: View {
    let title: LocalizedStringResource
    let content: Content

    init(title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .textCase(.uppercase)
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
    let title: LocalizedStringResource
    let detail: LocalizedStringResource?
    let control: Control

    init(
        title: LocalizedStringResource,
        detail: LocalizedStringResource? = nil,
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
