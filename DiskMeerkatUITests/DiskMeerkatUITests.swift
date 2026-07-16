import Foundation
import XCTest

final class DiskMeerkatUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstRunDismissalAndWindowCloseLeaveMenuAppRunning() throws {
        let dismissalLaunch = launch(fixture: .firstRun)
        defer { terminateIfNeeded(dismissalLaunch.app) }

        let statusWindow = dismissalLaunch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(statusWindow.waitForExistence(timeout: 3))
        XCTAssertTrue(dismissalLaunch.app.staticTexts["Welcome to DiskMeerkat"].exists)
        XCTAssertFalse(dismissalLaunch.app.dialogs.firstMatch.exists)

        let screenshot = XCTAttachment(screenshot: statusWindow.screenshot())
        screenshot.name = "Integrated first-run status"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let dismiss = element(
            in: dismissalLaunch.app,
            identifier: "diskMeerkat.status.dismissOnboarding"
        )
        XCTAssertTrue(dismiss.waitForExistence(timeout: 2))
        press(dismiss)
        XCTAssertTrue(
            dismissalLaunch.app.staticTexts["Welcome to DiskMeerkat"].waitForNonExistence(
                timeout: 2
            )
        )

        dismissalLaunch.app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(statusWindow.waitForNonExistence(timeout: 2))
        assertApplicationIsRunning(dismissalLaunch.app)
        XCTAssertTrue(menuBarItem(in: dismissalLaunch.app).waitForExistence(timeout: 2))
        dismissalLaunch.app.terminate()
        XCTAssertTrue(dismissalLaunch.app.wait(for: .notRunning, timeout: 3))

        let closeLaunch = launch(fixture: .firstRun)
        defer { terminateIfNeeded(closeLaunch.app) }
        let closeWindow = closeLaunch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(closeWindow.waitForExistence(timeout: 3))
        XCTAssertTrue(closeLaunch.app.staticTexts["Welcome to DiskMeerkat"].exists)

        closeLaunch.app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(closeWindow.waitForNonExistence(timeout: 2))
        openMenu(in: closeLaunch.app)
        let openStatus = element(
            in: closeLaunch.app,
            identifier: "diskMeerkat.menu.openStatus"
        )
        XCTAssertTrue(openStatus.waitForExistence(timeout: 2))
        press(openStatus)

        XCTAssertTrue(closeWindow.waitForExistence(timeout: 2))
        XCTAssertTrue(
            closeLaunch.app.staticTexts["Welcome to DiskMeerkat"].waitForNonExistence(
                timeout: 2
            )
        )
        assertApplicationIsRunning(closeLaunch.app)
    }

    @MainActor
    func testMenuStatusSettingsValidationAndQuitShareTheAppBoundary() throws {
        let launch = launch(fixture: .healthy)
        defer { terminateIfNeeded(launch.app) }

        openMenu(in: launch.app)

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
        press(openStatus)
        let statusWindow = launch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(statusWindow.waitForExistence(timeout: 2))
        launch.app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(statusWindow.waitForNonExistence(timeout: 2))
        assertApplicationIsRunning(launch.app)

        openMenu(in: launch.app)
        let openSettings = element(
            in: launch.app,
            identifier: "diskMeerkat.menu.openSettings"
        )
        XCTAssertTrue(openSettings.waitForExistence(timeout: 2))
        press(openSettings)
        XCTAssertTrue(launch.app.windows.firstMatch.waitForExistence(timeout: 2))

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
        press(element(in: launch.app, identifier: "diskMeerkat.settings.cancel"))
        XCTAssertTrue(settingsRoot.waitForNonExistence(timeout: 2))

        openMenu(in: launch.app)
        let quit = element(in: launch.app, identifier: "diskMeerkat.menu.quit")
        XCTAssertTrue(quit.waitForExistence(timeout: 2))
        press(quit)
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

        runningLaunch.app.typeKey("w", modifierFlags: .command)
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
            assertApplicationIsRunning(launch.app)
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
    private func openMenu(in app: XCUIApplication) {
        let capacity = element(in: app, identifier: "diskMeerkat.menu.capacity")
        guard !capacity.exists else {
            return
        }

        let menuBarItem = menuBarItem(in: app)
        XCTAssertTrue(menuBarItem.waitForExistence(timeout: 3))
        press(menuBarItem)
        XCTAssertTrue(capacity.waitForExistence(timeout: 2))
    }

    @MainActor
    private func press(_ element: XCUIElement) {
        element.click()
    }

    @MainActor
    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    private func assertApplicationIsRunning(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch app.state {
        case .runningBackground, .runningForeground:
            break
        default:
            XCTFail("Expected DiskMeerkat to be running", file: file, line: line)
        }
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
