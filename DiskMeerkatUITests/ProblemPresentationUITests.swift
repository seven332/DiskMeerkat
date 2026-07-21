import XCTest

final class ProblemPresentationUITests: DiskMeerkatUITestCase {
    @MainActor
    func testControlledProblemFixturesRemainScoped() throws {
        let expectations: [(DiskMeerkatFixture, String)] = [
            (.permissionDenied, "Notifications are off"),
            (.readFailure, "Couldn't check disk · Will retry"),
        ]

        for (fixture, expectedText) in expectations {
            let launch = launch(fixture: fixture, activateDuringLaunch: true)
            defer { terminateIfNeeded(launch.app) }
            XCTAssertTrue(
                launch.app.windows["DiskMeerkat Status"].waitForExistence(timeout: 3)
            )
            XCTAssertTrue(launch.app.staticTexts[expectedText].waitForExistence(timeout: 2))
            assertApplicationIsRunning(launch.app)
            launch.app.terminate()
            XCTAssertTrue(launch.app.wait(for: .notRunning, timeout: 3))
        }
    }
}
