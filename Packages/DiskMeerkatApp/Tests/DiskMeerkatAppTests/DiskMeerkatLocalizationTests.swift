import Foundation
import XCTest

@testable import DiskMeerkatApp

final class DiskMeerkatLocalizationTests: XCTestCase {
    func testEnglishCatalogResolvesStaticAndInterpolatedResources() {
        XCTAssertEqual(resolvedEnglish(englishLocalization.actionCancel), "Cancel")
        XCTAssertEqual(
            resolvedEnglish(englishLocalization.availableCapacity("82.4 GB")),
            "82.4 GB available"
        )
        XCTAssertEqual(
            resolvedEnglish(
                englishLocalization.notificationBody(
                    volumeName: "Macintosh HD",
                    availableCapacity: "18.4 GB",
                    threshold: "20 GB"
                )
            ),
            "Macintosh HD has 18.4 GB available, below your 20 GB limit."
        )
    }

    func testEnglishCatalogResolvesSemanticIntervalForms() {
        let expected: [(LocalizedStringResource, String)] = [
            (englishLocalization.intervalMinutes(1), "1 minute"),
            (englishLocalization.intervalMinutes(5), "5 minutes"),
            (englishLocalization.intervalHours(1), "1 hour"),
            (englishLocalization.intervalHours(24), "24 hours"),
        ]

        for (resource, copy) in expected {
            XCTAssertEqual(resolvedEnglish(resource), copy)
        }
    }

    func testSimplifiedChineseCatalogResolvesStaticAndInterpolatedResources() {
        XCTAssertEqual(
            resolvedSimplifiedChinese(simplifiedChineseLocalization.actionCancel),
            "取消"
        )
        XCTAssertEqual(
            resolvedSimplifiedChinese(
                simplifiedChineseLocalization.availableCapacity("82.4 GB")
            ),
            "82.4 GB 可用"
        )
        XCTAssertEqual(
            resolvedSimplifiedChinese(
                simplifiedChineseLocalization.notificationBody(
                    volumeName: "Macintosh HD",
                    availableCapacity: "18.4 GB",
                    threshold: "20 GB"
                )
            ),
            "“Macintosh HD”的可用空间为 18.4 GB，低于你设置的 20 GB 阈值。"
        )
    }

    func testSimplifiedChineseCatalogResolvesSemanticIntervalForms() {
        let expected: [(LocalizedStringResource, String)] = [
            (simplifiedChineseLocalization.intervalMinutes(1), "1 分钟"),
            (simplifiedChineseLocalization.intervalMinutes(5), "5 分钟"),
            (simplifiedChineseLocalization.intervalHours(1), "1 小时"),
            (simplifiedChineseLocalization.intervalHours(24), "24 小时"),
        ]

        for (resource, copy) in expected {
            XCTAssertEqual(resolvedSimplifiedChinese(resource), copy)
        }
    }

