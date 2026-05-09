import Foundation
import IhsanCore
import IhsanPrayerTimes
import SwiftData

internal struct PrayerLogService: Sendable {
    let prayerTimesProvider: any PrayerTimesProviding

    init(prayerTimesProvider: any PrayerTimesProviding = AdhanPrayerTimesProvider()) {
        self.prayerTimesProvider = prayerTimesProvider
    }

    /// Logs a prayer with the given status. Existing logs for the same
    /// (prayer, prayerDate) tuple are updated in place rather than duplicated.
    @MainActor
    func logPrayer(
        _ prayer: Prayer,
        status: PrayerStatus,
        withJamaah: Bool? = nil,
        prayedAt: Date? = nil,
        coordinates: Coordinates? = nil,
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> PrayerLog {
        let settings = try UserSettings.fetchOrCreate(in: context)
        let calculationConfiguration = (
            settings.calculationMethod,
            settings.madhab,
            settings.highLatitudeRule
        )

        let timeZone = TimeZone.current
        let now = Date.now
        let prayerDate = Calendar.current.startOfDay(for: now)
        let dedupKey = Self.makeDedupKey(prayer: prayer, prayerDate: prayerDate)

        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )
        let existing = try context.fetch(descriptor).first

        let scheduledTime: Date
        if let coordinates {
            do {
                let dayTimes = try prayerTimesProvider.dayTimes(
                    for: now,
                    coordinates: coordinates,
                    timeZone: timeZone,
                    calculationMethod: calculationConfiguration.0,
                    madhab: calculationConfiguration.1,
                    highLatitudeRule: calculationConfiguration.2
                )
                scheduledTime = try dayTimes.scheduledTime(for: prayer)
            } catch {
                throw IntentError.prayerTimesCalculationFailed(underlying: String(describing: error))
            }
        } else {
            // MARK: TODO
            // v1 placeholder: the application-layer coordinator that owns
            // CoreLocation should pass coordinates so this can save real
            // scheduled prayer times before shipping.
            scheduledTime = now
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
            existing.modifiedAt = .now
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
            sourceSurface: sourceSurface
        )
        context.insert(log)
        try context.save()
        return log
    }

    /// Toggles the jama'ah flag on today's log for the given prayer.
    /// Creates an on-time log when no log exists yet.
    @MainActor
    func toggleJamaah(
        for prayer: Prayer,
        sourceSurface: SourceSurface,
        in context: ModelContext
    ) throws -> PrayerLog {
        let prayerDate = Calendar.current.startOfDay(for: .now)
        let dedupKey = Self.makeDedupKey(prayer: prayer, prayerDate: prayerDate)
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.dedupKey == dedupKey }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.withJamaah.toggle()
            existing.sourceSurface = sourceSurface.rawValue
            existing.modifiedAt = .now
            try context.save()
            return existing
        }

        return try logPrayer(
            prayer,
            status: .onTime,
            withJamaah: true,
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

        let now = Date.now
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
            sourceSurface: sourceSurface
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
