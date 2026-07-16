import Foundation
import XCTest

@testable import DiskMeerkatApp

final class MonitoringSettingsDraftTests: XCTestCase {
    func testDraftStartsFromCommittedConfigurationAndIsNotDirty() {
        let draft = MonitoringSettingsDraft(
            configuration: .defaultValue,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(draft.thresholdText, "20")
        XCTAssertEqual(draft.interval, .fifteenMinutes)
        XCTAssertEqual(draft.validatedConfiguration, .defaultValue)
        XCTAssertFalse(draft.isDirty)
        XCTAssertNil(draft.thresholdError)
    }

    func testBlankFractionalAndPartialInputsHaveSpecificErrors() {
        var draft = makeDraft()

        draft.thresholdText = "  \n"
        XCTAssertEqual(draft.thresholdError, .required)

        draft.thresholdText = "20.5"
        XCTAssertEqual(draft.thresholdError, .wholeNumber)

        draft.thresholdText = "20 GB"
        XCTAssertEqual(draft.thresholdError, .wholeNumber)

        draft.thresholdText = "1e2"
        XCTAssertEqual(draft.thresholdError, .wholeNumber)
    }

    func testSupportedRangeIsValidatedBeforeBuildingConfiguration() {
        var draft = makeDraft()

        for text in ["0", "-1", "1,000,001"] {
            draft.thresholdText = text
            XCTAssertEqual(draft.thresholdError, .outsideSupportedRange)
            XCTAssertNil(draft.validatedConfiguration)
        }

        draft.thresholdText = "1"
        XCTAssertEqual(draft.validatedConfiguration?.threshold.gigabytes, 1)
        draft.thresholdText = "1,000,000"
        XCTAssertEqual(draft.validatedConfiguration?.threshold.gigabytes, 1_000_000)
    }

    func testParserUsesLocaleAndRequiresTheEntireInput() {
        var germanDraft = MonitoringSettingsDraft(
            configuration: .defaultValue,
            locale: Locale(identifier: "de_DE")
        )
        germanDraft.thresholdText = "1.000"
        XCTAssertEqual(germanDraft.validatedConfiguration?.threshold.gigabytes, 1_000)

        germanDraft.thresholdText = "1.000x"
        XCTAssertEqual(germanDraft.thresholdError, .wholeNumber)
    }

    func testValidEditsBecomeDirtyAndResetToNewCommittedValues() throws {
        var draft = makeDraft()
        draft.thresholdText = "35"
        draft.interval = .oneHour

        XCTAssertTrue(draft.isDirty)
        XCTAssertEqual(draft.validatedConfiguration?.threshold.gigabytes, 35)
        XCTAssertEqual(draft.validatedConfiguration?.interval, .oneHour)

        let committed = MonitoringConfiguration(
            threshold: try LowSpaceThreshold(gigabytes: 45),
            interval: .sixHours
        )
        draft.reset(to: committed)

        XCTAssertEqual(draft.thresholdText, "45")
        XCTAssertEqual(draft.interval, .sixHours)
        XCTAssertFalse(draft.isDirty)
    }

    func testInvalidEditIsDirtyButCannotProduceConfiguration() {
        var draft = makeDraft()
        draft.thresholdText = "invalid"

        XCTAssertTrue(draft.isDirty)
        XCTAssertNil(draft.validatedConfiguration)
    }

    func testAccessibilityIdentifiersAreStableAndUnique() {
        let identifiers = DiskMeerkatAccessibilityIdentifiers.all

        XCTAssertEqual(identifiers.count, 22)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix("diskMeerkat.") })
    }

    private func makeDraft() -> MonitoringSettingsDraft {
        MonitoringSettingsDraft(
            configuration: .defaultValue,
            locale: Locale(identifier: "en_US")
        )
    }
}
