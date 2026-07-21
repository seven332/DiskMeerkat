import XCTest

final class FirstRunAndLifecycleUITests: DiskMeerkatUITestCase {
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
}