    func testResourceLanguageIsIndependentFromNumericLocale() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "de_DE"))
        let threshold = try LowSpaceThreshold(gigabytes: 1_000)
        let formattedNumber = formatter.numberString(for: threshold)

        XCTAssertEqual(formattedNumber, "1.000")
        XCTAssertEqual(
            resolvedEnglish(englishLocalization.gigabytes(formattedNumber)),
            "1.000 GB"
        )
    }

    func testSimplifiedChineseResourceLanguageIsIndependentFromNumericLocale() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "de_DE"))
        let threshold = try LowSpaceThreshold(gigabytes: 1_000)
        let formattedNumber = formatter.numberString(for: threshold)

        XCTAssertEqual(formattedNumber, "1.000")
        XCTAssertEqual(
            resolvedSimplifiedChinese(
                simplifiedChineseLocalization.availableCapacity(
                    simplifiedChineseLocalization.resolve(
                        simplifiedChineseLocalization.gigabytes(formattedNumber)
                    )
                )
            ),
            "1.000 GB 可用"
        )
    }

    func testThresholdValidationMessagesAreResourceBacked() {
        let cases: [(MonitoringThresholdDraftError, String)] = [
            (.required, "Enter a low-space threshold."),
            (.wholeNumber, "Enter a whole number of decimal GB."),
            (.outsideSupportedRange, "Enter a value from 1 through 1,000,000 GB."),
        ]

        for (error, message) in cases {
            XCTAssertEqual(
                resolvedEnglish(error.message(localization: englishLocalization)),
                message
            )
        }
    }

    func testSimplifiedChineseValidationAndAccessibilityMessagesAreResourceBacked() {
        let cases: [(MonitoringThresholdDraftError, String)] = [
            (.required, "请输入储存空间不足提醒阈值。"),
            (.wholeNumber, "请输入整数值（单位为十进制 GB）。"),
            (.outsideSupportedRange, "请输入 1 至 1,000,000 GB 的值。"),
        ]

        for (error, message) in cases {
            XCTAssertEqual(
                resolvedSimplifiedChinese(
                    error.message(localization: simplifiedChineseLocalization)
                ),
                message
            )
        }

        XCTAssertEqual(
            resolvedSimplifiedChinese(
                simplifiedChineseLocalization.statusAccessibilityLabel(
                    headline: "正在监控",
                    availableSpace: "82.4 GB 可用"
                )
            ),
            "DiskMeerkat。正在监控。82.4 GB 可用。"
        )
        XCTAssertEqual(
            resolvedSimplifiedChinese(
                simplifiedChineseLocalization.thresholdErrorAccessibilityLabel(
                    "请输入储存空间不足提醒阈值。"
                )
            ),
            "阈值错误：请输入储存空间不足提醒阈值。"
        )
    }

    func testPackageCatalogOverridesAnIncorrectDefaultValue() {
        let resource = englishLocalization.resource(
            "action.cancel",
            defaultValue: "Incorrect fallback",
            comment: "Verifies that the Package-owned catalog is used."
        )

        XCTAssertEqual(resolvedEnglish(resource), "Cancel")
    }

    func testFoundationLanguageMatchingSelectsOnlySimplifiedChinesePreferences() {
        let supportedLocalizations = ["en", "zh-Hans"]

        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supportedLocalizations,
                forPreferences: ["zh-CN"]
            ),
            ["zh-Hans"]
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supportedLocalizations,
                forPreferences: ["zh-Hans"]
            ),
            ["zh-Hans"]
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supportedLocalizations,
                forPreferences: ["zh-Hant"]
            ),
            ["en"]
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supportedLocalizations,
                forPreferences: ["zh-TW"]
            ),
            ["en"]
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supportedLocalizations,
                forPreferences: ["en-US"]
            ),
            ["en"]
        )
    }

    func testGeneratedResourcesMatchThePackageCatalogForEverySupportedLanguage() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL =
            packageRoot
            .appendingPathComponent("Localization")
            .appendingPathComponent("Localizable.xcstrings")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalogRoot = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        )
        let catalogEntries = try XCTUnwrap(catalogRoot["strings"] as? [String: Any])

        for language in ["en", "zh-Hans"] {
            var catalogValues: [String: String] = [:]
            for (key, entryValue) in catalogEntries {
                let entry = try XCTUnwrap(entryValue as? [String: Any])
                let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
                let localization = try XCTUnwrap(localizations[language] as? [String: Any])
                let stringUnit = try XCTUnwrap(localization["stringUnit"] as? [String: Any])
                XCTAssertEqual(stringUnit["state"] as? String, "translated", key)
                let value = try XCTUnwrap(stringUnit["value"] as? String)
                XCTAssertFalse(value.isEmpty, key)
                XCTAssertNotEqual(value, key, key)
                catalogValues[key] = value
            }

            let resourceURL = try XCTUnwrap(
                DiskMeerkatLocalization.resourceBundle.url(
                    forResource: "Localizable",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: language
                )
            )
            let resourceData = try Data(contentsOf: resourceURL)
            let generatedValues = try XCTUnwrap(
                try PropertyListSerialization.propertyList(
                    from: resourceData,
                    options: [],
                    format: nil
                ) as? [String: String]
            )

            XCTAssertEqual(generatedValues, catalogValues, language)
        }

        let localizationSourceURL =
            packageRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("DiskMeerkatApp")
            .appendingPathComponent("DiskMeerkatLocalization.swift")
        let localizationSource = try String(contentsOf: localizationSourceURL, encoding: .utf8)
        let expression = try NSRegularExpression(
            pattern: #"resource\(\s*"([^"]+)""#
        )
        let sourceRange = NSRange(localizationSource.startIndex..., in: localizationSource)
        let sourceKeys: Set<String> = Set(
            expression.matches(in: localizationSource, range: sourceRange).compactMap { match in
                guard
                    let range = Range(match.range(at: 1), in: localizationSource)
                else {
                    return nil
                }
                return String(localizationSource[range])
            }
        )
        XCTAssertEqual(sourceKeys, Set(catalogEntries.keys))
    }

    func testCatalogPlaceholdersMatchAcrossSupportedLanguages() throws {
        let catalogEntries = try packageCatalogEntries()

        for (key, entryValue) in catalogEntries {
            let entry = try XCTUnwrap(entryValue as? [String: Any])
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let english = try localizedValue(in: localizations, language: "en")
            let simplifiedChinese = try localizedValue(
                in: localizations,
                language: "zh-Hans"
            )

            XCTAssertEqual(
                try placeholders(in: simplifiedChinese),
                try placeholders(in: english),
                key
            )
        }
    }

    func testSimplifiedChineseTranslatesEveryNonInvariantCatalogValue() throws {
        let invariantKeys: Set<String> = [
            "capacity.gigabytes",
            "settings.gigabytes-unit",
        ]
        let catalogEntries = try packageCatalogEntries()
        var matchingKeys: Set<String> = []

        for (key, entryValue) in catalogEntries {
            let entry = try XCTUnwrap(entryValue as? [String: Any])
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            if try localizedValue(in: localizations, language: "en")
                == localizedValue(in: localizations, language: "zh-Hans")
            {
                matchingKeys.insert(key)
            }
        }

        XCTAssertEqual(matchingKeys, invariantKeys)
    }

    func testResolvedEnglishCopyNeverReturnsStableKeys() {
        let resources: [(LocalizedStringResource, String)] = [
            (englishLocalization.runtimeNotConnected, "runtime.not-connected"),
            (englishLocalization.headlineMonitoring, "monitoring.headline.monitoring"),
            (englishLocalization.permissionDeniedTitle, "permission.denied.title"),
            (englishLocalization.launchAtLoginEnabledTitle, "launch-at-login.enabled.title"),
            (englishLocalization.noticeDiskReadTitle, "notice.disk-read.title"),
            (englishLocalization.onboardingTitle, "onboarding.title"),
            (englishLocalization.settingsAlertThreshold, "settings.alert-threshold"),
            (englishLocalization.notificationTitle, "notification.low-space.title"),
        ]

        for (resource, key) in resources {
            XCTAssertNotEqual(resolvedEnglish(resource), key)
        }
    }

    func testResolvedSimplifiedChineseCopyNeverReturnsStableKeys() {
        let resources: [(LocalizedStringResource, String)] = [
            (simplifiedChineseLocalization.runtimeNotConnected, "runtime.not-connected"),
            (
                simplifiedChineseLocalization.headlineMonitoring,
                "monitoring.headline.monitoring"
            ),
            (
                simplifiedChineseLocalization.permissionDeniedTitle,
                "permission.denied.title"
            ),
            (
                simplifiedChineseLocalization.launchAtLoginEnabledTitle,
                "launch-at-login.enabled.title"
            ),
            (simplifiedChineseLocalization.noticeDiskReadTitle, "notice.disk-read.title"),
            (simplifiedChineseLocalization.onboardingTitle, "onboarding.title"),
            (
                simplifiedChineseLocalization.settingsAlertThreshold,
                "settings.alert-threshold"
            ),
            (
                simplifiedChineseLocalization.notificationTitle,
                "notification.low-space.title"
            ),
        ]

        for (resource, key) in resources {
            XCTAssertNotEqual(resolvedSimplifiedChinese(resource), key)
        }
    }

    private func packageCatalogEntries() throws -> [String: Any] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL =
            packageRoot
            .appendingPathComponent("Localization")
            .appendingPathComponent("Localizable.xcstrings")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalogRoot = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        )
        return try XCTUnwrap(catalogRoot["strings"] as? [String: Any])
    }

    private func localizedValue(
        in localizations: [String: Any],
        language: String
    ) throws -> String {
        let localization = try XCTUnwrap(localizations[language] as? [String: Any])
        let stringUnit = try XCTUnwrap(localization["stringUnit"] as? [String: Any])
        return try XCTUnwrap(stringUnit["value"] as? String)
    }

    private func placeholders(in value: String) throws -> [String] {
        let expression = try NSRegularExpression(
            pattern: #"%(?:\d+\$)?(?:@|lld)"#
        )
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let range = Range(match.range, in: value) else {
                return nil
            }
            return String(value[range])
        }.sorted()
    }
}
