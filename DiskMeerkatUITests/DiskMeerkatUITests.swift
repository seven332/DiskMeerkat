import AppKit
import ApplicationServices
import Foundation
import XCTest

final class DiskMeerkatUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning() throws {
        let launch = launch(fixture: .firstRun)
        defer { terminateIfNeeded(launch.app) }

        let statusWindow = launch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(statusWindow.waitForExistence(timeout: 3))
        XCTAssertTrue(launch.app.staticTexts["Welcome to DiskMeerkat"].exists)
        XCTAssertFalse(launch.app.dialogs.firstMatch.exists)

        let screenshot = XCTAttachment(screenshot: statusWindow.screenshot())
        screenshot.name = "Integrated first-run status"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let dismiss = element(
            in: launch.app,
            identifier: "diskMeerkat.status.dismissOnboarding"
        )
        XCTAssertTrue(dismiss.waitForExistence(timeout: 2))
        dismiss.click()
        XCTAssertTrue(
            launch.app.staticTexts["Welcome to DiskMeerkat"].waitForNonExistence(timeout: 2)
        )

        statusWindow.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(statusWindow.waitForNonExistence(timeout: 2))
        XCTAssertEqual(launch.app.state, .runningForeground)
        XCTAssertTrue(menuBarItem(in: launch.app).waitForExistence(timeout: 2))
    }

    @MainActor
    func testMenuStatusSettingsValidationAndQuitShareTheAppBoundary() throws {
        let launch = launch(fixture: .healthy)
        defer { terminateIfNeeded(launch.app) }

        let menuBarItem = menuBarItem(in: launch.app)
        XCTAssertTrue(menuBarItem.waitForExistence(timeout: 3))
        press(menuBarItem: menuBarItem)

        let menuCapacity = element(
            in: launch.app,
            identifier: "diskMeerkat.menu.capacity"
        )
        XCTAssertTrue(menuCapacity.waitForExistence(timeout: 2))
        XCTAssertTrue(
            (menuCapacity.value as? String)?.contains("82.4 GB available") == true
        )

        let openStatus = element(
            in: launch.app,
            identifier: "diskMeerkat.menu.openStatus"
        )
        XCTAssertTrue(openStatus.exists)
        openStatus.click()
        let statusWindow = launch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(statusWindow.waitForExistence(timeout: 2))
        statusWindow.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(statusWindow.waitForNonExistence(timeout: 2))
        XCTAssertEqual(launch.app.state, .runningForeground)

        press(menuBarItem: menuBarItem)
        let openSettings = element(
            in: launch.app,
            identifier: "diskMeerkat.menu.openSettings"
        )
        XCTAssertTrue(openSettings.waitForExistence(timeout: 2))
        openSettings.click()

        let settingsRoot = element(
            in: launch.app,
            identifier: "diskMeerkat.settings.root"
        )
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 2))
        let threshold = element(
            in: launch.app,
            identifier: "diskMeerkat.settings.threshold"
        )
        threshold.click()
        threshold.typeKey("a", modifierFlags: .command)
        threshold.typeText("20.5")
        let thresholdError = launch.app.staticTexts.matching(
            NSPredicate(
                format: "value CONTAINS %@",
                "Enter a whole number of decimal GB."
            )
        ).firstMatch
        XCTAssertTrue(
            thresholdError.waitForExistence(timeout: 2)
        )
        let save = element(
            in: launch.app,
            identifier: "diskMeerkat.settings.save"
        )
        XCTAssertFalse(save.isEnabled)
        element(in: launch.app, identifier: "diskMeerkat.settings.cancel").click()
        XCTAssertTrue(settingsRoot.waitForNonExistence(timeout: 2))

        press(menuBarItem: menuBarItem)
        let quit = element(in: launch.app, identifier: "diskMeerkat.menu.quit")
        XCTAssertTrue(quit.waitForExistence(timeout: 2))
        quit.click()
        XCTAssertTrue(launch.app.wait(for: .notRunning, timeout: 3))
    }

    @MainActor
    func testNotificationActivationDuringLaunchAndWhileRunningUsesOneWindow() throws {
        let pendingLaunch = launch(fixture: .healthy, activateDuringLaunch: true)
        defer { terminateIfNeeded(pendingLaunch.app) }

        let pendingWindow = pendingLaunch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(pendingWindow.waitForExistence(timeout: 3))
        XCTAssertEqual(
            pendingLaunch.app.windows.matching(identifier: "DiskMeerkat Status").count,
            1
        )
        pendingLaunch.app.terminate()
        XCTAssertTrue(pendingLaunch.app.wait(for: .notRunning, timeout: 3))

        let runningLaunch = launch(fixture: .healthy)
        defer { terminateIfNeeded(runningLaunch.app) }
        postNotificationActivation(session: runningLaunch.session)

        let runningWindow = runningLaunch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(runningWindow.waitForExistence(timeout: 3))
        postNotificationActivation(session: runningLaunch.session)
        XCTAssertEqual(
            runningLaunch.app.windows.matching(identifier: "DiskMeerkat Status").count,
            1
        )

        runningWindow.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(runningWindow.waitForNonExistence(timeout: 2))
        postNotificationActivation(session: runningLaunch.session)
        XCTAssertTrue(runningWindow.waitForExistence(timeout: 3))
        XCTAssertEqual(
            runningLaunch.app.windows.matching(identifier: "DiskMeerkat Status").count,
            1
        )
    }

    @MainActor
    func testControlledProblemFixturesRemainScoped() throws {
        let expectations: [(Fixture, String)] = [
            (.permissionDenied, "Notifications are off"),
            (.readFailure, "Couldn't check disk · Will retry"),
        ]

        for (fixture, expectedText) in expectations {
            let launch = launch(fixture: fixture, activateDuringLaunch: true)
            XCTAssertTrue(
                launch.app.windows["DiskMeerkat Status"].waitForExistence(timeout: 3)
            )
            XCTAssertTrue(launch.app.staticTexts[expectedText].waitForExistence(timeout: 2))
            XCTAssertEqual(launch.app.state, .runningForeground)
            launch.app.terminate()
            XCTAssertTrue(launch.app.wait(for: .notRunning, timeout: 3))
        }
    }

    @MainActor
    private func launch(
        fixture: Fixture,
        activateDuringLaunch: Bool = false
    ) -> Launch {
        let app = XCUIApplication()
        let session = UUID().uuidString
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["DISK_MEERKAT_UI_TEST_FIXTURE"] = fixture.rawValue
        app.launchEnvironment["DISK_MEERKAT_UI_TEST_SESSION"] = session
        if activateDuringLaunch {
            app.launchEnvironment["DISK_MEERKAT_UI_TEST_ACTIVATE_DURING_LAUNCH"] = "1"
        }
        app.launch()
        return Launch(app: app, session: session)
    }

    @MainActor
    private func menuBarItem(in app: XCUIApplication) -> XCUIElement {
        app.menuBars.statusItems["diskMeerkat.menuBar.status"]
    }

    @MainActor
    private func press(menuBarItem: XCUIElement) {
        // XCUI can report MenuBarExtra frames outside the owning display on
        // multi-display hosts, so press the stable accessibility element.
        guard
            let runningApplication = NSRunningApplication.runningApplications(
                withBundleIdentifier: "Hippo.DiskMeerkat"
            ).max(by: { $0.processIdentifier < $1.processIdentifier }),
            let statusItem = accessibilityDescendant(
                of: AXUIElementCreateApplication(runningApplication.processIdentifier),
                identifier: menuBarItem.identifier
            )
        else {
            XCTFail("Could not resolve the DiskMeerkat status item")
            return
        }
        XCTAssertEqual(
            AXUIElementPerformAction(statusItem, kAXPressAction as CFString),
            .success
        )
    }

    private func accessibilityDescendant(
        of element: AXUIElement,
        identifier: String
    ) -> AXUIElement? {
        var identifierValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element,
            kAXIdentifierAttribute as CFString,
            &identifierValue
        ) == .success,
            identifierValue as? String == identifier
        {
            return element
        }

        var childrenValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element,
                kAXChildrenAttribute as CFString,
                &childrenValue
            ) == .success,
            let children = childrenValue as? [AXUIElement]
        else {
            return nil
        }
        return children.lazy.compactMap {
            self.accessibilityDescendant(of: $0, identifier: identifier)
        }.first
    }

    @MainActor
    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func postNotificationActivation(session: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(
                "Hippo.DiskMeerkat.ui-test.notification-activation.\(session)"
            ),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    @MainActor
    private func terminateIfNeeded(_ app: XCUIApplication) {
        guard app.state != .notRunning else {
            return
        }
        app.terminate()
    }
}

private struct Launch {
    let app: XCUIApplication
    let session: String
}

private enum Fixture: String {
    case firstRun = "first-run"
    case healthy
    case permissionDenied = "permission-denied"
    case readFailure = "read-failure"
}
