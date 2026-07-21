import XCTest

final class MenuAndSettingsUITests: DiskMeerkatUITestCase {
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
        XCTAssertTrue(menuCapacity.waitForNonExistence(timeout: 2))
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
        XCTAssertTrue(openSettings.waitForNonExistence(timeout: 2))
        XCTAssertTrue(launch.app.windows.firstMatch.waitForExistence(timeout: 2))

        let settingsRoot = element(
            in: launch.app,
            identifier: "diskMeerkat.settings.root"
        )
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 2))
        let save = element(
            in: launch.app,
            identifier: "diskMeerkat.settings.save"
        )
        XCTAssertTrue(
            save.waitForExistence(timeout: 2),
            "Settings Save button is missing before validation: \(launch.app.debugDescription)"
        )
        XCTAssertFalse(save.isEnabled)
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
        XCTAssertTrue(
            save.exists,
            "Settings Save button disappeared after validation: \(launch.app.debugDescription)"
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
}
