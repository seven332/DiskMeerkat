enum DiskCapacityValidationError: Error, Equatable, Sendable {
    case negativeBytes
}

enum ThresholdRelationship: Equatable, Sendable {
    case below
    case equal
    case above
}

struct DiskCapacity: Comparable, Sendable {
    static let bytesPerGigabyte: Int64 = 1_000_000_000

    let bytes: Int64

    init(bytes: Int64) throws {
        guard bytes >= 0 else {
            throw DiskCapacityValidationError.negativeBytes
        }

        self.bytes = bytes
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.bytes < rhs.bytes
    }

    func relationship(to threshold: LowSpaceThreshold) -> ThresholdRelationship {
        if bytes < threshold.bytes {
            .below
        } else if bytes > threshold.bytes {
            .above
        } else {
            .equal
        }
    }
}

enum LowSpaceThresholdValidationError: Error, Equatable, Sendable {
    case notWholeGigabyte
    case outsideSupportedRange
}

struct LowSpaceThreshold: Comparable, Sendable {
    static let minimumGigabytes: Int64 = 1
    static let maximumGigabytes: Int64 = 1_000_000
    static let defaultValue = LowSpaceThreshold(validatedGigabytes: 20)

    let bytes: Int64

    var gigabytes: Int64 {
        bytes / DiskCapacity.bytesPerGigabyte
    }

    init(gigabytes: Int64) throws {
        guard Self.minimumGigabytes...Self.maximumGigabytes ~= gigabytes else {
            throw LowSpaceThresholdValidationError.outsideSupportedRange
        }

        self.init(validatedGigabytes: gigabytes)
    }

    init(bytes: Int64) throws {
        guard bytes.isMultiple(of: DiskCapacity.bytesPerGigabyte) else {
            throw LowSpaceThresholdValidationError.notWholeGigabyte
        }

        try self.init(gigabytes: bytes / DiskCapacity.bytesPerGigabyte)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.bytes < rhs.bytes
    }

    private init(validatedGigabytes: Int64) {
        bytes = validatedGigabytes * DiskCapacity.bytesPerGigabyte
    }
}

enum CheckInterval: Int, CaseIterable, Sendable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1_800
    case oneHour = 3_600
    case sixHours = 21_600
    case twentyFourHours = 86_400

    static let defaultValue = CheckInterval.fifteenMinutes

    var duration: Duration {
        .seconds(rawValue)
    }
}

struct MonitoringConfiguration: Equatable, Sendable {
    static let defaultValue = MonitoringConfiguration(
        threshold: .defaultValue,
        interval: .defaultValue
    )

    let threshold: LowSpaceThreshold
    let interval: CheckInterval
}
