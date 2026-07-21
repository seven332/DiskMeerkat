import XCTest

final class NotificationActivationUITests: DiskMeerkatUITestCase {
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
}
