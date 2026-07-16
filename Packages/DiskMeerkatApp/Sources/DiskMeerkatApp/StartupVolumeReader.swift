import Foundation

protocol StartupVolumeReader: Sendable {
    func readStartupVolume() -> DiskSpaceReading
}

struct StartupVolumeResourceValues: Equatable, Sendable {
    let availableCapacityForImportantUsage: Int64?
    let volumeName: String?
}

struct FoundationStartupVolumeReader: StartupVolumeReader, Sendable {
    typealias ResourceValuesLoader =
        @Sendable (URL, Set<URLResourceKey>) throws -> StartupVolumeResourceValues

    private static let resourceKeys: Set<URLResourceKey> = [
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeNameKey,
    ]

    private let startupVolumeURL: URL
    private let resourceValuesLoader: ResourceValuesLoader

    init(
        startupVolumeURL: URL = URL(fileURLWithPath: "/", isDirectory: true),
        resourceValuesLoader: @escaping ResourceValuesLoader = Self.loadResourceValues
    ) {
        self.startupVolumeURL = startupVolumeURL
        self.resourceValuesLoader = resourceValuesLoader
    }

    func readStartupVolume() -> DiskSpaceReading {
        let resourceValues: StartupVolumeResourceValues
        do {
            resourceValues = try resourceValuesLoader(startupVolumeURL, Self.resourceKeys)
        } catch {
            return .failed(.unavailable)
        }

        guard let availableBytes = resourceValues.availableCapacityForImportantUsage else {
            return .failed(.unavailable)
        }

        let availableCapacity: DiskCapacity
        do {
            availableCapacity = try DiskCapacity(bytes: availableBytes)
        } catch {
            return .failed(.invalidCapacity)
        }

        return .available(
            StartupVolumeSnapshot(
                availableCapacity: availableCapacity,
                volumeName: normalizedVolumeName(resourceValues.volumeName)
            )
        )
    }

    private static func loadResourceValues(
        from url: URL,
        forKeys keys: Set<URLResourceKey>
    ) throws -> StartupVolumeResourceValues {
        let values = try url.resourceValues(forKeys: keys)
        return StartupVolumeResourceValues(
            availableCapacityForImportantUsage: values.volumeAvailableCapacityForImportantUsage,
            volumeName: values.volumeName
        )
    }

    private func normalizedVolumeName(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        return name
    }
}
