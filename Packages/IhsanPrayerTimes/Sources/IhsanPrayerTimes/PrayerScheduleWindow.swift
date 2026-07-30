import Foundation
import IhsanCore

/// The temporal state of one exact prayer instance.
///
/// These are the only three states a UI may render. Boundaries are
/// deliberately unadjusted and half-open: `[start, end)`. Scheduling
/// concerns such as notification preferences and Live Activity lead
/// time never enter this type or the resolver below.
public enum PrayerWindowState: Sendable, Hashable {
    case upcoming(opensAt: Date)
    case current(startedAt: Date, endsAt: Date)
    case closed(startedAt: Date, endedAt: Date)

    public var windowEnd: Date? {
        switch self {
        case .upcoming:
            nil
        case .current(_, let endsAt), .closed(_, let endsAt):
            endsAt
        }
    }

    public var isCurrent: Bool {
        if case .current = self { return true }
        return false
    }
}

/// One prayer instance together with the state resolved for it.
public struct ResolvedPrayerWindow: Sendable, Hashable {
    public let prayerTime: PrayerTime
    public let state: PrayerWindowState

    public init(prayerTime: PrayerTime, state: PrayerWindowState) {
        self.prayerTime = prayerTime
        self.state = state
    }
}

/// The complete answer every app surface consumes for one instant.
///
/// `currentPrayer`, `nextPrayer`, and `windowState` are resolved in one
/// pass. `prayerWindows` carries the same answer for marker/card/sheet
/// rendering, preventing those surfaces from re-comparing boundaries.
public struct PrayerResolution: Sendable, Hashable {
    public let currentPrayer: PrayerTime?
    public let nextPrayer: PrayerTime
    /// State of the current prayer, or of `nextPrayer` when no prayer
    /// window is open (the sunrise-to-Dhuhr gap).
    public let windowState: PrayerWindowState
    public let prayerWindows: [ResolvedPrayerWindow]
    /// True only when `now` has reached this table's terminal boundary
    /// and the caller must fetch the next bracketed schedule.
    public let isScheduleExhausted: Bool

    public init(
        currentPrayer: PrayerTime?,
        nextPrayer: PrayerTime,
        windowState: PrayerWindowState,
        prayerWindows: [ResolvedPrayerWindow],
        isScheduleExhausted: Bool
    ) {
        self.currentPrayer = currentPrayer
        self.nextPrayer = nextPrayer
        self.windowState = windowState
        self.prayerWindows = prayerWindows
        self.isScheduleExhausted = isScheduleExhausted
    }

    /// The countdown target is always the next prayer's actual start.
    /// No timezone, lead-time, or notification arithmetic is involved.
    public var countdownTarget: Date {
        nextPrayer.scheduledTime
    }

    public var currentWindowEnd: Date? {
        guard case .current(_, let endsAt) = windowState else { return nil }
        return endsAt
    }

    /// State for an exact prayer instance. Callers pass the same
    /// `PrayerTime` they display, which also distinguishes today's Fajr
    /// from tomorrow's rolled Fajr.
    public func state(for prayerTime: PrayerTime) -> PrayerWindowState? {
        prayerWindows.first { $0.prayerTime == prayerTime }?.state
    }

    public func windowEnd(for prayerTime: PrayerTime) -> Date? {
        state(for: prayerTime)?.windowEnd
    }
}

/// The minimum immutable time table required by the resolver.
///
/// App views build this from `PrayerScheduleWindow`; widgets rebuild it
/// from the app-group schedule cache. Both therefore resolve the exact
/// same absolute instants without recomputing Adhan parameters.
public struct PrayerStateSchedule: Sendable, Hashable {
    public let yesterdayIsha: PrayerTime
    public let fajr: PrayerTime
    public let sunrise: Date
    public let dhuhr: PrayerTime
    public let asr: PrayerTime
    public let maghrib: PrayerTime
    public let isha: PrayerTime
    public let tomorrowFajr: PrayerTime
    public let timeZoneIdentifier: String

    public init(
        yesterdayIsha: PrayerTime,
        fajr: PrayerTime,
        sunrise: Date,
        dhuhr: PrayerTime,
        asr: PrayerTime,
        maghrib: PrayerTime,
        isha: PrayerTime,
        tomorrowFajr: PrayerTime,
        timeZoneIdentifier: String
    ) {
        self.yesterdayIsha = yesterdayIsha
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.tomorrowFajr = tomorrowFajr
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public init(_ window: PrayerScheduleWindow) {
        self.init(
            yesterdayIsha: window.yesterdayIsha,
            fajr: window.day.fajr,
            sunrise: window.day.sunrise,
            dhuhr: window.day.dhuhr,
            asr: window.day.asr,
            maghrib: window.day.maghrib,
            isha: window.day.isha,
            tomorrowFajr: window.tomorrowFajr,
            timeZoneIdentifier: window.day.timeZoneIdentifier
        )
    }

    public var dayPrayerTimes: [PrayerTime] {
        [fajr, dhuhr, asr, maghrib, isha]
    }

    /// Stable FNV-1a fingerprint for DEBUG diagnostics and cache
    /// divergence checks. Unlike Swift's `Hasher`, this is repeatable
    /// across processes (app, widgets, and watch extensions).
    public var tableHash: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func append(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        func append(_ value: Int64) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { bytes in
                bytes.forEach(append)
            }
        }

        for byte in timeZoneIdentifier.utf8 { append(byte) }
        let dates = [
            yesterdayIsha.scheduledTime, fajr.scheduledTime, sunrise,
            dhuhr.scheduledTime, asr.scheduledTime, maghrib.scheduledTime,
            isha.scheduledTime, tomorrowFajr.scheduledTime
        ]
        for date in dates {
            append(Int64((date.timeIntervalSince1970 * 1_000).rounded()))
        }
        return String(format: "%016llx", hash)
    }
}

