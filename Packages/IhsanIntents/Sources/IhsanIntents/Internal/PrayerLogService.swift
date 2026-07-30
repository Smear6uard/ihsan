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
    /// `prayerDate` names the civil day being logged — nil means
    /// today. Retroactive entries (a passed day repaired from the
    /// Path ledger) pass the day explicitly; dedup then holds per
    /// (prayer, that day).
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
        let prayerDate = Calendar.current.startOfDay(for: explicitPrayerDate ?? now)
        let dedupKey = Self.makeDedupKey(prayer: prayer, prayerDate: prayerDate)

        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )
        let existing = try context.fetch(descriptor).first

        let scheduledTime: Date
        if let coordinates {
            do {
                let dayTimes = try prayerTimesProvider.dayTimes(
                    for: explicitPrayerDate ?? now,
                    coordinates: coordinates,
                    timeZone: timeZone,
                    calculationMethod: calculationConfiguration.0,
                    madhab: calculationConfiguration.1,
                    highLatitudeRule: calculationConfiguration.2,
                    tuning: calculationConfiguration.3
                )
                scheduledTime = try dayTimes.scheduledTime(for: prayer)
            } catch {
                throw IntentError.prayerTimesCalculationFailed(underlying: String(describing: error))
            }
        } else {
            // MARK: TODO
            // v1 placeholder: the application-layer coordinator that owns
            // CoreLocation should pass coordinates so this can save real
            // scheduled prayer times before shipping. Retroactive
            // entries stamp the day itself — coordinates for a past
            // day are gone by design (transient, never stored).
            scheduledTime = explicitPrayerDate.map { Calendar.current.startOfDay(for: $0) } ?? now
        }

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

    /// Toggles the jama'ah flag on the given day's log for the given
    /// prayer (today when `prayerDate` is nil). Creates an on-time
    /// log when no log exists yet.
    @MainActor
    func toggleJamaah(
        for prayer: Prayer,
        prayerDate explicitPrayerDate: Date? = nil,
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> PrayerLog {
        let now = clock.now()
        let prayerDate = Calendar.current.startOfDay(for: explicitPrayerDate ?? now)
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
            prayerDate: Calendar.current.startOfDay(for: now),
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
