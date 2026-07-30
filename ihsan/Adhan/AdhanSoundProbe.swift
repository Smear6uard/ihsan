#if DEBUG
import Foundation
import IhsanCore
import IhsanNotifications
import UserNotifications

/// The timed device check for the sound pipeline.
///
/// A notification whose tone iOS rejects — missing file, wrong format,
/// over thirty seconds — still arrives. It just arrives silent, with
/// nothing in the log to say so. This schedules one real notification
/// per sound choice a few seconds out, built by the same content
/// builder the real schedule uses, so a test can watch them land and
/// read back the sound each one actually carries.
///
/// DEBUG only. Nothing here compiles into a release build.
enum AdhanSoundProbe {
    static let identifierPrefix = "ihsan.debug.sound-probe."

    /// Seconds between probes, so each banner is distinguishable on
    /// screen and in the delivered list.
    private static let spacing: TimeInterval = 3

    static func fire(names: [String]) async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        // Clear any probe left by an earlier run so a test never reads
        // a stale delivery as a fresh one.
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.map(\.request.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
        )

        for (index, name) in names.enumerated() {
            let choice = AdhanSoundCatalog(userChoice: name)
            let content = NotificationContent.makeAdhanContent(
                prayer: choice == .chimeDawn ? .fajr : .dhuhr,
                scheduledDate: Date(),
                timeZone: .current,
                soundChoice: choice,
                isTimeSensitive: false,
                soundFileResolver: .mainBundle
            )
            // The probe says which choice it is, so the test can assert
            // on the banner rather than on internal state.
            content.title = "Probe \(choice.rawValue)"
            content.body = content.userInfo[ScheduledNotificationUserInfoKey.soundFileName]
                as? String ?? "no sound"

            let request = UNNotificationRequest(
                identifier: identifierPrefix + choice.rawValue,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: spacing * Double(index + 1),
                    repeats: false
                )
            )
            try? await center.add(request)
        }
    }
}
#endif
