import Foundation

struct StoredMonitoringState: Equatable, Sendable {
    static let defaultValue = StoredMonitoringState(
        configuration: .defaultValue,
        notificationEpisodeState: .armed,
        hasCompletedOnboarding: false
    )

    let configuration: MonitoringConfiguration
    let notificationEpisodeState: NotificationEpisodeState
    let hasCompletedOnboarding: Bool
}

enum MonitoringStatePersistenceError: Error, Equatable, Sendable {
    case corruptData
    case unsupportedSchemaVersion(Int)
    case encodingFailed
}

protocol MonitoringStateRepository: Sendable {
    func load() async throws -> StoredMonitoringState
    func save(_ state: StoredMonitoringState) async throws
}

actor UserDefaultsMonitoringStateRepository: MonitoringStateRepository {
    static let storageKey = "Hippo.DiskMeerkat.monitoringState"

    private static let currentSchemaVersion = 1

    private let defaults: UserDefaults
    private let storageKey: String

    init(storageKey: String = UserDefaultsMonitoringStateRepository.storageKey) {
        defaults = .standard
        self.storageKey = storageKey
    }

    init(
        suiteName: String,
        storageKey: String = UserDefaultsMonitoringStateRepository.storageKey
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create the UserDefaults suite")
        }

        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load() async throws -> StoredMonitoringState {
        guard let storedObject = defaults.object(forKey: storageKey) else {
            return .defaultValue
        }
        guard let data = storedObject as? Data else {
            throw MonitoringStatePersistenceError.corruptData
        }

        let decoder = PropertyListDecoder()
        let header: SchemaHeader
        do {
            header = try decoder.decode(SchemaHeader.self, from: data)
        } catch {
            throw MonitoringStatePersistenceError.corruptData
        }

        guard header.schemaVersion == Self.currentSchemaVersion else {
            throw MonitoringStatePersistenceError.unsupportedSchemaVersion(header.schemaVersion)
        }

        let payload: Version1Payload
        do {
            payload = try decoder.decode(Version1Payload.self, from: data)
        } catch {
            throw MonitoringStatePersistenceError.corruptData
        }

        return try restore(payload)
    }

    func save(_ state: StoredMonitoringState) async throws {
        let payload = Version1Payload(
            schemaVersion: Self.currentSchemaVersion,
            thresholdBytes: state.configuration.threshold.bytes,
            checkIntervalSeconds: state.configuration.interval.rawValue,
            notificationEpisodeState: persistedValue(for: state.notificationEpisodeState),
            hasCompletedOnboarding: state.hasCompletedOnboarding
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw MonitoringStatePersistenceError.encodingFailed
        }

        defaults.set(data, forKey: storageKey)
    }

    private func restore(_ payload: Version1Payload) throws -> StoredMonitoringState {
        let threshold: LowSpaceThreshold
        do {
            threshold = try LowSpaceThreshold(bytes: payload.thresholdBytes)
        } catch {
            throw MonitoringStatePersistenceError.corruptData
        }

        guard let interval = CheckInterval(rawValue: payload.checkIntervalSeconds) else {
            throw MonitoringStatePersistenceError.corruptData
        }

        let episodeState: NotificationEpisodeState
        switch payload.notificationEpisodeState {
        case "armed":
            episodeState = .armed
        case "suppressed":
            episodeState = .suppressed
        default:
            throw MonitoringStatePersistenceError.corruptData
        }

        return StoredMonitoringState(
            configuration: MonitoringConfiguration(threshold: threshold, interval: interval),
            notificationEpisodeState: episodeState,
            hasCompletedOnboarding: payload.hasCompletedOnboarding
        )
    }

    private func persistedValue(for episodeState: NotificationEpisodeState) -> String {
        switch episodeState {
        case .armed:
            "armed"
        case .suppressed:
            "suppressed"
        }
    }

    private struct SchemaHeader: Decodable {
        let schemaVersion: Int

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
        }
    }

    private struct Version1Payload: Codable {
        let schemaVersion: Int
        let thresholdBytes: Int64
        let checkIntervalSeconds: Int
        let notificationEpisodeState: String
        let hasCompletedOnboarding: Bool

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case thresholdBytes
            case checkIntervalSeconds
            case notificationEpisodeState
            case hasCompletedOnboarding
        }
    }
}
