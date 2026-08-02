import Foundation
import SwiftData

public struct PrayerNotificationConfig: Codable, Sendable, Equatable {
    public var prayer: Prayer
    public var isEnabled: Bool
    public var athanSoundName: String
    public var leadTimeSeconds: Int
    /// Whether this prayer's notification may break through Focus.
    /// Off unless asked for: the app does not decide on its own that it
    /// is allowed to interrupt.
    public var isTimeSensitive: Bool

    public init(
        prayer: Prayer,
        isEnabled: Bool = true,
        athanSoundName: String = "default",
        leadTimeSeconds: Int = 0,
        isTimeSensitive: Bool = false
    ) {
        self.prayer = prayer
        self.isEnabled = isEnabled
        self.athanSoundName = athanSoundName
        self.leadTimeSeconds = leadTimeSeconds
        self.isTimeSensitive = isTimeSensitive
    }

    /// Decoded leniently so a payload written by an earlier build — one
    /// with no `isTimeSensitive` key — still reads, rather than
    /// throwing away every per-prayer preference a person had set.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prayer = try container.decode(Prayer.self, forKey: .prayer)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        athanSoundName = try container.decodeIfPresent(String.self, forKey: .athanSoundName) ?? "default"
        leadTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .leadTimeSeconds) ?? 0
        isTimeSensitive = try container.decodeIfPresent(Bool.self, forKey: .isTimeSensitive) ?? false
    }
}

/// Editable rawatib counts around one fard prayer. The defaults are a
/// commonly kept set, not a ruling — schools differ, and the counts are the
/// user's to change.
public struct RawatibConfig: Codable, Sendable, Equatable {
    public var prayer: Prayer
    public var beforeCount: Int
    public var afterCount: Int

    public init(prayer: Prayer, beforeCount: Int, afterCount: Int) {
        self.prayer = prayer
        self.beforeCount = beforeCount
        self.afterCount = afterCount
    }
}

@Model
public final class UserSettings {
    public static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public var id: UUID = UserSettings.singletonID

    public var calculationMethodRaw: String = CalculationMethodChoice.isna.rawValue
    public var madhabRaw: String = MadhabChoice.standard.rawValue
    public var highLatitudeRuleRaw: String = HighLatitudeRule.middleOfNight.rawValue
    /// Calculation depth — all nil / zero means "the chosen method,
    /// untouched". `customFajrAngle` and the Isha pair override the
    /// method's own twilight angles; the offsets are whole-minute
    /// corrections applied after the solar math.
    public var customFajrAngle: Double?
    public var customIshaAngle: Double?
    public var customIshaIntervalMinutes: Int?
    public var prayerOffsetFajrMinutes: Int = 0
    public var prayerOffsetDhuhrMinutes: Int = 0
    public var prayerOffsetAsrMinutes: Int = 0
    public var prayerOffsetMaghribMinutes: Int = 0
    public var prayerOffsetIshaMinutes: Int = 0
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
    /// Whether the in-app adhan plays when the ringer switch is off.
    /// Off by default: the silent switch means silent, and an app that
    /// overrides it without being asked has broken a promise the phone
    /// made to its owner.
    public var adhanPlaysInSilentMode: Bool = false
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
    /// The sunnah layer is invisible until the user turns it on. Nothing in
    /// the off state hints that anything is missing.
    public var sunnahLayerEnabled: Bool = false
    public var sunnahRawatibEnabled: Bool = false
    public var sunnahDuhaEnabled: Bool = false
    public var sunnahNightEnabled: Bool = false
    /// Whether logging a nafl asks for a rak'ah count. Off by default —
    /// one tap records, nothing prompts.
    public var sunnahRakahCountsEnabled: Bool = false
    public var rawatibConfigJSON: String = UserSettings.defaultRawatibConfigJSON
    public var duhaSunriseOffsetMinutes: Int = 20
    public var duhaDhuhrMarginMinutes: Int = 15
    /// Optional nafl overlay on the Path dot rows — visible if sought.
    public var pathNaflOverlayEnabled: Bool = false
    /// Voluntary fasting rhythms — gentle intentions, OFF by default.
    /// When enabled, the significant-day line doubles as a quiet
    /// offer; never a notification by default.
    public var fastingMonThuOfferEnabled: Bool = false
    public var fastingWhiteDaysOfferEnabled: Bool = false
    /// Optional dhikr presence on the Path — off by default, factual
    /// counts only, exactly like the nafl overlay.
    public var pathDhikrOverlayEnabled: Bool = false
    /// The gentle wake for the last third of the night. Strictly opt-in.
    public var nightWakeEnabled: Bool = false
    /// Minutes before the last third's start to wake; 0 wakes at its start.
    public var nightWakeOffsetMinutes: Int = 0

