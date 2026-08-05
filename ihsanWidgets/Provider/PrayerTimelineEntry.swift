import Foundation
import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import WidgetKit

/// A single point on the widget timeline.
///
/// An entry is either the day, resolved — or an invitation to open the
/// app. There is no third shape: the old model carried a stylized fake
/// schedule behind an `isLocationMissing` flag, and any face that
/// forgot to check the flag rendered fiction as fact. Structurally
/// impossible now — a face must switch on `content`, and only `.live`
/// carries times at all.
struct PrayerTimelineEntry: TimelineEntry, Sendable, Equatable {
    let date: Date
    let content: Content
    /// Set by the configurable provider when the user pinned the
    /// small widget to one prayer; nil follows the day.
    var fixedPrayer: Prayer? = nil
    /// The inline accessory's configured form.
    var inlineShowsCountdown: Bool = false

    enum Content: Sendable, Equatable {
        case live(LiveDay)
        case invitation(Invitation)
    }

    /// The world at `date`, resolved from the published snapshot by
    /// the one shared resolver. Nothing here was computed in this
    /// process.
    struct LiveDay: Sendable, Equatable {
        let nextPrayer: Prayer
        let nextPrayerTime: Date
        let currentPrayer: Prayer?
        /// The open prayer window at `date`, for gauges.
        let currentWindow: ClosedRange<Date>?
        /// Today's five prayers in order, with their logged states.
        let slots: [PrayerSlot]
        let sunrise: Date
        let cityName: String?
        let timeZoneIdentifier: String
        let qiblaBearingDegrees: Double?
        /// The night containing `date`, when it is night at all.
        let night: WidgetSnapshot.NightTable?
        let hijri: WidgetSnapshot.HijriStamp?
        let fasting: WidgetSnapshot.FastingStamp?
        /// During an excused pause a widget shows times and carries no
        /// logging surface of any kind.
        let isPaused: Bool
        let qadaRemaining: Int?
        /// The next occurrence of each prayer at or after `date`,
        /// resolved across both snapshot days — the fixed-prayer
        /// widget configuration reads this instead of re-deriving.
        let nextOccurrenceByPrayerRaw: [String: Date]

        struct PrayerSlot: Sendable, Equatable, Identifiable {
            let prayer: Prayer
            let scheduledTime: Date
            let status: PrayerStatus?
            let withJamaah: Bool

            var id: String { prayer.rawValue }
        }

        func slot(for prayer: Prayer) -> PrayerSlot? {
            slots.first { $0.prayer == prayer }
        }

        /// Marker state at this entry's instant, in the plate's
        /// four-state ornament language.
        func markerState(for slot: PrayerSlot, at date: Date) -> PrayerMarkerState {
            if currentPrayer == slot.prayer { return .current }
            if let status = slot.status, status != .missed { return .logged }
            return slot.scheduledTime <= date ? .passedUnlogged : .upcoming
        }

        /// Wall-clock text in the place's timezone — never the
        /// device's.
        func clockTime(_ date: Date) -> String {
            WidgetCountdown.clockTime(
                date,
                timeZone: TimeZone(identifier: timeZoneIdentifier)
            )
        }
    }

    /// The dignified fallback. It names what would help ("Open Ihsan")
    /// and never shows a time it does not have.
    struct Invitation: Sendable, Equatable {
        enum Reason: Sendable, Equatable {
            /// No snapshot has ever been published — first run, or a
            /// reinstall that has not opened the app yet.
            case neverPublished
            /// A snapshot exists but its truth has run out.
            case stale
        }

        let reason: Reason

        var title: String { "Open Ihsan" }
        var line: String {
            switch reason {
            case .neverPublished: "for today's prayer times"
            case .stale: "to refresh today's times"
            }
        }
    }

    var liveDay: LiveDay? {
        if case .live(let day) = content { return day }
        return nil
    }

    /// The clamped interval for the countdown to the next prayer —
    /// the only form a face may hand to `Text(timerInterval:)`.
    var nextPrayerCountdown: ClosedRange<Date>? {
        guard let day = liveDay else { return nil }
        return WidgetTimerInterval.countdown(from: date, to: day.nextPrayerTime)
    }
}
