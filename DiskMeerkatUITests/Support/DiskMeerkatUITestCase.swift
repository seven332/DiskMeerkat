import Foundation
import XCTest

class DiskMeerkatUITestCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    @MainActor
    func launch(
        fixture: DiskMeerkatFixture,
        activateDuringLaunch: Bool = false
    ) -> DiskMeerkatLaunch {
        let app = XCUIApplication()
        let session = UUID().uuidString
        app.launchArguments += [
            "-ApplePersistenceIgnoreState",
            "YES",
            "-AppleLanguages",
            "(en)",
        ]
        app.launchEnvironment["DISK_MEERKAT_UI_TEST_FIXTURE"] = fixture.rawValue
        app.launchEnvironment["DISK_MEERKAT_UI_TEST_SESSION"] = session
        if activateDuringLaunch {
            app.launchEnvironment["DISK_MEERKAT_UI_TEST_ACTIVATE_DURING_LAUNCH"] = "1"
        }
        app.launch()
        return DiskMeerkatLaunch(app: app, session: session)
    }

    @MainActor
    func menuBarItem(in app: XCUIApplication) -> XCUIElement {
        app.menuBars.statusItems["diskMeerkat.menuBar.status"]
    }

    @MainActor
    func openMenu(in app: XCUIApplication) {
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
    func press(_ element: XCUIElement) {
        element.click()
    }

    @MainActor
    func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor
    func assertApplicationIsRunning(
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

    func postNotificationActivation(session: String) {
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
    func terminateIfNeeded(_ app: XCUIApplication) {
        guard app.state != .notRunning else {
            return
        }
        app.terminate()
    }
}

struct DiskMeerkatLaunch {
    let app: XCUIApplication
    let session: String
}

enum DiskMeerkatFixture: String {
    case firstRun = "first-run"
    case healthy
    case permissionDenied = "permission-denied"
    case readFailure = "read-failure"
}
