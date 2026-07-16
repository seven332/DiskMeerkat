import Foundation

struct DiskCapacityFormatter: Sendable {
    private static let defaultMaximumFractionDigits = 1
    private static let bytePrecisionFractionDigits = 9

    let locale: Locale

    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    func string(
        for capacity: DiskCapacity,
        relativeTo threshold: LowSpaceThreshold
    ) -> String {
        let capacityInGigabytes = Decimal(capacity.bytes) / Decimal(DiskCapacity.bytesPerGigabyte)
        let thresholdInGigabytes = Decimal(threshold.gigabytes)
        let relationship = capacity.relationship(to: threshold)
        let maximumFractionDigits = maximumFractionDigits(
            for: capacityInGigabytes,
            threshold: thresholdInGigabytes,
            relationship: relationship
        )
        let formatter = makeNumberFormatter(maximumFractionDigits: maximumFractionDigits)
        let number = NSDecimalNumber(decimal: capacityInGigabytes)
        let formattedNumber = formatter.string(from: number) ?? number.stringValue

        return "\(formattedNumber) GB"
    }

    private func maximumFractionDigits(
        for capacity: Decimal,
        threshold: Decimal,
        relationship: ThresholdRelationship
    ) -> Int {
        for fractionDigits in Self.defaultMaximumFractionDigits...Self.bytePrecisionFractionDigits {
            let roundedCapacity = rounded(capacity, fractionDigits: fractionDigits)
            if preserves(relationship, roundedCapacity: roundedCapacity, threshold: threshold) {
                return fractionDigits
            }
        }

        return Self.bytePrecisionFractionDigits
    }

    private func rounded(_ value: Decimal, fractionDigits: Int) -> Decimal {
        var value = value
        var result = Decimal()
        NSDecimalRound(&result, &value, fractionDigits, .plain)
        return result
    }

    private func preserves(
        _ relationship: ThresholdRelationship,
        roundedCapacity: Decimal,
        threshold: Decimal
    ) -> Bool {
        switch relationship {
        case .below:
            roundedCapacity < threshold
        case .equal:
            roundedCapacity == threshold
        case .above:
            roundedCapacity > threshold
        }
    }

    private func makeNumberFormatter(maximumFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        formatter.locale = locale
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfUp
        formatter.usesGroupingSeparator = true
        return formatter
    }
}
