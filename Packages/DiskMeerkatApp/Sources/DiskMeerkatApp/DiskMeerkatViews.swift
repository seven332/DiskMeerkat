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

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("DiskMeerkat")
                    .font(.headline)
                Spacer()
                Text(state.headline.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuStatus)
            }

            MonitoringSummaryView(
                state: state,
                compact: true,
                capacityIdentifier: DiskMeerkatAccessibilityIdentifiers.menuCapacity
            )

            MonitoringScheduleView(state: state)

            if let notice = state.notices.first {
                MonitoringNoticeView(notice: notice)
            }

            HStack {
                Button {
                    Task { await model.checkNow() }
                } label: {
                    if state.isCheckInProgress {
                        Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Check Now", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(!state.canCheckNow)
                .keyboardShortcut("r", modifiers: .command)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuCheckNow)

                Button("Open Status", action: actions.openStatus)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuOpenStatus)
            }

            Divider()

            HStack {
                Button("Settings…", action: actions.openSettings)
                    .keyboardShortcut(",", modifiers: .command)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuOpenSettings)
                Spacer()
                Button("Quit DiskMeerkat", action: actions.quit)
                    .keyboardShortcut("q", modifiers: .command)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.menuQuit)
            }
        }
        .padding(16)
        .frame(width: 340)
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
                isRequestingAuthorization: model.isRequestingNotificationAuthorization,
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

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if state.shouldShowOnboarding {
                    DiskMeerkatOnboardingView(model: model)
                }

                MonitoringSummaryView(state: state)
                MonitoringScheduleView(state: state)

                HStack {
                    Button {
                        Task { await model.checkNow() }
                    } label: {
                        if state.isCheckInProgress {
                            Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Check Now", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.canCheckNow)
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.statusCheckNow)

                    Button("Settings…", action: openSettings)
                        .keyboardShortcut(",", modifiers: .command)
                }

                if let suppressionExplanation = state.suppressionExplanation {
                    Label(suppressionExplanation, systemImage: "bell.badge")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(state.notices) { notice in
                    MonitoringNoticeView(notice: notice)
                }

                if !state.shouldShowOnboarding {
                    NotificationPermissionView(
                        permission: state.notificationPermission,
                        isWorking: model.isRequestingNotificationAuthorization,
                        enable: {
                            Task { await model.enableNotifications() }
                        },
                        openSettings: {
                            Task { await model.openNotificationSettings() }
                        }
                    )
                }
            }
            .padding(24)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 460, idealHeight: 600)
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

        Form {
            Section("Monitoring") {
                LabeledContent("Monitored volume") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(state.volumeName)
                        Text(state.availableSpaceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Notify me when available space falls below") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("Threshold", text: $model.settingsDraft.thresholdText)
                            .frame(width: 110)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Low-space threshold in decimal gigabytes")
                            .accessibilityIdentifier(
                                DiskMeerkatAccessibilityIdentifiers.settingsThreshold
                            )
                        Text("GB")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = model.settingsDraft.thresholdError {
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("Threshold error: \(error.message)")
                }

                Picker("Check interval", selection: $model.settingsDraft.interval) {
                    ForEach(CheckInterval.allCases, id: \.rawValue) { interval in
                        Text(interval.displayName)
                            .tag(interval)
                    }
                }
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsInterval)
            }
            .disabled(model.isSavingSettings || state.isSavingConfiguration)

            Section("Notifications") {
                NotificationPermissionView(
                    permission: state.notificationPermission,
                    isWorking: model.isRequestingNotificationAuthorization,
                    enable: {
                        Task { await model.enableNotifications() }
                    },
                    openSettings: {
                        Task { await model.openNotificationSettings() }
                    },
                    enableIdentifier:
                        DiskMeerkatAccessibilityIdentifiers.settingsEnableNotifications,
                    openSettingsIdentifier:
                        DiskMeerkatAccessibilityIdentifiers.settingsOpenNotificationSettings
                )
            }

            Section("Startup") {
                Toggle(
                    isOn: Binding(
                        get: { state.launchAtLogin.isEnabled },
                        set: { isEnabled in
                            Task { await model.setLaunchAtLoginEnabled(isEnabled) }
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at Login")
                        Text(state.launchAtLogin.title)
                            .font(.caption)
                            .foregroundStyle(
                                state.launchAtLogin.requiresAttention ? .orange : .secondary
                            )
                        Text(state.launchAtLogin.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!state.launchAtLogin.canToggle || model.isChangingLaunchAtLogin)
                .accessibilityIdentifier(
                    DiskMeerkatAccessibilityIdentifiers.settingsLaunchAtLogin
                )

                if state.launchAtLogin.canOpenSettings {
                    Button("Open Login Items Settings") {
                        Task { await model.openLaunchAtLoginSettings() }
                    }
                    .accessibilityIdentifier(
                        DiskMeerkatAccessibilityIdentifiers.settingsOpenLoginSettings
                    )
                }
            }

            if let error = model.settingsSaveError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 520)
        .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsRoot)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    model.cancelSettingsEditing()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isSavingSettings || state.isSavingConfiguration)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if await model.saveSettings() {
                            dismiss()
                        }
                    }
                } label: {
                    if model.isSavingSettings || state.isSavingConfiguration {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Saving settings")
                    } else {
                        Text("Save")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSaveSettings)
                .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.settingsSave)
            }
        }
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
}
