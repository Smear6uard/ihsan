import Foundation
import IhsanCore
import IhsanPrayerTimes

/// THE app-side statement of each prayer's window end — the log
/// sheet, the focused card, and any future surface read this one
/// rule, and `PrayerWindowSemanticsTests` pins it to agree with
/// `PrayerScheduleWindow.moment(at:)` at every instant of the day.
/// If either side ever changes alone, a test fails.
///
/// Fajr ends at sunrise; Dhuhr at Asr; Asr at Maghrib; Maghrib at
/// Isha; Isha at tomorrow's true Fajr. One Asr instant exists — the
/// user's madhab setting decides it once, in the calculation layer.
enum PrayerWindowRule {
    static func windowEnd(for prayer: Prayer, in window: PrayerScheduleWindow) -> Date {
        switch prayer {
        case .fajr: window.day.sunrise
        case .dhuhr: window.day.asr.scheduledTime
        case .asr: window.day.maghrib.scheduledTime
        case .maghrib: window.day.isha.scheduledTime
        case .isha: window.tomorrowFajr.scheduledTime
        }
    }
}
