import Foundation
import IhsanCore
import IhsanPrayerTimes
import SwiftData

internal struct PrayerLogService: Sendable {
    let prayerTimesProvider: any PrayerTimesProviding
    /// The clock every timestamp in this service derives from. The
    /// default is the process's one clock (`NowProvider.active`), so
    /// a debug now-override moves commit stamps together with the UI
    /// clock — a logged timestamp can never run ahead of the time the
    /// Today surface displays. Tests inject a fixed override.
    let clock: NowProvider

    init(
        prayerTimesProvider: any PrayerTimesProviding = AdhanPrayerTimesProvider(),
        clock: NowProvider = .active
    ) {
        self.prayerTimesProvider = prayerTimesProvider
        self.clock = clock
    }

    /// Logs a prayer with the given status. Existing logs for the same
    /// (prayer, prayerDate) tuple are updated in place rather than duplicated.
    ///
    /// `prayerDate` names the PRAYER CYCLE being logged — nil means the
    /// cycle in progress. A cycle runs Fajr → next Fajr and is keyed by
    /// the Gregorian date its Fajr opened on, so an Isha offered at
    /// 1 AM lands on the evening it belongs to rather than on a day
    /// whose own Isha has not been called yet. Retroactive entries (a
    /// passed day repaired from the Path ledger) pass their cycle
    /// explicitly; dedup then holds per (prayer, that cycle).
    @MainActor
    func logPrayer(
        _ prayer: Prayer,
        status: PrayerStatus,
        withJamaah: Bool? = nil,
        prayedAt: Date? = nil,
        prayerDate explicitPrayerDate: Date? = nil,
        coordinates: Coordinates? = nil,
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> PrayerLog {
        let settings = try UserSettings.fetchOrCreate(in: context)
        let calculationConfiguration = (
            settings.calculationMethod,
            settings.madhab,
            settings.highLatitudeRule,
            settings.calculationTuning
        )

        let timeZone = TimeZone.current
        let now = clock.now()
        let attribution = try cycleAttribution(
            prayer: prayer,
            explicitPrayerDate: explicitPrayerDate,
            now: now,
            coordinates: coordinates,
            timeZone: timeZone,
            configuration: calculationConfiguration
        )
        let prayerDate = attribution.cycleDate
        let scheduledTime = attribution.scheduledTime
        let dedupKey = Self.makeDedupKey(prayer: prayer, prayerDate: prayerDate)

        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )
        let existing = try context.fetch(descriptor).first

        let lateBySeconds: Int? = {
            guard status == .late, let prayedAt else {
                return nil
            }

            let delta = Int(prayedAt.timeIntervalSince(scheduledTime))
            return max(0, delta)
        }()

        if let existing {
            existing.statusRaw = status.rawValue
            existing.prayedAt = prayedAt
            existing.lateBySeconds = lateBySeconds
            if let withJamaah {
                existing.withJamaah = withJamaah
            }
            existing.sourceSurface = sourceSurface.rawValue
            existing.modifiedAt = now
            // Integrity guard: a re-commit can only move the stamp
            // backward to the clock, never leave one in the future
            // (e.g. a record created before a clock correction).
            existing.loggedAt = min(existing.loggedAt, now)
            try context.save()
            return existing
        }

        let log = PrayerLog(
            prayer: prayer,
            prayerDate: prayerDate,
            loggedTimeZoneIdentifier: timeZone.identifier,
            scheduledTime: scheduledTime,
            prayedAt: prayedAt,
            loggedAt: now,
            status: status,
            lateBySeconds: lateBySeconds,
            withJamaah: withJamaah ?? false,
            sourceSurface: sourceSurface,
            createdAt: now,
            modifiedAt: now
        )
        context.insert(log)
        try context.save()
        return log
    }

    // MARK: - Attribution (clock 1)

    /// Which cycle a log belongs to, and the start of the window it is
    /// measured against.
    private struct CycleAttribution {
        let cycleDate: Date
        let scheduledTime: Date
    }

