import Foundation
import XCTest
@testable import DiskMeerkatApp

final class StartupVolumeReaderTests: XCTestCase {
    func testValidReadUsesStartupRootAndRequiredResourceKeys() async throws {
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

        let reading = await reader.readStartupVolume()
        XCTAssertEqual(
            reading,
            .available(
                StartupVolumeSnapshot(
                    availableCapacity: try DiskCapacity(bytes: 42_000_000_000),
                    volumeName: "Macintosh HD"
                )
            )
        )
    }

    func testMissingAndBlankNamesRemainSuccessfulReads() async throws {
        for name in [nil, "", " \n\t"] as [String?] {
            let reader = FoundationStartupVolumeReader { _, _ in
                StartupVolumeResourceValues(
                    availableCapacityForImportantUsage: 20_000_000_000,
                    volumeName: name
                )
            }

            let reading = await reader.readStartupVolume()
            XCTAssertEqual(
                reading,
                .available(
                    StartupVolumeSnapshot(
                        availableCapacity: try DiskCapacity(bytes: 20_000_000_000),
                        volumeName: nil
                    )
                )
            )
        }
    }

    func testVolumeNameIsTrimmed() async throws {
        let reader = FoundationStartupVolumeReader { _, _ in
            StartupVolumeResourceValues(
                availableCapacityForImportantUsage: 20_000_000_000,
                volumeName: "  Macintosh HD \n"
            )
        }

        let reading = await reader.readStartupVolume()
        XCTAssertEqual(
            reading,
            .available(
                StartupVolumeSnapshot(
                    availableCapacity: try DiskCapacity(bytes: 20_000_000_000),
                    volumeName: "Macintosh HD"
                )
            )
        )
    }

    func testMissingCapacityIsUnavailableRatherThanZero() async {
        let reader = FoundationStartupVolumeReader { _, _ in
            StartupVolumeResourceValues(
                availableCapacityForImportantUsage: nil,
                volumeName: "Macintosh HD"
            )
        }

        let reading = await reader.readStartupVolume()
        XCTAssertEqual(reading, .failed(.unavailable))
    }

    func testNegativeCapacityIsInvalidRatherThanZero() async {
        let reader = FoundationStartupVolumeReader { _, _ in
            StartupVolumeResourceValues(
                availableCapacityForImportantUsage: -1,
                volumeName: "Macintosh HD"
            )
        }

        let reading = await reader.readStartupVolume()
        XCTAssertEqual(reading, .failed(.invalidCapacity))
    }

    func testThrownResourceReadIsUnavailable() async {
        let reader = FoundationStartupVolumeReader { _, _ in
            throw TestError.readFailed
        }

        let reading = await reader.readStartupVolume()
        XCTAssertEqual(reading, .failed(.unavailable))
    }

    private enum TestError: Error {
        case readFailed
        case unexpectedKeys
        case unexpectedURL
    }
}
