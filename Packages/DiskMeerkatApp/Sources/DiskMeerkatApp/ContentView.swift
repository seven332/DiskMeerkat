import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DiskMeerkat")
                .font(.title.weight(.semibold))
            MonitoringSummaryView(state: PreviewPresentationFixtures.stopped)
            Text("The app is not connected to its monitoring runtime yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 320)
        .accessibilityIdentifier(DiskMeerkatAccessibilityIdentifiers.statusRoot)
    }
}

private enum PreviewPresentationFixtures {
    static let stopped = MonitoringPresentationState(
        snapshot: MonitoringSnapshot(
            lifecycleState: .stopped,
            configuration: .defaultValue,
            notificationEpisodeState: .armed,
            hasCompletedOnboarding: true,
            notificationAuthorizationState: .unknown,
            isCheckInProgress: false,
            isSavingConfiguration: false,
            latestSuccessfulVolume: nil,
            latestAssessment: nil,
            lastSuccessfulCheckAt: nil,
            nextScheduledCheckAt: nil,
            persistenceFailure: nil,
            notificationFailure: nil
        ),
        launchAtLoginSnapshot: LaunchAtLoginSnapshot(actualState: .disabled, problem: nil),
        locale: Locale(identifier: "en_US")
    )

    static let lowSpace = MonitoringPresentationState(
        snapshot: MonitoringSnapshot(
            lifecycleState: .running,
            configuration: .defaultValue,
            notificationEpisodeState: .suppressed,
            hasCompletedOnboarding: true,
            notificationAuthorizationState: .authorized,
            isCheckInProgress: false,
            isSavingConfiguration: false,
            latestSuccessfulVolume: lowSpaceVolume,
            latestAssessment: .available(
                startupVolume: lowSpaceVolume,
                relationship: .below
            ),
            lastSuccessfulCheckAt: .now,
            nextScheduledCheckAt: .now.addingTimeInterval(900),
            persistenceFailure: nil,
            notificationFailure: nil
        ),
        launchAtLoginSnapshot: LaunchAtLoginSnapshot(actualState: .enabled, problem: nil),
        locale: Locale(identifier: "en_US")
    )

    private static let lowSpaceVolume = StartupVolumeSnapshot(
        availableCapacity: try! DiskCapacity(bytes: 18_400_000_000),
        volumeName: "Macintosh HD"
    )
}

#Preview("Stopped") {
    ContentView()
}

#Preview("Low space") {
    MonitoringSummaryView(state: PreviewPresentationFixtures.lowSpace)
        .padding()
        .frame(width: 500)
}