    /// Resolve the cycle and the prayer's own scheduled instant inside
    /// it, from the best schedule on hand.
    ///
    /// Three sources, in descending exactness:
    ///
    /// 1. **An explicit day** — a retroactive entry from Path. The day
    ///    IS the cycle key, and the prayer's schedule comes from that
    ///    day's table.
    /// 2. **Coordinates** — a live log with a place. The bracketed
    ///    window answers both questions at once, and before dawn it
    ///    answers them with YESTERDAY's table, which is the whole
    ///    point: a 1 AM Isha is measured against the Isha that is
    ///    still open, not against one twenty hours away.
    /// 3. **The App Group schedule cache** — a live log without a
    ///    place, which is most of them: the intent funnel carries no
    ///    coordinates. The cache holds a cycle's own boundaries, so it
    ///    is exact for the cycle it covers.
    ///
    /// Below all three sits the civil day. It is reached only before a
    /// device has ever resolved a schedule; `lateBySeconds` stays nil
    /// there, because a lateness measured against a start time we do
    /// not know would be a fabricated number.
    ///
    /// Coordinates are used and discarded — never written. That is why
    /// source 3 exists at all: the privacy invariant on `LocatedPlace`
    /// means a past log's place is not recoverable, so the schedule has
    /// to travel as derived boundaries or not at all.
    @MainActor
    private func cycleAttribution(
        prayer: Prayer,
        explicitPrayerDate: Date?,
        now: Date,
        coordinates: Coordinates?,
        timeZone: TimeZone,
        configuration: (
            CalculationMethodChoice, MadhabChoice, HighLatitudeRule, CalculationTuning
        )
    ) throws -> CycleAttribution {
        let calendar = Calendar.current

        if let explicitPrayerDate {
            let cycleDate = calendar.startOfDay(for: explicitPrayerDate)
            guard let coordinates else {
                return CycleAttribution(cycleDate: cycleDate, scheduledTime: cycleDate)
            }
            do {
                let dayTimes = try prayerTimesProvider.dayTimes(
                    for: explicitPrayerDate,
                    coordinates: coordinates,
                    timeZone: timeZone,
                    calculationMethod: configuration.0,
                    madhab: configuration.1,
                    highLatitudeRule: configuration.2,
                    tuning: configuration.3
                )
                return CycleAttribution(
                    cycleDate: cycleDate,
                    scheduledTime: try dayTimes.scheduledTime(for: prayer)
                )
            } catch {
                throw IntentError.prayerTimesCalculationFailed(underlying: String(describing: error))
            }
        }

        if let coordinates {
            do {
                let window = try prayerTimesProvider.scheduleWindow(
                    for: now,
                    coordinates: coordinates,
                    timeZone: timeZone,
                    calculationMethod: configuration.0,
                    madhab: configuration.1,
                    highLatitudeRule: configuration.2,
                    tuning: configuration.3
                )
                return CycleAttribution(
                    cycleDate: window.cycle(at: now).date,
                    scheduledTime: window.scheduledTime(of: prayer, inCycleAt: now)
                )
            } catch {
                throw IntentError.prayerTimesCalculationFailed(underlying: String(describing: error))
            }
        }

        if let cache = PrayerTimesCacheStore.read(),
           let cycle = cache.cycle(at: now),
           let scheduledTime = cache.scheduledTime(for: prayer, at: now) {
            return CycleAttribution(cycleDate: cycle.date, scheduledTime: scheduledTime)
        }

        return CycleAttribution(
            cycleDate: calendar.startOfDay(for: now),
            scheduledTime: now
        )
    }

    /// Toggles the jama'ah flag on the given cycle's log for the given
    /// prayer (the cycle in progress when `prayerDate` is nil). Creates
    /// an on-time log when no log exists yet.
    @MainActor
    func toggleJamaah(
        for prayer: Prayer,
        prayerDate explicitPrayerDate: Date? = nil,
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> PrayerLog {
        let now = clock.now()
        let prayerDate = explicitPrayerDate.map { Calendar.current.startOfDay(for: $0) }
            ?? PrayerCycleClock.sharedCycleDate(at: now)
        let dedupKey = Self.makeDedupKey(prayer: prayer, prayerDate: prayerDate)
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.withJamaah.toggle()
            existing.sourceSurface = sourceSurface.rawValue
            existing.modifiedAt = now
            try context.save()
            return existing
        }

        return try logPrayer(
            prayer,
            status: .onTime,
            withJamaah: true,
            prayerDate: explicitPrayerDate,
            sourceSurface: sourceSurface,
            in: context
        )
    }

    /// Marks a previously missed prayer as qada while preserving the original log.
    @MainActor
    func markAsQada(
        originalLogID: UUID,
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> PrayerLog {
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.id == originalLogID }
        )

        guard let original = try context.fetch(descriptor).first,
              let originalPrayer = original.prayer
        else {
            throw IntentError.invalidPrayer(originalLogID.uuidString)
        }

        let now = clock.now()
        let qadaLog = PrayerLog(
            prayer: originalPrayer,
            // The cycle the makeup was performed in, not the civil day
            // it happened to fall on: a witr-hour qadā belongs to the
            // evening it was offered in.
            prayerDate: PrayerCycleClock.sharedCycleDate(at: now),
            loggedTimeZoneIdentifier: TimeZone.current.identifier,
            scheduledTime: now,
            prayedAt: now,
            loggedAt: now,
            status: .qada,
            withJamaah: false,
            qadaForPrayerLogID: originalLogID,
            sourceSurface: sourceSurface,
            createdAt: now,
            modifiedAt: now
        )

        context.insert(qadaLog)
        try context.save()
        return qadaLog
    }

    static func makeDedupKey(prayer: Prayer, prayerDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(prayer.rawValue)-\(formatter.string(from: prayerDate))"
    }
}

private extension DayPrayerTimes {
    func scheduledTime(for prayer: Prayer) throws -> Date {
        guard let prayerTime = allFardh.first(where: { $0.prayer == prayer }) else {
            throw IntentError.invalidPrayer(prayer.rawValue)
        }

        return prayerTime.scheduledTime
    }
}