/// The one prayer state machine for the app and all extensions.
///
/// This is a pure function of an immutable prayer-time table and `now`.
/// Every entry and exit uses the prayer's exact start/end; there is no
/// configurable tolerance and no pre-adhan lead.
public enum PrayerStateResolver {
    public static func resolve(
        prayerTimes: PrayerStateSchedule,
        now: Date
    ) -> PrayerResolution {
        let windows: [(PrayerTime, Date)] = [
            (prayerTimes.yesterdayIsha, prayerTimes.fajr.scheduledTime),
            (prayerTimes.fajr, prayerTimes.sunrise),
            (prayerTimes.dhuhr, prayerTimes.asr.scheduledTime),
            (prayerTimes.asr, prayerTimes.maghrib.scheduledTime),
            (prayerTimes.maghrib, prayerTimes.isha.scheduledTime),
            (prayerTimes.isha, prayerTimes.tomorrowFajr.scheduledTime)
        ]

        let resolvedWindows = windows.map { prayerTime, end in
            let state: PrayerWindowState
            if now < prayerTime.scheduledTime {
                state = .upcoming(opensAt: prayerTime.scheduledTime)
            } else if now < end {
                state = .current(startedAt: prayerTime.scheduledTime, endsAt: end)
            } else {
                state = .closed(startedAt: prayerTime.scheduledTime, endedAt: end)
            }
            return ResolvedPrayerWindow(prayerTime: prayerTime, state: state)
        }

        let current = resolvedWindows.first { $0.state.isCurrent }?.prayerTime
        let next = (prayerTimes.dayPrayerTimes + [prayerTimes.tomorrowFajr])
            .first { $0.scheduledTime > now }
            // A schedule is consumed only before tomorrow Fajr. The
            // fallback keeps resolution total if an extension briefly
            // renders a stale entry while requesting its replacement.
            ?? prayerTimes.tomorrowFajr

        var allStates = resolvedWindows
        allStates.append(ResolvedPrayerWindow(
            prayerTime: prayerTimes.tomorrowFajr,
            state: .upcoming(opensAt: prayerTimes.tomorrowFajr.scheduledTime)
        ))

        let state: PrayerWindowState
        if let current,
           let currentState = allStates.first(where: { $0.prayerTime == current })?.state {
            state = currentState
        } else {
            state = .upcoming(opensAt: next.scheduledTime)
        }

        return PrayerResolution(
            currentPrayer: current,
            nextPrayer: next,
            windowState: state,
            prayerWindows: allStates,
            isScheduleExhausted: now >= prayerTimes.tomorrowFajr.scheduledTime
        )
    }
}

/// DEBUG-only proof line for comparing consumers. The resolver remains
/// pure; surfaces call this after consuming its result.
public enum PrayerResolverDiagnostics {
    public static func emit(
        prayerTimes: PrayerStateSchedule,
        now: Date,
        resolution: PrayerResolution,
        surface: String
    ) {
        #if DEBUG
        if let current = resolution.currentPrayer {
            assert(current.scheduledTime <= now, "Resolver made a prayer current before its start")
            assert(resolution.currentWindowEnd.map { now < $0 } == true,
                   "Resolver retained a prayer at or after its window end")
        }
        assert(
            resolution.nextPrayer.scheduledTime > now
                || now >= prayerTimes.tomorrowFajr.scheduledTime,
            "Resolver next prayer is not strictly in the future"
        )
        let current = resolution.currentPrayer?.prayer.rawValue ?? "none"
        let next = resolution.nextPrayer.prayer.rawValue
        print(
            "[PrayerStateResolver] surface=\(surface) table=\(prayerTimes.tableHash) "
                + "now=\(now.ISO8601Format()) current=\(current) next=\(next) "
                + "state=\(String(describing: resolution.windowState))"
        )
        #else
        _ = prayerTimes
        _ = now
        _ = resolution
        _ = surface
        #endif
    }
}

/// Three consecutive days' worth of schedule — enough to resolve any
/// instant of the middle day, including yesterday's Isha before dawn
/// and tomorrow's Fajr after Isha.
public struct PrayerScheduleWindow: Sendable, Equatable {
    public let yesterdayIsha: PrayerTime
    public let day: DayPrayerTimes
    public let tomorrowFajr: PrayerTime

    public init(yesterdayIsha: PrayerTime, day: DayPrayerTimes, tomorrowFajr: PrayerTime) {
        self.yesterdayIsha = yesterdayIsha
        self.day = day
        self.tomorrowFajr = tomorrowFajr
    }

    public var resolverSchedule: PrayerStateSchedule {
        PrayerStateSchedule(self)
    }
}

public extension PrayerTimesProviding {
    /// Build the three-day resolution window that brackets `date`.
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