    // MARK: - Adhkar
    //
    // The remembrance layer, invisible until the user turns it on —
    // the same discipline as the sunnah layer. Nothing in the off
    // state hints that anything is missing, and nothing here ever
    // schedules a notification: the windows offer, they never call.

    public var adhkarLayerEnabled: Bool = false
    public var adhkarMorningEnabled: Bool = false
    public var adhkarEveningEnabled: Bool = false
    public var adhkarPostPrayerEnabled: Bool = false
    public var adhkarSleepEnabled: Bool = false

    /// Whether the reading surface shows romanised Arabic beneath the
    /// line. On by default: someone still learning the words needs it,
    /// and someone who does not can turn it off in one tap.
    public var adhkarShowsTransliteration: Bool = true

    /// How far past sunrise the morning window runs. Schools differ on
    /// where the morning ends; the default carries it into
    /// mid-morning, and the bound is the user's to set.
    public var adhkarMorningEndsAfterSunriseMinutes: Int = 90

    /// How far past Maghrib the evening window runs. Some hold the
    /// evening closes at Maghrib, others that it runs through the
    /// early night; the default sits between them and is the user's to
    /// set — 0 closes it at Maghrib exactly.
    public var adhkarEveningExtendsAfterMaghribMinutes: Int = 60
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
        calculationTuning: CalculationTuning = .standard,
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
        adhanPlaysInSilentMode: Bool = false,
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
        sunnahLayerEnabled: Bool = false,
        sunnahRawatibEnabled: Bool = false,
        sunnahDuhaEnabled: Bool = false,
        sunnahNightEnabled: Bool = false,
        sunnahRakahCountsEnabled: Bool = false,
        rawatibConfigJSON: String = UserSettings.defaultRawatibConfigJSON,
        duhaSunriseOffsetMinutes: Int = 20,
        duhaDhuhrMarginMinutes: Int = 15,
        pathNaflOverlayEnabled: Bool = false,
        fastingMonThuOfferEnabled: Bool = false,
        fastingWhiteDaysOfferEnabled: Bool = false,
        pathDhikrOverlayEnabled: Bool = false,
        nightWakeEnabled: Bool = false,
        nightWakeOffsetMinutes: Int = 0,
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
        self.customFajrAngle = calculationTuning.fajrAngle
        self.customIshaAngle = calculationTuning.ishaRule.storedAngle
        self.customIshaIntervalMinutes = calculationTuning.ishaRule.storedIntervalMinutes
        self.prayerOffsetFajrMinutes = calculationTuning.offsets.fajr
        self.prayerOffsetDhuhrMinutes = calculationTuning.offsets.dhuhr
        self.prayerOffsetAsrMinutes = calculationTuning.offsets.asr
        self.prayerOffsetMaghribMinutes = calculationTuning.offsets.maghrib
        self.prayerOffsetIshaMinutes = calculationTuning.offsets.isha
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
        self.adhanPlaysInSilentMode = adhanPlaysInSilentMode
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
        self.sunnahLayerEnabled = sunnahLayerEnabled
        self.sunnahRawatibEnabled = sunnahRawatibEnabled
        self.sunnahDuhaEnabled = sunnahDuhaEnabled
        self.sunnahNightEnabled = sunnahNightEnabled
        self.sunnahRakahCountsEnabled = sunnahRakahCountsEnabled
        self.rawatibConfigJSON = rawatibConfigJSON
        self.duhaSunriseOffsetMinutes = duhaSunriseOffsetMinutes
        self.duhaDhuhrMarginMinutes = duhaDhuhrMarginMinutes
        self.pathNaflOverlayEnabled = pathNaflOverlayEnabled
        self.fastingMonThuOfferEnabled = fastingMonThuOfferEnabled
        self.fastingWhiteDaysOfferEnabled = fastingWhiteDaysOfferEnabled
        self.pathDhikrOverlayEnabled = pathDhikrOverlayEnabled
        self.nightWakeEnabled = nightWakeEnabled
        self.nightWakeOffsetMinutes = nightWakeOffsetMinutes
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

