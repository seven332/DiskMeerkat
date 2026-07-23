import Foundation

enum MonitoringThresholdDraftError: Error, Equatable, Sendable {
    case required
    case wholeNumber
    case outsideSupportedRange

    func message(
        localization: DiskMeerkatLocalization = .current
    ) -> LocalizedStringResource {
        switch self {
        case .required:
            localization.validationThresholdRequired
        case .wholeNumber:
            localization.validationThresholdWholeNumber
        case .outsideSupportedRange:
            localization.validationThresholdRange
        }
    }
}

struct MonitoringSettingsDraft: Equatable, Sendable {
    private(set) var baselineConfiguration: MonitoringConfiguration
    private(set) var baselineThresholdText: String
    var thresholdText: String
    var interval: CheckInterval
    let locale: Locale

    init(
        configuration: MonitoringConfiguration,
        locale: Locale = .autoupdatingCurrent
    ) {
        baselineConfiguration = configuration
        self.locale = locale
        let thresholdText = Self.thresholdText(
            for: configuration.threshold,
            locale: locale
        )
        baselineThresholdText = thresholdText
        self.thresholdText = thresholdText
        interval = configuration.interval
    }

    var thresholdResult: Result<LowSpaceThreshold, MonitoringThresholdDraftError> {
        Self.parseThreshold(thresholdText, locale: locale)
    }

    var thresholdError: MonitoringThresholdDraftError? {
        guard case .failure(let error) = thresholdResult else {
            return nil
        }
        return error
    }

    var validatedConfiguration: MonitoringConfiguration? {
        guard case .success(let threshold) = thresholdResult else {
            return nil
        }
        return MonitoringConfiguration(threshold: threshold, interval: interval)
    }

    var isDirty: Bool {
        if let validatedConfiguration {
            return validatedConfiguration != baselineConfiguration
        }
        return thresholdText != baselineThresholdText || interval != baselineConfiguration.interval
    }

    mutating func reset(to configuration: MonitoringConfiguration) {
        self = MonitoringSettingsDraft(configuration: configuration, locale: locale)
    }

    private static func parseThreshold(
        _ text: String,
        locale: Locale
    ) -> Result<LowSpaceThreshold, MonitoringThresholdDraftError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.required)
        }
        guard trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "eE")) == nil else {
            return .failure(.wholeNumber)
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = false
        var object: AnyObject?
        var range = NSRange(location: 0, length: trimmed.utf16.count)
        do {
            try formatter.getObjectValue(&object, for: trimmed, range: &range)
        } catch {
            return .failure(.wholeNumber)
        }
        guard range.location == 0, range.length == trimmed.utf16.count,
            let number = object as? NSNumber
        else {
            return .failure(.wholeNumber)
        }

        let decimal = number.decimalValue
        var rounded = Decimal()
        var value = decimal
        NSDecimalRound(&rounded, &value, 0, .plain)
        guard rounded == decimal else {
            return .failure(.wholeNumber)
        }
        let minimum = Decimal(LowSpaceThreshold.minimumGigabytes)
        let maximum = Decimal(LowSpaceThreshold.maximumGigabytes)
        guard decimal >= minimum, decimal <= maximum else {
            return .failure(.outsideSupportedRange)
        }

        do {
            return .success(try LowSpaceThreshold(gigabytes: number.int64Value))
        } catch {
            return .failure(.outsideSupportedRange)
        }
    }

    private static func thresholdText(
        for threshold: LowSpaceThreshold,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: threshold.gigabytes))
            ?? String(threshold.gigabytes)
    }
}

public enum DiskMeerkatAccessibilityIdentifiers {
    public static let menuBarStatus = "diskMeerkat.menuBar.status"
    public static let menuStatus = "diskMeerkat.menu.status"
    public static let menuCapacity = "diskMeerkat.menu.capacity"
    public static let menuCheckNow = "diskMeerkat.menu.checkNow"
    public static let menuOpenStatus = "diskMeerkat.menu.openStatus"
    public static let menuOpenSettings = "diskMeerkat.menu.openSettings"
    public static let menuQuit = "diskMeerkat.menu.quit"
    public static let statusRoot = "diskMeerkat.status.root"
    public static let statusCapacity = "diskMeerkat.status.capacity"
    public static let statusCheckNow = "diskMeerkat.status.checkNow"
    public static let statusEnableNotifications = "diskMeerkat.status.enableNotifications"
    public static let statusOpenNotificationSettings =
        "diskMeerkat.status.openNotificationSettings"
    public static let statusDismissOnboarding = "diskMeerkat.status.dismissOnboarding"
    public static let settingsRoot = "diskMeerkat.settings.root"
    public static let settingsThreshold = "diskMeerkat.settings.threshold"
    public static let settingsInterval = "diskMeerkat.settings.interval"
    public static let settingsSave = "diskMeerkat.settings.save"
    public static let settingsCancel = "diskMeerkat.settings.cancel"
    public static let settingsEnableNotifications = "diskMeerkat.settings.enableNotifications"
    public static let settingsOpenNotificationSettings =
        "diskMeerkat.settings.openNotificationSettings"
    public static let settingsLaunchAtLogin = "diskMeerkat.settings.launchAtLogin"
    public static let settingsOpenLoginSettings = "diskMeerkat.settings.openLoginSettings"

    static let all: [String] = [
        menuBarStatus,
        menuStatus,
        menuCapacity,
        menuCheckNow,
        menuOpenStatus,
        menuOpenSettings,
        menuQuit,
        statusRoot,
        statusCapacity,
        statusCheckNow,
        statusEnableNotifications,
        statusOpenNotificationSettings,
        statusDismissOnboarding,
        settingsRoot,
        settingsThreshold,
        settingsInterval,
        settingsSave,
        settingsCancel,
        settingsEnableNotifications,
        settingsOpenNotificationSettings,
        settingsLaunchAtLogin,
        settingsOpenLoginSettings,
    ]
}
