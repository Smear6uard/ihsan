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

    @Attribute(.unique)
    public var id: UUID = UserSettings.singletonID

    public var calculationMethodRaw: String = CalculationMethodChoice.isna.rawValue
    public var madhabRaw: String = MadhabChoice.standard.rawValue
    public var highLatitudeRuleRaw: String = HighLatitudeRule.middleOfNight.rawValue
    public var notificationsEnabled: Bool = true
    public var hasCompletedOnboarding: Bool = false
    public var prayerNotificationsConfigJSON: String = UserSettings.defaultPrayerNotificationsConfigJSON
    public var themeRaw: String = ThemePreference.auto.rawValue
    public var hijriCalendarOffsetDays: Int = 0
    public var arabicNumeralsEnabled: Bool = false
    public var weekStartsOnSaturday: Bool = true
    public var showStreaksUI: Bool = false
    public var aiInsightsEnabled: Bool = true
    public var autoSyncAudioMemos: Bool = false
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
        notificationsEnabled: Bool = true,
        hasCompletedOnboarding: Bool = false,
        prayerNotificationsConfigJSON: String = UserSettings.defaultPrayerNotificationsConfigJSON,
        theme: ThemePreference = .auto,
        hijriCalendarOffsetDays: Int = 0,
        arabicNumeralsEnabled: Bool = false,
        weekStartsOnSaturday: Bool = true,
        showStreaksUI: Bool = false,
        aiInsightsEnabled: Bool = true,
        autoSyncAudioMemos: Bool = false,
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
        self.notificationsEnabled = notificationsEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.prayerNotificationsConfigJSON = prayerNotificationsConfigJSON
        self.themeRaw = theme.rawValue
        self.hijriCalendarOffsetDays = hijriCalendarOffsetDays
        self.arabicNumeralsEnabled = arabicNumeralsEnabled
        self.weekStartsOnSaturday = weekStartsOnSaturday
        self.showStreaksUI = showStreaksUI
        self.aiInsightsEnabled = aiInsightsEnabled
        self.autoSyncAudioMemos = autoSyncAudioMemos
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
}
