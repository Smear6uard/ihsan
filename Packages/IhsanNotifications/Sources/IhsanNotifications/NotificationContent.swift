import Foundation
import IhsanCore
@preconcurrency import UserNotifications

public enum NotificationContent {
    /// Public so the app can build a prayer notification identical to a
    /// scheduled one — the DEBUG sound probe fires through this exact
    /// path rather than a parallel one, which is the only way the probe
    /// proves anything about the real schedule.
    public static func makeAdhanContent(
        prayer: Prayer,
        scheduledDate: Date,
        timeZone: TimeZone,
        soundChoice: AdhanSoundCatalog,
        isTimeSensitive: Bool,
        soundFileResolver: AdhanSoundFileResolver = .mainBundle
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = prayer.displayNameEnglish
        content.subtitle = prayer.displayNameArabic
        content.body = localizedTimeString(for: scheduledDate, timeZone: timeZone)

        let soundFileName = soundChoice.resolvedFileName(using: soundFileResolver)
        if let soundFileName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFileName))
        } else {
            // Silence is a real choice here, not a failure: the banner
            // still arrives. Falling back to the system tri-tone would
            // override the one thing the person asked for.
            content.sound = nil
        }

        // Time-sensitive breaks through Focus. It stays off unless a
        // person asked for it on this prayer — an app that decides on
        // its own that it may interrupt you has stopped being quiet.
        content.interruptionLevel = isTimeSensitive ? .timeSensitive : .active

        var userInfo: [AnyHashable: Any] = [
            ScheduledNotificationUserInfoKey.prayer: prayer.rawValue,
            ScheduledNotificationUserInfoKey.scheduledDate: scheduledDate,
            ScheduledNotificationUserInfoKey.soundChoice: soundChoice.rawValue
        ]
        if let soundFileName {
            userInfo[ScheduledNotificationUserInfoKey.soundFileName] = soundFileName
        }
        content.userInfo = userInfo
        content.categoryIdentifier = NotificationCategory.prayer

        return content
    }

    /// A quiet window-opening reminder. It carries no sound and never
    /// becomes time-sensitive: the person opted into a useful nudge,
    /// not a second adhān at the same prayer boundary.
    public static func makeAdhkarContent(
        category: AdhkarCategory,
        scheduledDate: Date,
        timeZone: TimeZone
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(category.displayName) adhkār"
        content.body = category == .morning
            ? "The morning remembrance window is open."
            : "The evening remembrance window is open."
        content.sound = nil
        content.interruptionLevel = .active
        content.userInfo = [
            ScheduledNotificationUserInfoKey.adhkarCategory: category.rawValue,
            ScheduledNotificationUserInfoKey.scheduledDate: scheduledDate,
            ScheduledNotificationUserInfoKey.timeZoneIdentifier: timeZone.identifier,
        ]
        content.categoryIdentifier = NotificationCategory.adhkar
        return content
    }

    /// The masjid's own name when it has one — a person recognises "Masjid
    /// al-Noor" faster than a generic word, and they chose that name.
    public static func iqamahTitle(masjidName: String?) -> String {
        guard let masjidName, !masjidName.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return "Iqamah"
        }
        return "Iqamah at \(masjidName)"
    }

    /// States the fact and stops. No urging, no exhortation — the person
    /// set this reminder and knows what it is for.
    public static func iqamahBody(
        prayer: Prayer,
        kind: IqamahKind,
        leadMinutes: Int
    ) -> String {
        let name = kind == .khutbah ? "Khutbah" : "\(prayer.displayNameEnglish) iqamah"
        if leadMinutes <= 0 {
            return "\(name) now."
        }
        let unit = leadMinutes == 1 ? "minute" : "minutes"
        return "\(name) in \(leadMinutes) \(unit)."
    }

    private static func localizedTimeString(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Notification categories, so a tapped prayer notification can offer
/// the full call rather than only opening the app.
public enum NotificationCategory {
    public static let prayer = "ihsan.prayer"
    public static let adhkar = "ihsan.adhkar"
    public static let playAdhanAction = "ihsan.play-adhan"
}

public enum ScheduledNotificationUserInfoKey {
    public static let prayer = "prayer"
    public static let scheduledDate = "scheduledDate"
    public static let soundFileName = "soundFileName"
    public static let soundChoice = "soundChoice"
    public static let adhkarCategory = "adhkarCategory"
    public static let timeZoneIdentifier = "timeZoneIdentifier"
}
