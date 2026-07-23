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

    func testPackageCatalogOverridesAnIncorrectDefaultValue() {
        let resource = englishLocalization.resource(
            "action.cancel",
            defaultValue: "Incorrect fallback",
            comment: "Verifies that the Package-owned catalog is used."
        )

        XCTAssertEqual(resolvedEnglish(resource), "Cancel")
    }

    func testGeneratedEnglishResourcesMatchThePackageCatalog() throws {
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
        var catalogValues: [String: String] = [:]
        for (key, entryValue) in catalogEntries {
            let entry = try XCTUnwrap(entryValue as? [String: Any])
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let english = try XCTUnwrap(localizations["en"] as? [String: Any])
            let stringUnit = try XCTUnwrap(english["stringUnit"] as? [String: Any])
            catalogValues[key] = try XCTUnwrap(stringUnit["value"] as? String)
        }

        let resourceURL = try XCTUnwrap(
            DiskMeerkatLocalization.resourceBundle.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: "en"
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

        XCTAssertEqual(generatedValues, catalogValues)

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
        XCTAssertEqual(sourceKeys, Set(catalogValues.keys))
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
}
