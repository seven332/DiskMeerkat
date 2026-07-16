import Foundation
import XCTest

@testable import DiskMeerkatApp

final class DiskCapacityFormatterTests: XCTestCase {
    func testFormatsRoutineAndLargeDecimalGigabyteValues() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: 82_400_000_000),
                relativeTo: threshold
            ),
            "82.4 GB"
        )
        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: 1_000_000_000_000_000),
                relativeTo: threshold
            ),
            "1,000,000 GB"
        )
        XCTAssertEqual(
            formatter.string(for: try DiskCapacity(bytes: 0), relativeTo: threshold),
            "0 GB"
        )
    }

    func testIncreasesPrecisionWhenDefaultRoundingWouldReachThreshold() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: 19_950_000_000),
                relativeTo: threshold
            ),
            "19.95 GB"
        )
    }

    func testPreservesStrictRelationshipAtByteAdjacentThresholdValues() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: threshold.bytes - 1),
                relativeTo: threshold
            ),
            "19.999999999 GB"
        )
        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: threshold.bytes),
                relativeTo: threshold
            ),
            "20 GB"
        )
        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: threshold.bytes + 1),
                relativeTo: threshold
            ),
            "20.000000001 GB"
        )
    }

    func testUsesTheRequestedLocaleForGroupingAndDecimalSeparators() throws {
        let formatter = DiskCapacityFormatter(locale: Locale(identifier: "de_DE"))
        let threshold = try LowSpaceThreshold(gigabytes: 20)

        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: threshold.bytes - 1),
                relativeTo: threshold
            ),
            "19,999999999 GB"
        )
        XCTAssertEqual(
            formatter.string(
                for: try DiskCapacity(bytes: 1_000_000_000_000_000),
                relativeTo: threshold
            ),
            "1.000.000 GB"
        )
    }

    func testFormatsWholeThresholdsWithTheRequestedLocale() throws {
        let englishFormatter = DiskCapacityFormatter(locale: Locale(identifier: "en_US_POSIX"))
        let germanFormatter = DiskCapacityFormatter(locale: Locale(identifier: "de_DE"))
        let threshold = try LowSpaceThreshold(gigabytes: 1_000)

        XCTAssertEqual(englishFormatter.string(for: threshold), "1,000 GB")
        XCTAssertEqual(germanFormatter.string(for: threshold), "1.000 GB")
    }
}
