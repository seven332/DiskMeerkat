import XCTest

final class LocalizationUITests: DiskMeerkatUITestCase {
    @MainActor
    func testSimplifiedChineseOnboardingUsesAppAndPackageResources() throws {
        let launch = launch(
            fixture: .firstRun,
            language: "zh-CN",
            locale: "zh_CN"
        )
        defer { terminateIfNeeded(launch.app) }

        let statusWindow = launch.app.windows["DiskMeerkat 状态"]
        XCTAssertTrue(statusWindow.waitForExistence(timeout: 3))
        XCTAssertTrue(
            launch.app.staticTexts["欢迎使用 DiskMeerkat"].waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            launch.app.staticTexts[
                "DiskMeerkat 会监控你的启动磁盘，并在可用空间低于你设置的阈值时提醒你。"
            ].exists
        )
        XCTAssertFalse(launch.app.staticTexts["Welcome to DiskMeerkat"].exists)

        attachScreenshot(of: statusWindow, named: "Simplified Chinese onboarding")
    }

    @MainActor
    func testSimplifiedChineseMenuStatusAndSettingsRemainReadable() throws {
        let launch = launch(
            fixture: .healthy,
            language: "zh-CN",
            locale: "zh_CN"
        )
        defer { terminateIfNeeded(launch.app) }

        openMenu(in: launch.app)
        let menuCapacity = element(
            in: launch.app,
            identifier: "diskMeerkat.menu.capacity"
        )
        XCTAssertTrue(
            (menuCapacity.value as? String)?.contains("82.4 GB 可用") == true
        )
        let openStatus = element(
            in: launch.app,
            identifier: "diskMeerkat.menu.openStatus"
        )
        XCTAssertEqual(openStatus.label, "打开状态窗口")
        XCTAssertEqual(
            element(in: launch.app, identifier: "diskMeerkat.menu.openSettings").label,
            "设置"
        )
        XCTAssertEqual(
            element(in: launch.app, identifier: "diskMeerkat.menu.quit").label,
            "退出 DiskMeerkat"
        )
        attachScreenshot(of: launch.app, named: "Simplified Chinese menu")

        press(openStatus)
        let statusWindow = launch.app.windows["DiskMeerkat 状态"]
        XCTAssertTrue(statusWindow.waitForExistence(timeout: 2))
        XCTAssertTrue(launch.app.staticTexts["当前状态"].exists)
        XCTAssertTrue(
            launch.app.staticTexts["DiskMeerkat 会在后台自动检查你的启动磁盘。"].exists
        )
        attachScreenshot(of: statusWindow, named: "Simplified Chinese status")

        launch.app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(statusWindow.waitForNonExistence(timeout: 2))
        openMenu(in: launch.app)
        press(
            element(
                in: launch.app,
                identifier: "diskMeerkat.menu.openSettings"
            )
        )
        let settingsRoot = element(
            in: launch.app,
            identifier: "diskMeerkat.settings.root"
        )
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 2))
        XCTAssertTrue(launch.app.staticTexts["提醒阈值"].exists)
        XCTAssertTrue(launch.app.staticTexts["登录时打开"].exists)
        XCTAssertTrue(launch.app.staticTexts["储存空间不足提醒"].exists)

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
                "请输入整数值（单位为十进制 GB）。"
            )
        ).firstMatch
        XCTAssertTrue(thresholdError.waitForExistence(timeout: 2))
        XCTAssertFalse(
            element(
                in: launch.app,
                identifier: "diskMeerkat.settings.save"
            ).isEnabled
        )
        attachScreenshot(of: settingsRoot, named: "Simplified Chinese settings validation")
    }

    @MainActor
    func testSimplifiedChineseProblemAndPermissionCopyRemainReadable() throws {
        let expectations: [(DiskMeerkatFixture, String, String)] = [
            (.permissionDenied, "通知已关闭", "Simplified Chinese permission"),
            (.readFailure, "无法检查磁盘 · 将重试", "Simplified Chinese disk error"),
        ]

        for (fixture, expectedText, screenshotName) in expectations {
            let launch = launch(
                fixture: fixture,
                language: "zh-CN",
                locale: "zh_CN",
                activateDuringLaunch: true
            )
            let statusWindow = launch.app.windows["DiskMeerkat 状态"]
            XCTAssertTrue(statusWindow.waitForExistence(timeout: 3))
            XCTAssertTrue(
                launch.app.staticTexts[expectedText].waitForExistence(timeout: 2)
            )
            attachScreenshot(of: statusWindow, named: screenshotName)
            terminateIfNeeded(launch.app)
        }
    }

    @MainActor
    func testLanguageAndRegionCanBeSelectedIndependently() throws {
        let englishLaunch = launch(
            fixture: .healthy,
            language: "en",
            locale: "zh_CN",
            activateDuringLaunch: true
        )
        let englishWindow = englishLaunch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(englishWindow.waitForExistence(timeout: 3))
        XCTAssertTrue(englishLaunch.app.staticTexts["Current status"].exists)
        XCTAssertFalse(englishLaunch.app.staticTexts["当前状态"].exists)
        terminateIfNeeded(englishLaunch.app)
        XCTAssertTrue(englishLaunch.app.wait(for: .notRunning, timeout: 3))

        let traditionalChineseLaunch = launch(
            fixture: .firstRun,
            language: "zh-Hant",
            locale: "zh_TW",
            activateDuringLaunch: true
        )
        defer { terminateIfNeeded(traditionalChineseLaunch.app) }
        let fallbackWindow = traditionalChineseLaunch.app.windows["DiskMeerkat Status"]
        XCTAssertTrue(fallbackWindow.waitForExistence(timeout: 3))
        XCTAssertTrue(
            traditionalChineseLaunch.app.staticTexts["Welcome to DiskMeerkat"]
                .waitForExistence(timeout: 2)
        )
        XCTAssertFalse(
            traditionalChineseLaunch.app.staticTexts["欢迎使用 DiskMeerkat"].exists
        )
    }

    @MainActor
    private func attachScreenshot(of element: XCUIElement, named name: String) {
        let screenshot = XCTAttachment(screenshot: element.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
