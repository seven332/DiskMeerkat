import XCTest
@testable import DiskMeerkatApp

final class MonitoringConfigurationTests: XCTestCase {
    func testCheckIntervalPresetsExposeStableSecondsAndDurations() {
        let expectedValues: [(CheckInterval, Int)] = [
            (.fiveMinutes, 300),
            (.fifteenMinutes, 900),
            (.thirtyMinutes, 1_800),
            (.oneHour, 3_600),
            (.sixHours, 21_600),
            (.twentyFourHours, 86_400),
        ]

        XCTAssertEqual(CheckInterval.allCases, expectedValues.map(\.0))

        for (interval, seconds) in expectedValues {
            XCTAssertEqual(interval.rawValue, seconds)
            XCTAssertEqual(interval.duration, .seconds(seconds))
        }
    }

    func testDefaultConfigurationUsesApprovedValues() {
        XCTAssertEqual(MonitoringConfiguration.defaultValue.threshold.gigabytes, 20)
        XCTAssertEqual(MonitoringConfiguration.defaultValue.threshold.bytes, 20_000_000_000)
        XCTAssertEqual(MonitoringConfiguration.defaultValue.interval, .fifteenMinutes)
        XCTAssertEqual(CheckInterval.defaultValue, .fifteenMinutes)
    }

    func testDiskCapacityRejectsNegativeBytes() {
        XCTAssertThrowsError(try DiskCapacity(bytes: -1)) { error in
            XCTAssertEqual(error as? DiskCapacityValidationError, .negativeBytes)
        }
    }

    func testDiskCapacityUsesExactComparableBytes() throws {
        let lower = try DiskCapacity(bytes: 19_999_999_999)
        let higher = try DiskCapacity(bytes: 20_000_000_000)

        XCTAssertLessThan(lower, higher)
        XCTAssertEqual(higher.bytes, 20_000_000_000)
    }

    func testThresholdAcceptsSupportedGigabyteBoundaries() throws {
        let minimum = try LowSpaceThreshold(gigabytes: 1)
        let maximum = try LowSpaceThreshold(gigabytes: 1_000_000)

        XCTAssertEqual(minimum.bytes, 1_000_000_000)
        XCTAssertEqual(maximum.bytes, 1_000_000_000_000_000)
        XCTAssertEqual(maximum.gigabytes, 1_000_000)
    }

    func testThresholdRejectsUnsupportedGigabyteValuesBeforeMultiplication() {
        for gigabytes: Int64 in [0, -1, 1_000_001, .max] {
            XCTAssertThrowsError(try LowSpaceThreshold(gigabytes: gigabytes)) { error in
                XCTAssertEqual(error as? LowSpaceThresholdValidationError, .outsideSupportedRange)
            }
        }
    }

    func testThresholdRestoresExactWholeGigabyteBytes() throws {
        let threshold = try LowSpaceThreshold(bytes: 25_000_000_000)

        XCTAssertEqual(threshold.gigabytes, 25)
        XCTAssertEqual(threshold.bytes, 25_000_000_000)
    }

    func testThresholdRejectsNonWholeAndOutOfRangeBytes() {
        XCTAssertThrowsError(try LowSpaceThreshold(bytes: 20_000_000_001)) { error in
            XCTAssertEqual(error as? LowSpaceThresholdValidationError, .notWholeGigabyte)
        }

        for bytes: Int64 in [0, 1_000_001_000_000_000] {
            XCTAssertThrowsError(try LowSpaceThreshold(bytes: bytes)) { error in
                XCTAssertEqual(error as? LowSpaceThresholdValidationError, .outsideSupportedRange)
            }
        }
    }
}
