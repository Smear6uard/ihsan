import Foundation
import IhsanCore

/// The resolved prayer state at one instant.
///
/// Invariant: `current` and `currentWindowEnd` are either both present
/// or both nil, `current`'s window always contains the queried instant
/// (`scheduledTime <= now < currentWindowEnd`), and `next` is always
/// strictly in the future. The countdown target — window end while a
/// window is open, next start otherwise — is therefore strictly future
/// at every instant, including exact boundaries.
public struct PrayerMoment: Sendable, Equatable {
    /// The prayer whose fiqh window contains the instant. Nil only in
    /// the forenoon gap [sunrise, dhuhr) — and, degenerately, before
    /// yesterday's Isha at the extreme edge of the window's span.
    public let current: PrayerTime?
    /// The next fardh strictly after the instant; rolls into
    /// tomorrow's Fajr once Isha has begun.
    public let next: PrayerTime
    /// End of `current`'s window: sunrise for Fajr, the next prayer's
    /// start otherwise, tomorrow's Fajr for Isha.
    public let currentWindowEnd: Date?

    /// What a countdown should run toward at this instant: the open
    /// window's end, or the next window's opening. Strictly future.
    public var countdownTarget: Date {
        currentWindowEnd ?? next.scheduledTime
    }
}

/// Three consecutive days' worth of schedule — just enough to resolve
/// the prayer state at any instant of the middle day, including the
/// pre-dawn tail of yesterday's Isha window and the post-Isha rollover
/// into tomorrow's Fajr.
///
/// Pure data + pure resolution: the UI computes this once per
/// snapshot refresh and then queries `moment(at:)` on every clock
/// tick without touching the calculation layer.
public struct PrayerScheduleWindow: Sendable, Equatable {
    public let yesterdayIsha: PrayerTime
    public let day: DayPrayerTimes
    public let tomorrowFajr: PrayerTime

    public init(yesterdayIsha: PrayerTime, day: DayPrayerTimes, tomorrowFajr: PrayerTime) {
        self.yesterdayIsha = yesterdayIsha
        self.day = day
        self.tomorrowFajr = tomorrowFajr
    }

    /// Resolve the prayer state at an instant. All comparisons are
    /// half-open `[start, end)` so a boundary instant belongs to the
    /// state that begins there — the transition is atomic.
    public func moment(at now: Date) -> PrayerMoment {
        if now < day.fajr.scheduledTime {
            // Pre-dawn: yesterday's Isha window runs until today's Fajr.
            let inIshaWindow = now >= yesterdayIsha.scheduledTime
            return PrayerMoment(
                current: inIshaWindow ? yesterdayIsha : nil,
                next: day.fajr,
                currentWindowEnd: inIshaWindow ? day.fajr.scheduledTime : nil
            )
        }
        if now < day.sunrise {
            return PrayerMoment(
                current: day.fajr,
                next: day.dhuhr,
                currentWindowEnd: day.sunrise
            )
        }
        if now < day.dhuhr.scheduledTime {
            // The forenoon gap — no window is open.
            return PrayerMoment(current: nil, next: day.dhuhr, currentWindowEnd: nil)
        }
        if now < day.asr.scheduledTime {
            return PrayerMoment(
                current: day.dhuhr,
                next: day.asr,
                currentWindowEnd: day.asr.scheduledTime
            )
        }
        if now < day.maghrib.scheduledTime {
            return PrayerMoment(
                current: day.asr,
                next: day.maghrib,
                currentWindowEnd: day.maghrib.scheduledTime
            )
        }
        if now < day.isha.scheduledTime {
            return PrayerMoment(
                current: day.maghrib,
                next: day.isha,
                currentWindowEnd: day.isha.scheduledTime
            )
        }
        return PrayerMoment(
            current: day.isha,
            next: tomorrowFajr,
            currentWindowEnd: tomorrowFajr.scheduledTime
        )
    }
}

public extension PrayerTimesProviding {
    /// Build the three-day resolution window that brackets `date`.
    ///
    /// The window's valid span is `[yesterday's fajr, tomorrow's fajr)`
    /// and this builder guarantees `date` falls inside it — the civil
    /// day is only the starting guess, because a timezone far from the
    /// location's solar meridian can push a "day's" prayer times many
    /// hours away from that day's clock span. `moment(at:)` queried
    /// outside the span is a stale read; refresh the window instead.
    func scheduleWindow(
        for date: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        calculationMethod: CalculationMethodChoice,
        madhab: MadhabChoice,
        highLatitudeRule: HighLatitudeRule
    ) throws -> PrayerScheduleWindow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        func times(_ dayOffset: Int) throws -> DayPrayerTimes {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else {
                throw PrayerTimesError.invalidDate(
                    "Could not offset \(date) by \(dayOffset) day(s) in \(timeZone.identifier)."
                )
            }
            return try dayTimes(
                for: day,
                coordinates: coordinates,
                timeZone: timeZone,
                calculationMethod: calculationMethod,
                madhab: madhab,
                highLatitudeRule: highLatitudeRule
            )
        }

        // Walk the candidate day until [fajr, tomorrowFajr) brackets
        // the instant. Solar-vs-civil offsets are bounded by a day, so
        // a few steps always suffice; the guard is a safety net, not a
        // path the geometry can reach.
        var offset = 0
        for _ in 0..<4 {
            let day = try times(offset)
            let tomorrowFajr = try times(offset + 1).fajr
            if date >= tomorrowFajr.scheduledTime {
                offset += 1
                continue
            }
            let yesterday = try times(offset - 1)
            if date < yesterday.fajr.scheduledTime {
                offset -= 1
                continue
            }
            return PrayerScheduleWindow(
                yesterdayIsha: yesterday.isha,
                day: day,
                tomorrowFajr: tomorrowFajr
            )
        }
        throw PrayerTimesError.invalidDate(
            "Could not bracket \(date) with a prayer-schedule window in \(timeZone.identifier)."
        )
    }
}
