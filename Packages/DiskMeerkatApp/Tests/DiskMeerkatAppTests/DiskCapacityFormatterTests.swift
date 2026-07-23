import Foundation
import XCTest

@testable import DiskMeerkatApp

final class DiskCapacityFormatterTests: XCTestCase {
    func testFormatsRoutineAndLargeDecimalGigabyteValues() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: 82_400_000_000),
                relativeTo: threshold
            ),
            "82.4"
        )
        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: 1_000_000_000_000_000),
                relativeTo: threshold
            ),
            "1,000,000"
        )
        XCTAssertEqual(
            formatter.numberString(for: try DiskCapacity(bytes: 0), relativeTo: threshold),
            "0"
        )
    }

    func testIncreasesPrecisionWhenDefaultRoundingWouldReachThreshold() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: 19_950_000_000),
                relativeTo: threshold
            ),
            "19.95"
        )
    }

    func testPreservesStrictRelationshipAtByteAdjacentThresholdValues() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: threshold.bytes - 1),
                relativeTo: threshold
            ),
            "19.999999999"
        )
        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: threshold.bytes),
                relativeTo: threshold
            ),
            "20"
        )
        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: threshold.bytes + 1),
                relativeTo: threshold
            ),
            "20.000000001"
        )
    }

    func testUsesTheRequestedLocaleForGroupingAndDecimalSeparators() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "de_DE"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: threshold.bytes - 1),
                relativeTo: threshold
            ),
            "19,999999999"
        )
        XCTAssertEqual(
            formatter.numberString(
                for: try DiskCapacity(bytes: 1_000_000_000_000_000),
                relativeTo: threshold
            ),
            "1.000.000"
        )
    }

    func testFormatsWholeThresholdsWithTheRequestedLocale() throws {
        let englishFormatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let germanFormatter = DiskCapacityFormatter(locale: Locale(identifier: "de_DE"))
        let threshold = try LowSpaceThreshold(gigabytes: 1_000)

        XCTAssertEqual(englishFormatter.numberString(for: threshold), "1,000")
        XCTAssertEqual(germanFormatter.numberString(for: threshold), "1.000")
    }
}
