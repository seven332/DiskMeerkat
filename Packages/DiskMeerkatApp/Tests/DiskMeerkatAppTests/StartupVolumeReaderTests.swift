import Foundation
import XCTest
@testable import DiskMeerkatApp

final class StartupVolumeReaderTests: XCTestCase {
    func testValidReadUsesStartupRootAndRequiredResourceKeys() throws {
        let reader = FoundationStartupVolumeReader { url, keys in
            guard url.path == "/" else {
                throw TestError.unexpectedURL
            }
            guard
                keys == [
                    .volumeAvailableCapacityForImportantUsageKey,
                    .volumeNameKey,
                ]
            else {
                throw TestError.unexpectedKeys
            }

            return StartupVolumeResourceValues(
                availableCapacityForImportantUsage: 42_000_000_000,
                volumeName: "Macintosh HD"
            )
        }

        XCTAssertEqual(
            reader.readStartupVolume(),
            .available(
                StartupVolumeSnapshot(
                    availableCapacity: try DiskCapacity(bytes: 42_000_000_000),
                    volumeName: "Macintosh HD"
                )
            )
        )
    }

    func testMissingAndBlankNamesRemainSuccessfulReads() throws {
        for name in [nil, "", " \n\t"] as [String?] {
            let reader = FoundationStartupVolumeReader { _, _ in
                StartupVolumeResourceValues(
                    availableCapacityForImportantUsage: 20_000_000_000,
                    volumeName: name
                )
            }

            XCTAssertEqual(
                reader.readStartupVolume(),
                .available(
                    StartupVolumeSnapshot(
                        availableCapacity: try DiskCapacity(bytes: 20_000_000_000),
                        volumeName: nil
                    )
                )
            )
        }
    }

    func testVolumeNameIsTrimmed() throws {
        let reader = FoundationStartupVolumeReader { _, _ in
            StartupVolumeResourceValues(
                availableCapacityForImportantUsage: 20_000_000_000,
                volumeName: "  Macintosh HD \n"
            )
        }

        XCTAssertEqual(
            reader.readStartupVolume(),
            .available(
                StartupVolumeSnapshot(
                    availableCapacity: try DiskCapacity(bytes: 20_000_000_000),
                    volumeName: "Macintosh HD"
                )
            )
        )
    }

    func testMissingCapacityIsUnavailableRatherThanZero() {
        let reader = FoundationStartupVolumeReader { _, _ in
            StartupVolumeResourceValues(
                availableCapacityForImportantUsage: nil,
                volumeName: "Macintosh HD"
            )
        }

        XCTAssertEqual(reader.readStartupVolume(), .failed(.unavailable))
    }

    func testNegativeCapacityIsInvalidRatherThanZero() {
        let reader = FoundationStartupVolumeReader { _, _ in
            StartupVolumeResourceValues(
                availableCapacityForImportantUsage: -1,
                volumeName: "Macintosh HD"
            )
        }

        XCTAssertEqual(reader.readStartupVolume(), .failed(.invalidCapacity))
    }

    func testThrownResourceReadIsUnavailable() {
        let reader = FoundationStartupVolumeReader { _, _ in
            throw TestError.readFailed
        }

        XCTAssertEqual(reader.readStartupVolume(), .failed(.unavailable))
    }

    private enum TestError: Error {
        case readFailed
        case unexpectedKeys
        case unexpectedURL
    }
}
