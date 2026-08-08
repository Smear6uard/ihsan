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

        return makeResolution(
            windows: windows,
            nextCandidates: prayerTimes.dayPrayerTimes + [prayerTimes.tomorrowFajr],
            terminalFajr: prayerTimes.tomorrowFajr,
            now: now
        )
    }

    /// Resolves the five prayers belonging to one exact Fajr-to-Fajr
    /// cycle. App surfaces use this overload after
    /// `PrayerScheduleWindow.cycleDayTimes(at:)` selects the cycle in
    /// progress. Unlike a civil-day bracket, it contains all five
    /// marker/card instances the person is looking at before dawn —
    /// including the previous evening's Maghrib and Isha.
    public static func resolve(
        cycleDay: DayPrayerTimes,
        nextFajr: PrayerTime,
        now: Date
    ) -> PrayerResolution {
        let windows: [(PrayerTime, Date)] = cycleDay.allFardh.map {
            ($0, cycleDay.windowEnd(for: $0.prayer, nextFajr: nextFajr.scheduledTime))
        }

        return makeResolution(
            windows: windows,
            nextCandidates: cycleDay.allFardh + [nextFajr],
            terminalFajr: nextFajr,
            now: now
        )
    }

    private static func makeResolution(
        windows: [(PrayerTime, Date)],
        nextCandidates: [PrayerTime],
        terminalFajr: PrayerTime,
        now: Date
    ) -> PrayerResolution {

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
        let next = nextCandidates
            .first { $0.scheduledTime > now }
            // A schedule is consumed only before tomorrow Fajr. The
            // fallback keeps resolution total if an extension briefly
            // renders a stale entry while requesting its replacement.
            ?? terminalFajr

        var allStates = resolvedWindows
        if !allStates.contains(where: { $0.prayerTime == terminalFajr }) {
            allStates.append(ResolvedPrayerWindow(
                prayerTime: terminalFajr,
                state: .upcoming(opensAt: terminalFajr.scheduledTime)
            ))
        }

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
            isScheduleExhausted: now >= terminalFajr.scheduledTime
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
///
/// Yesterday arrives whole rather than as its Isha alone. The builder
/// always computed the full table and threw the rest away; keeping it
/// is what lets a pre-dawn log of ANY prayer resolve against the
/// window it actually belongs to — the cycle before this one — instead
/// of against a window that has not opened yet.
public struct PrayerScheduleWindow: Sendable, Equatable {
    public let yesterday: DayPrayerTimes
    public let day: DayPrayerTimes
    public let tomorrowFajr: PrayerTime

    public init(yesterday: DayPrayerTimes, day: DayPrayerTimes, tomorrowFajr: PrayerTime) {
        self.yesterday = yesterday
        self.day = day
        self.tomorrowFajr = tomorrowFajr
    }

    /// The previous day's Isha — the window that owns the hours before
    /// dawn.
    public var yesterdayIsha: PrayerTime { yesterday.isha }

    public var resolverSchedule: PrayerStateSchedule {
        PrayerStateSchedule(self)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: day.timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    // MARK: - Clock 1

    /// The prayer cycle containing `instant` — the tracking day, which
    /// rolls at Fajr and knows nothing about midnight.
    public func cycle(at instant: Date) -> PrayerCycle {
        PrayerCycleClock.cycle(
            at: instant,
            civilDayFajr: day.fajr.scheduledTime,
            nextDayFajr: tomorrowFajr.scheduledTime,
            calendar: calendar
        )
    }

    /// The day table belonging to the cycle containing `instant`:
    /// before this civil day's Fajr, that is yesterday's table.
    public func cycleDayTimes(at instant: Date) -> DayPrayerTimes {
        instant < day.fajr.scheduledTime ? yesterday : day
    }

    /// The half-open window `[start, end)` of `prayer` inside the cycle
    /// containing `instant`. Isha's end is the Fajr that closes the
    /// cycle — which is where the midnight boundary was wrong.
    public func window(of prayer: Prayer, inCycleAt instant: Date) -> (start: Date, end: Date) {
        let table = cycleDayTimes(at: instant)
        let cycleEndFajr = instant < day.fajr.scheduledTime
            ? day.fajr.scheduledTime
            : tomorrowFajr.scheduledTime
        let start = table.time(for: prayer)
        let end = table.windowEnd(for: prayer, nextFajr: cycleEndFajr)
        return (start, end)
    }

    /// The scheduled instant of `prayer` inside the cycle containing
    /// `instant`.
    public func scheduledTime(of prayer: Prayer, inCycleAt instant: Date) -> Date {
        cycleDayTimes(at: instant).time(for: prayer)
    }

    // MARK: - Clock 2

    /// The Maghrib of the civil day containing `instant` — the instant
    /// clock 2 turns on — when this window covers that day.
    ///
    /// Matched by civil day rather than taken from `day`, because a
    /// screen left open across midnight holds a window whose `day` is
    /// no longer the one the clock is in. `nil` then, which tabulates
    /// civilly rather than turning the date on a sunset that already
    /// happened.
    public func maghribOfCivilDay(containing instant: Date) -> Date? {
        let calendar = calendar
        return [day, yesterday]
            .first { calendar.isDate($0.date, inSameDayAs: instant) }?
            .maghrib.scheduledTime
    }

    /// The evening boundaries this window can vouch for — yesterday,
    /// today, and (through tomorrow's Fajr only) nothing further. The
    /// app publishes these so every surface names the same Hijri date.
    public var eveningBoundaries: [HijriDisplay.EveningBoundary] {
        let calendar = calendar
        return [yesterday, day].map {
            HijriDisplay.EveningBoundary(
                civilDayStart: calendar.startOfDay(for: $0.date),
                maghrib: $0.maghrib.scheduledTime
            )
        }
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
        highLatitudeRule: HighLatitudeRule,
        tuning: CalculationTuning = .standard
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
                highLatitudeRule: highLatitudeRule,
                tuning: tuning
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
                yesterday: yesterday,
                day: day,
                tomorrowFajr: tomorrowFajr
            )
        }
        throw PrayerTimesError.invalidDate(
            "Could not bracket \(date) with a prayer-schedule window in \(timeZone.identifier)."
        )
    }
}
