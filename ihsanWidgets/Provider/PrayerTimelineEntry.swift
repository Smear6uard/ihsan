import Foundation
import IhsanCore
import IhsanPrayerTimes
import WidgetKit

/// A single point on the widget timeline. Lightweight and Codable so
/// WidgetKit can serialize entries to disk between updates.
///
/// Each entry captures the snapshot of the world at `date`:
/// - which prayer is "next" relative to that moment
/// - what each of today's five prayers' logged status is (or absent if
///   not logged)
/// - location label and qibla bearing for compass-style indicators
/// - a flag distinguishing "no location yet" from "fully populated"
struct PrayerTimelineEntry: TimelineEntry, Codable, Sendable, Equatable {
    let date: Date

    /// The next upcoming prayer at `date`. May refer to tomorrow's Fajr
    /// when `date` falls after today's Isha.
    let nextPrayer: Prayer
    let nextPrayerScheduledTime: Date

    /// Today's five prayer scheduled times in chronological order. Used
    /// by the medium/large widgets to render the day's strip even for
    /// prayers that have already passed.
    let todayPrayerTimes: [PrayerSlot]

    /// Logged status per prayer for the civil day containing `date`.
    /// Absence means "no log written yet" (rendered as the inactive dot).
    /// String-keyed so the entry stays cleanly Codable.
    let loggedStatusByPrayerRaw: [String: String]

    let cityName: String
    let qiblaBearingDegrees: Double?

    /// `true` when location is unavailable (App Group cache empty). The
    /// widget shows a placeholder state instead of fake prayer times.
    let isLocationMissing: Bool

    struct PrayerSlot: Codable, Sendable, Equatable, Identifiable {
        let prayer: Prayer
        let scheduledTime: Date

        var id: String { prayer.rawValue }
    }

    func loggedStatus(for prayer: Prayer) -> PrayerStatus? {
        guard let raw = loggedStatusByPrayerRaw[prayer.rawValue] else {
            return nil
        }
        return PrayerStatus(rawValue: raw)
    }

    /// Convenience: which prayer (if any) is currently "active" (we are
    /// past its scheduled time but before the next one).
    var activePrayer: Prayer? {
        todayPrayerTimes
            .filter { $0.scheduledTime <= date }
            .last?
            .prayer
    }

    var secondsUntilNextPrayer: TimeInterval {
        max(0, nextPrayerScheduledTime.timeIntervalSince(date))
    }

    /// Number of prayers logged today with a non-missed status.
    var loggedCountToday: Int {
        Prayer.allCases.reduce(into: 0) { count, prayer in
            if let status = loggedStatus(for: prayer), status != .missed {
                count += 1
            }
        }
    }
}

extension PrayerTimelineEntry {
    /// A frozen-in-time placeholder used in the widget gallery and for
    /// `placeholder()` returns where no real data is available.
    static func placeholder(at date: Date = .now) -> PrayerTimelineEntry {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        // Stylized 5:12am / 1:04pm / 4:32pm / 7:18pm / 8:47pm progression so
        // the placeholder reads as a believable day even before the user's
        // real location resolves.
        let offsets: [(Prayer, Int)] = [
            (.fajr, 5 * 3600 + 12 * 60),
            (.dhuhr, 13 * 3600 + 4 * 60),
            (.asr, 16 * 3600 + 32 * 60),
            (.maghrib, 19 * 3600 + 18 * 60),
            (.isha, 20 * 3600 + 47 * 60)
        ]
        let slots: [PrayerSlot] = offsets.map { prayer, offset in
            PrayerSlot(
                prayer: prayer,
                scheduledTime: startOfDay.addingTimeInterval(TimeInterval(offset))
            )
        }
        let next: PrayerSlot = slots.first(where: { $0.scheduledTime > date })
            ?? PrayerSlot(
                prayer: .fajr,
                scheduledTime: calendar.date(byAdding: .day, value: 1, to: slots[0].scheduledTime) ?? slots[0].scheduledTime
            )

        return PrayerTimelineEntry(
            date: date,
            nextPrayer: next.prayer,
            nextPrayerScheduledTime: next.scheduledTime,
            todayPrayerTimes: slots,
            loggedStatusByPrayerRaw: [
                Prayer.fajr.rawValue: PrayerStatus.onTime.rawValue,
                Prayer.dhuhr.rawValue: PrayerStatus.onTime.rawValue
            ],
            cityName: "Your City",
            qiblaBearingDegrees: 58,
            isLocationMissing: false
        )
    }
}
