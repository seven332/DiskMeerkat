import Foundation
import XCTest
@testable import DiskMeerkatApp

final class MonitoringStateRepositoryTests: XCTestCase {
    func testMissingStateReturnsDocumentedDefaults() async throws {
        let suiteName = makeSuite()
        defer { removeSuite(named: suiteName) }
        let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)

        let state = try await repository.load()

        XCTAssertEqual(state, .defaultValue)
        XCTAssertEqual(state.configuration.threshold.bytes, 20_000_000_000)
        XCTAssertEqual(state.configuration.interval, .fifteenMinutes)
        XCTAssertEqual(state.notificationEpisodeState, .armed)
        XCTAssertFalse(state.hasCompletedOnboarding)
    }

    func testStateRoundTripsExactValuesAndSurvivesRepositoryRecreation() async throws {
        let suiteName = makeSuite()
        defer { removeSuite(named: suiteName) }
        let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)
        let state = StoredMonitoringState(
            configuration: MonitoringConfiguration(
                threshold: try LowSpaceThreshold(bytes: 999_999_000_000_000),
                interval: .twentyFourHours
            ),
            notificationEpisodeState: .suppressed,
            hasCompletedOnboarding: true
        )

        try await repository.save(state)

        let recreatedRepository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)
        let restoredState = try await recreatedRepository.load()
        XCTAssertEqual(restoredState, state)
        XCTAssertEqual(restoredState.configuration.threshold.bytes, 999_999_000_000_000)
    }

    func testEveryIntervalAndEpisodeStateRoundTrips() async throws {
        for (index, interval) in CheckInterval.allCases.enumerated() {
            for episodeState in [NotificationEpisodeState.armed, .suppressed] {
                let suiteName = makeSuite()
                defer { removeSuite(named: suiteName) }
                let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)
                let state = StoredMonitoringState(
                    configuration: MonitoringConfiguration(
                        threshold: try LowSpaceThreshold(gigabytes: Int64(index + 1)),
                        interval: interval
                    ),
                    notificationEpisodeState: episodeState,
                    hasCompletedOnboarding: index.isMultiple(of: 2)
                )

                try await repository.save(state)
                let restoredState = try await repository.load()

                XCTAssertEqual(restoredState, state)
            }
        }
    }

    func testMalformedDataIsCorruptAndIsNotOverwritten() async throws {
        let originalData = Data([0x00, 0x01, 0x02])
        let suiteName = makeSuite(storedObject: originalData)
        defer { removeSuite(named: suiteName) }
        let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)

        await assertLoadError(.corruptData, from: repository)

        XCTAssertEqual(
            UserDefaults(suiteName: suiteName)?.object(
                forKey: UserDefaultsMonitoringStateRepository.storageKey
            ) as? Data,
            originalData
        )
    }

    func testWrongStoredObjectTypeIsCorruptAndIsNotOverwritten() async throws {
        let suiteName = makeSuite(storedObject: "not data")
        defer { removeSuite(named: suiteName) }
        let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)

        await assertLoadError(.corruptData, from: repository)

        XCTAssertEqual(
            UserDefaults(suiteName: suiteName)?.object(
                forKey: UserDefaultsMonitoringStateRepository.storageKey
            ) as? String,
            "not data"
        )
    }

    func testUnsupportedSchemaIsReportedBeforeVersionSpecificDecoding() async throws {
        let data = try encode(UnsupportedPayload(schemaVersion: 2, futureValue: "future"))
        let suiteName = makeSuite(storedObject: data)
        defer { removeSuite(named: suiteName) }
        let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)

        await assertLoadError(.unsupportedSchemaVersion(2), from: repository)
    }

    func testInvalidVersionOneFieldsAreCorrupt() async throws {
        let payloads = [
            TestVersion1Payload(
                schemaVersion: 1,
                thresholdBytes: -1,
                checkIntervalSeconds: CheckInterval.fifteenMinutes.rawValue,
                notificationEpisodeState: "armed",
                hasCompletedOnboarding: false
            ),
            TestVersion1Payload(
                schemaVersion: 1,
                thresholdBytes: LowSpaceThreshold.defaultValue.bytes,
                checkIntervalSeconds: 1,
                notificationEpisodeState: "armed",
                hasCompletedOnboarding: false
            ),
            TestVersion1Payload(
                schemaVersion: 1,
                thresholdBytes: LowSpaceThreshold.defaultValue.bytes,
                checkIntervalSeconds: CheckInterval.fifteenMinutes.rawValue,
                notificationEpisodeState: "unknown",
                hasCompletedOnboarding: false
            ),
        ]

        for payload in payloads {
            let suiteName = makeSuite(storedObject: try encode(payload))
            defer { removeSuite(named: suiteName) }
            let repository = UserDefaultsMonitoringStateRepository(suiteName: suiteName)

            await assertLoadError(.corruptData, from: repository)
        }
    }

    private func assertLoadError(
        _ expectedError: MonitoringStatePersistenceError,
        from repository: UserDefaultsMonitoringStateRepository
    ) async {
        do {
            _ = try await repository.load()
            XCTFail("Expected load to fail with \(expectedError)")
        } catch {
            XCTAssertEqual(error as? MonitoringStatePersistenceError, expectedError)
        }
    }

    private func makeSuite(storedObject: Any? = nil) -> String {
        let name = "DiskMeerkatAppTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        if let storedObject {
            defaults.set(storedObject, forKey: UserDefaultsMonitoringStateRepository.storageKey)
        }
        return name
    }

    private func removeSuite(named name: String) {
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    private struct UnsupportedPayload: Encodable {
        let schemaVersion: Int
        let futureValue: String
    }

    private struct TestVersion1Payload: Encodable {
        let schemaVersion: Int
        let thresholdBytes: Int64
        let checkIntervalSeconds: Int
        let notificationEpisodeState: String
        let hasCompletedOnboarding: Bool
    }
}
