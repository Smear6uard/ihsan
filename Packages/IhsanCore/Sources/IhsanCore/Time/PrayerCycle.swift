import Foundation

/// Clock 1 — the prayer cycle, and the only day boundary tracking uses.
///
/// A prayer belongs to the date its WINDOW OPENED, not the date the
/// wall clock happened to read when it was offered. Isha's window runs
/// past midnight, so an Isha prayed at 1 AM belongs to the evening
/// before it; under a midnight boundary that prayer landed on the next
/// day's row, where its own window had not opened yet, and was scored
/// against a schedule it never belonged to.
///
/// So the tracker's day is the cycle **Fajr → next Fajr**, keyed by the
/// Gregorian date its Fajr opened on. The tracker rolls at Fajr. Before
/// Fajr the current cycle is still yesterday evening's — which is what
/// the prayer-state resolver has always said, treating Isha as current
/// until its window ends. The attribution now agrees with it.
///
/// Midnight is not a boundary anywhere in this file, and should not be
/// one anywhere that keys worship to a day.
public struct PrayerCycle: Sendable, Hashable {

    /// Start of the Gregorian day this cycle's Fajr opened on. This is
    /// the key every record and every column is stored and looked up
    /// under.
    public let date: Date

    /// The next Fajr — the instant this cycle gives way to the next,
    /// and the only moment at which a tracking surface rolls over.
    public let rollsAt: Date

    public init(date: Date, rollsAt: Date) {
        self.date = date
        self.rollsAt = rollsAt
    }

    /// The cycle before this one.
    public func previousDate(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }
}

/// The cycle arithmetic, kept here in `IhsanCore` rather than beside the
/// schedule so it is testable without prayer times — and, more to the
/// point, without coordinates. Callers hand in the two Fajr instants
/// that bracket the question; nothing in this type knows where anyone
/// is.
public enum PrayerCycleClock {

    /// The cycle containing `instant`.
    ///
    /// - Parameters:
    ///   - instant: the moment being attributed.
    ///   - civilDayFajr: Fajr of the civil day that contains `instant`.
    ///   - nextDayFajr: Fajr of the following civil day.
    ///
    /// The whole rule is the first comparison: at or after the civil
    /// day's Fajr the cycle is that day's; before it, the cycle is still
    /// the previous day's and rolls at the Fajr just ahead.
    public static func cycle(
        at instant: Date,
        civilDayFajr: Date,
        nextDayFajr: Date,
        calendar: Calendar = .current
    ) -> PrayerCycle {
        // The date is derived from `civilDayFajr`, never from
        // `instant`'s own start-of-day: one calendar operation, so a
        // daylight-saving shift or a post-midnight instant cannot pull
        // the key and the boundary apart.
        let civilDayStart = calendar.startOfDay(for: civilDayFajr)
        guard instant < civilDayFajr else {
            return PrayerCycle(date: civilDayStart, rollsAt: nextDayFajr)
        }
        let previous = calendar.date(byAdding: .day, value: -1, to: civilDayStart)
            ?? civilDayStart
        return PrayerCycle(date: previous, rollsAt: civilDayFajr)
    }

    /// Just the key, for callers that only need to know which row an
    /// instant belongs to.
    public static func cycleDate(
        at instant: Date,
        civilDayFajr: Date,
        calendar: Calendar = .current
    ) -> Date {
        cycle(
            at: instant,
            civilDayFajr: civilDayFajr,
            // Unused by the key; the cycle's own boundary is the only
            // thing it changes.
            nextDayFajr: civilDayFajr,
            calendar: calendar
        ).date
    }
}
