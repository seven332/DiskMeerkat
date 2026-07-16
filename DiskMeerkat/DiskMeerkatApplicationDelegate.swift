import AppKit
import DiskMeerkatApp
import Foundation
import UserNotifications

@MainActor
final class DiskMeerkatApplicationDelegate: NSObject, NSApplicationDelegate,
    UNUserNotificationCenterDelegate
{
    let controller: DiskMeerkatApplicationController
    let statusRouter = DiskMeerkatStatusWindowRouter()

    private var startTask: Task<Void, Never>?
    private var terminationTask: Task<Void, Never>?

    #if DEBUG
        private let uiTestConfiguration: DiskMeerkatUITestConfiguration?
    #endif

    override init() {
        #if DEBUG
            let uiTestConfiguration = DiskMeerkatUITestConfiguration.current
            self.uiTestConfiguration = uiTestConfiguration
            if let uiTestConfiguration {
                controller = DiskMeerkatApplicationController(
                    fixture: uiTestConfiguration.fixture,
                    openNotificationSettings: {
                        await DiskMeerkatSystemSettings.openNotifications()
                    }
                )
            } else {
                controller = DiskMeerkatApplicationController(
                    openNotificationSettings: {
                        await DiskMeerkatSystemSettings.openNotifications()
                    }
                )
            }
        #else
            controller = DiskMeerkatApplicationController(
                openNotificationSettings: {
                    await DiskMeerkatSystemSettings.openNotifications()
                }
            )
        #endif
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        #if DEBUG
            guard let uiTestConfiguration else {
                return
            }
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(handleUITestNotificationActivation(_:)),
                name: uiTestConfiguration.activationNotificationName,
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
            if uiTestConfiguration.activatesStatusDuringLaunch {
                statusRouter.requestStatus()
            }
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        startTask = Task { [weak self] in
            guard let self else {
                return
            }
            if await controller.start() == .showStatus {
                statusRouter.requestStatus()
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        statusRouter.requestStatus()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminationTask == nil else {
            return .terminateLater
        }

        let controller = controller
        terminationTask = Task {
            await controller.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = nil
        #if DEBUG
            if let uiTestConfiguration {
                DistributedNotificationCenter.default().removeObserver(
                    self,
                    name: uiTestConfiguration.activationNotificationName,
                    object: nil
                )
            }
        #endif
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) ->
            Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let opensStatus = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        if opensStatus {
            Task { @MainActor [weak self] in
                self?.statusRouter.requestStatus()
            }
        }
        completionHandler()
    }

    #if DEBUG
        @objc private nonisolated func handleUITestNotificationActivation(
            _ notification: Notification
        ) {
            Task { @MainActor [weak self] in
                self?.statusRouter.requestStatus()
            }
        }
    #endif
}

@MainActor
final class DiskMeerkatStatusWindowRouter {
    private var openStatusAction: (@MainActor () -> Void)?
    private var hasPendingRequest = false

    func install(openStatus: @escaping @MainActor () -> Void) {
        openStatusAction = openStatus
        guard hasPendingRequest else {
            return
        }
        hasPendingRequest = false
        openStatus()
    }

    func requestStatus() {
        guard let openStatusAction else {
            hasPendingRequest = true
            return
        }
        openStatusAction()
    }
}

@MainActor
private enum DiskMeerkatSystemSettings {
    static func openNotifications() async {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Hippo.DiskMeerkat"
        let encodedIdentifier =
            bundleIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? bundleIdentifier
        let notificationSettingsURL = URL(
            string:
                "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(encodedIdentifier)"
        )
        if let notificationSettingsURL, NSWorkspace.shared.open(notificationSettingsURL) {
            return
        }

        guard
            let systemSettingsURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.systempreferences"
            )
        else {
            return
        }
        _ = try? await NSWorkspace.shared.openApplication(
            at: systemSettingsURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

#if DEBUG
    private struct DiskMeerkatUITestConfiguration {
        private static let fixtureKey = "DISK_MEERKAT_UI_TEST_FIXTURE"
        private static let sessionKey = "DISK_MEERKAT_UI_TEST_SESSION"
        private static let activateDuringLaunchKey =
            "DISK_MEERKAT_UI_TEST_ACTIVATE_DURING_LAUNCH"

        let fixture: DiskMeerkatApplicationFixture
        let session: String
        let activatesStatusDuringLaunch: Bool

        var activationNotificationName: Notification.Name {
            Notification.Name("Hippo.DiskMeerkat.ui-test.notification-activation.\(session)")
        }

        static var current: Self? {
            let environment = ProcessInfo.processInfo.environment
            guard
                let fixtureValue = environment[fixtureKey],
                let fixture = DiskMeerkatApplicationFixture(rawValue: fixtureValue),
                let session = environment[sessionKey],
                session.count <= 64,
                !session.isEmpty,
                session.unicodeScalars.allSatisfy(Self.allowedSessionCharacters.contains)
            else {
                return nil
            }
            return Self(
                fixture: fixture,
                session: session,
                activatesStatusDuringLaunch: environment[activateDuringLaunchKey] == "1"
            )
        }

        private static let allowedSessionCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        )
    }
#endif
