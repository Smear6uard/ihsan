import Foundation
import SwiftData

public struct PrayerNotificationConfig: Codable, Sendable {
    public var prayer: Prayer
    public var isEnabled: Bool
    public var athanSoundName: String
    public var leadTimeSeconds: Int

    public init(
        prayer: Prayer,
        isEnabled: Bool = true,
        athanSoundName: String = "default",
        leadTimeSeconds: Int = 0
    ) {
        self.prayer = prayer
        self.isEnabled = isEnabled
        self.athanSoundName = athanSoundName
        self.leadTimeSeconds = leadTimeSeconds
    }
}

@Model
public final class UserSettings {
    public static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public var id: UUID = UserSettings.singletonID

    public var calculationMethodRaw: String = CalculationMethodChoice.isna.rawValue
    public var madhabRaw: String = MadhabChoice.standard.rawValue
    public var highLatitudeRuleRaw: String = HighLatitudeRule.middleOfNight.rawValue
    public var automaticLocationUpdatesEnabled: Bool = true
    @Attribute(.allowsCloudEncryption)
    public var lastResolvedCityName: String?
    public var lastResolvedCountryCode: String?
    public var notificationsEnabled: Bool = true
    public var hasCompletedOnboarding: Bool = false
    public var prayerNotificationsConfigJSON: String = UserSettings.defaultPrayerNotificationsConfigJSON
    /// Per-prayer adhan-sound toggle. When `true` the scheduled notification
    /// plays the user's chosen adhan recording; when `false` it falls back to
    /// the system default tone. Independent of whether the notification fires
    /// at all (that's controlled by `prayerNotificationsConfigJSON`).
    public var adhanEnabledFajr: Bool = true
    public var adhanEnabledDhuhr: Bool = true
    public var adhanEnabledAsr: Bool = true
    public var adhanEnabledMaghrib: Bool = true
    public var adhanEnabledIsha: Bool = true
    public var themeRaw: String = ThemePreference.dark.rawValue
    public var hijriCalendarOffsetDays: Int = 0
    public var arabicNumeralsEnabled: Bool = false
    public var weekStartsOnSaturday: Bool = true
    public var showStreaksUI: Bool = false
    public var aiInsightsEnabled: Bool = true
    public var autoSyncAudioMemos: Bool = false
    /// Makeup-prayer (qada) tracking is invisible until the user opts in.
    public var qadaTrackingEnabled: Bool = false
    public var qadaTracksWitr: Bool = false
    /// When a day's prayer passes unlogged, whether it flows into the
    /// makeup ledger. The user chooses this at setup and can change it later.
    public var qadaMissedFlowEnabled: Bool = false
    public var qadaPathCardDismissed: Bool = false
    /// A quiet daily-intention reminder preference — not a tracked goal.
    public var qadaDailyIntentionEnabled: Bool = false
    public var qadaSetupCompletedAt: Date?
    public var lastDataExportAt: Date?
    public var lastDataDeletionRequestAt: Date?
    public var schemaVersion: Int = 1
    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UserSettings.singletonID,
        calculationMethod: CalculationMethodChoice = .isna,
        madhab: MadhabChoice = .standard,
        highLatitudeRule: HighLatitudeRule = .middleOfNight,
        automaticLocationUpdatesEnabled: Bool = true,
        lastResolvedCityName: String? = nil,
        lastResolvedCountryCode: String? = nil,
        notificationsEnabled: Bool = true,
        hasCompletedOnboarding: Bool = false,
        prayerNotificationsConfigJSON: String = UserSettings.defaultPrayerNotificationsConfigJSON,
        adhanEnabledFajr: Bool = true,
        adhanEnabledDhuhr: Bool = true,
        adhanEnabledAsr: Bool = true,
        adhanEnabledMaghrib: Bool = true,
        adhanEnabledIsha: Bool = true,
        theme: ThemePreference = .dark,
        hijriCalendarOffsetDays: Int = 0,
        arabicNumeralsEnabled: Bool = false,
        weekStartsOnSaturday: Bool = true,
        showStreaksUI: Bool = false,
        aiInsightsEnabled: Bool = true,
        autoSyncAudioMemos: Bool = false,
        qadaTrackingEnabled: Bool = false,
        qadaTracksWitr: Bool = false,
        qadaMissedFlowEnabled: Bool = false,
        qadaPathCardDismissed: Bool = false,
        qadaDailyIntentionEnabled: Bool = false,
        qadaSetupCompletedAt: Date? = nil,
        lastDataExportAt: Date? = nil,
        lastDataDeletionRequestAt: Date? = nil,
        schemaVersion: Int = 1,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.calculationMethodRaw = calculationMethod.rawValue
        self.madhabRaw = madhab.rawValue
        self.highLatitudeRuleRaw = highLatitudeRule.rawValue
        self.automaticLocationUpdatesEnabled = automaticLocationUpdatesEnabled
        self.lastResolvedCityName = lastResolvedCityName
        self.lastResolvedCountryCode = lastResolvedCountryCode
        self.notificationsEnabled = notificationsEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.prayerNotificationsConfigJSON = prayerNotificationsConfigJSON
        self.adhanEnabledFajr = adhanEnabledFajr
        self.adhanEnabledDhuhr = adhanEnabledDhuhr
        self.adhanEnabledAsr = adhanEnabledAsr
        self.adhanEnabledMaghrib = adhanEnabledMaghrib
        self.adhanEnabledIsha = adhanEnabledIsha
        self.themeRaw = theme.rawValue
        self.hijriCalendarOffsetDays = hijriCalendarOffsetDays
        self.arabicNumeralsEnabled = arabicNumeralsEnabled
        self.weekStartsOnSaturday = weekStartsOnSaturday
        self.showStreaksUI = showStreaksUI
        self.aiInsightsEnabled = aiInsightsEnabled
        self.autoSyncAudioMemos = autoSyncAudioMemos
        self.qadaTrackingEnabled = qadaTrackingEnabled
        self.qadaTracksWitr = qadaTracksWitr
        self.qadaMissedFlowEnabled = qadaMissedFlowEnabled
        self.qadaPathCardDismissed = qadaPathCardDismissed
        self.qadaDailyIntentionEnabled = qadaDailyIntentionEnabled
        self.qadaSetupCompletedAt = qadaSetupCompletedAt
        self.lastDataExportAt = lastDataExportAt
        self.lastDataDeletionRequestAt = lastDataDeletionRequestAt
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public static func fetchOrCreate(in context: ModelContext) throws -> UserSettings {
        let singletonID = UserSettings.singletonID
        var descriptor = FetchDescriptor<UserSettings>(
            predicate: #Predicate<UserSettings> { $0.id == singletonID }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let settings = UserSettings()
        context.insert(settings)
        return settings
    }

    public static var defaultPrayerNotificationsConfigJSON: String {
        let configs = Prayer.allCases.map {
            PrayerNotificationConfig(prayer: $0)
        }

        guard let data = try? JSONEncoder().encode(configs),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return json
    }
}

public extension UserSettings {
    var calculationMethod: CalculationMethodChoice {
        CalculationMethodChoice(rawValue: calculationMethodRaw) ?? .isna
    }

