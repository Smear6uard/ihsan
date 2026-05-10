import Foundation
import IhsanCore
@preconcurrency import UserNotifications

struct AdhanSoundFileResolver: Sendable {
    let fileExists: @Sendable (String) -> Bool

    static let mainBundle = AdhanSoundFileResolver { fileName in
        let url = URL(fileURLWithPath: fileName)
        let resourceName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        return Bundle.main.url(forResource: resourceName, withExtension: fileExtension) != nil
    }
}

enum NotificationContent {
    static func makeAdhanContent(
        prayer: Prayer,
        scheduledDate: Date,
        timeZone: TimeZone,
        soundChoice: AdhanSoundCatalog,
        soundFileResolver: AdhanSoundFileResolver = .mainBundle
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = prayer.displayNameEnglish
        content.subtitle = prayer.displayNameArabic
        content.body = localizedTimeString(for: scheduledDate, timeZone: timeZone)

        let soundFileName = soundChoice.fileName(for: prayer)
        if let soundFileName, soundFileResolver.fileExists(soundFileName) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFileName))
        } else {
            // Audio files are bundled by the main app target, not this package. If an
            // expected CAF file is absent at runtime, fall back to the system sound.
            content.sound = .default
        }

        var userInfo: [AnyHashable: Any] = [
            ScheduledNotificationUserInfoKey.prayer: prayer.rawValue,
            ScheduledNotificationUserInfoKey.scheduledDate: scheduledDate
        ]
        if let soundFileName {
            userInfo[ScheduledNotificationUserInfoKey.soundFileName] = soundFileName
        }
        content.userInfo = userInfo

        return content
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

enum ScheduledNotificationUserInfoKey {
    static let prayer = "prayer"
    static let scheduledDate = "scheduledDate"
    static let soundFileName = "soundFileName"
}