    /// A commonly kept rawatib set — Fajr 2 before; Dhuhr 4 before, 2 after;
    /// Maghrib and Isha 2 after. Schools differ; every count is editable.
    public static var defaultRawatibConfigJSON: String {
        let configs = [
            RawatibConfig(prayer: .fajr, beforeCount: 2, afterCount: 0),
            RawatibConfig(prayer: .dhuhr, beforeCount: 4, afterCount: 2),
            RawatibConfig(prayer: .asr, beforeCount: 0, afterCount: 0),
            RawatibConfig(prayer: .maghrib, beforeCount: 0, afterCount: 2),
            RawatibConfig(prayer: .isha, beforeCount: 0, afterCount: 2),
        ]

        // Sorted keys so the stored default is byte-stable across
        // processes — JSONEncoder's unsorted output varies per run.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(configs),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return json
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

    /// The calculation depth, assembled from the stored columns. Every
    /// surface that computes prayer times reads this and hands it to the
    /// provider alongside the method — there is no second path.
    var calculationTuning: CalculationTuning {
        get {
            CalculationTuning(
                fajrAngle: customFajrAngle,
                ishaRule: IshaRule(
                    storedAngle: customIshaAngle,
                    storedIntervalMinutes: customIshaIntervalMinutes
                ),
                offsets: PrayerOffsets(
                    fajr: prayerOffsetFajrMinutes,
                    dhuhr: prayerOffsetDhuhrMinutes,
                    asr: prayerOffsetAsrMinutes,
                    maghrib: prayerOffsetMaghribMinutes,
                    isha: prayerOffsetIshaMinutes
                )
            )
        }
        set {
            customFajrAngle = newValue.fajrAngle
            customIshaAngle = newValue.ishaRule.storedAngle
            customIshaIntervalMinutes = newValue.ishaRule.storedIntervalMinutes
            prayerOffsetFajrMinutes = newValue.offsets.fajr
            prayerOffsetDhuhrMinutes = newValue.offsets.dhuhr
            prayerOffsetAsrMinutes = newValue.offsets.asr
            prayerOffsetMaghribMinutes = newValue.offsets.maghrib
            prayerOffsetIshaMinutes = newValue.offsets.isha
        }
    }

    var theme: ThemePreference {
        ThemePreference(rawValue: themeRaw) ?? .auto
    }

    /// The user's rawatib counts, falling back to the neutral defaults when
    /// the stored JSON is unreadable.
    var rawatibConfigs: [RawatibConfig] {
        guard let data = rawatibConfigJSON.data(using: .utf8),
              let configs = try? JSONDecoder().decode([RawatibConfig].self, from: data),
              !configs.isEmpty
        else {
            guard let fallback = UserSettings.defaultRawatibConfigJSON.data(using: .utf8),
                  let configs = try? JSONDecoder().decode([RawatibConfig].self, from: fallback)
            else {
                return []
            }
            return configs
        }
        return configs
    }

    func rawatibConfig(for prayer: Prayer) -> RawatibConfig {
        rawatibConfigs.first { $0.prayer == prayer }
            ?? RawatibConfig(prayer: prayer, beforeCount: 0, afterCount: 0)
    }

    func setRawatibConfig(_ config: RawatibConfig) {
        var configs = rawatibConfigs
        if let index = configs.firstIndex(where: { $0.prayer == config.prayer }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        if let data = try? JSONEncoder().encode(configs),
           let json = String(data: data, encoding: .utf8) {
            rawatibConfigJSON = json
        }
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