    var madhab: MadhabChoice {
        MadhabChoice(rawValue: madhabRaw) ?? .standard
    }

    var highLatitudeRule: HighLatitudeRule {
        HighLatitudeRule(rawValue: highLatitudeRuleRaw) ?? .middleOfNight
    }

    var theme: ThemePreference {
        ThemePreference(rawValue: themeRaw) ?? .auto
    }

    /// Whether the configured adhan sound plays for the given prayer. When
    /// `false`, the scheduled notification uses the system default tone
    /// instead of the chosen adhan recording. Whether the notification
    /// fires at all is controlled separately via `prayerNotificationsConfigJSON`.
    func adhanEnabled(for prayer: Prayer) -> Bool {
        switch prayer {
        case .fajr: return adhanEnabledFajr
        case .dhuhr: return adhanEnabledDhuhr
        case .asr: return adhanEnabledAsr
        case .maghrib: return adhanEnabledMaghrib
        case .isha: return adhanEnabledIsha
        }
    }

    func setAdhanEnabled(_ enabled: Bool, for prayer: Prayer) {
        switch prayer {
        case .fajr: adhanEnabledFajr = enabled
        case .dhuhr: adhanEnabledDhuhr = enabled
        case .asr: adhanEnabledAsr = enabled
        case .maghrib: adhanEnabledMaghrib = enabled
        case .isha: adhanEnabledIsha = enabled
        }
    }
}
