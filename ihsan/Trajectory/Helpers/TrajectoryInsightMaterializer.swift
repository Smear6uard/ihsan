import Foundation
import IhsanCore

/// Converts the Path's already-materialized aggregate into the narrow
/// numeric record the on-device model is allowed to read. Raw prayer
/// logs never cross into the insights package.
enum TrajectoryInsightMaterializer {
    static func makeSummary(
        snapshot: TrajectoryState.Snapshot,
        dhikrSessions: [DhikrSession],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> PeriodSummary? {
        guard let kind = periodKind(for: snapshot.period),
              let firstDay = snapshot.days.first?.date,
              let lastDay = snapshot.days.last?.date,
              let periodEnd = calendar.date(byAdding: .day, value: 1, to: lastDay)
        else { return nil }

        let aggregate = snapshot.aggregate
        let byPrayer = aggregate.perPrayer.map { prayer in
            ByPrayerStat(
                prayer: prayer.prayer,
                expected: prayer.totalActiveDays,
                logged: prayer.onTimeCount + prayer.lateCount + prayer.missedCount,
                onTime: prayer.onTimeCount,
                late: prayer.lateCount,
                missed: prayer.missedCount,
                jamaah: jamaahCount(
                    for: prayer.prayer,
                    in: snapshot.days
                )
            )
        }

        let dhikrCount = dhikrSessions.filter {
            $0.sessionDate >= firstDay && $0.sessionDate < periodEnd
        }.count

        return PeriodSummary(
            periodKind: kind,
            periodStart: firstDay,
            periodEnd: periodEnd,
            loggedTimeZoneIdentifier: calendar.timeZone.identifier,
            expectedPrayerCount: aggregate.totalPossible,
            loggedPrayerCount: aggregate.totalLogged,
            onTimeCount: aggregate.onTimeCount,
            lateCount: aggregate.lateCount,
            missedCount: aggregate.missedCount,
            qadaLoggedCount: aggregate.qadaCount,
            jamaahCount: aggregate.jamaahCount,
            pausedDayCount: aggregate.pausedDays,
            traveledDayCount: aggregate.travelingDays,
            byPrayer: byPrayer,
            dhikrSessionCount: dhikrCount,
            lastRecomputedAt: now,
            createdAt: now,
            modifiedAt: now
        )
    }

    /// Reuses the one cached record for this period kind. Any change in
    /// the numeric source invalidates generated text before a new model
    /// request is made; presentation-only changes do not.
    @discardableResult
    static func refresh(
        _ existing: PeriodSummary,
        from materialized: PeriodSummary,
        now: Date = .now
    ) -> Bool {
        let changed = dataFingerprint(existing) != dataFingerprint(materialized)

        existing.periodStart = materialized.periodStart
        existing.periodEnd = materialized.periodEnd
        existing.loggedTimeZoneIdentifier = materialized.loggedTimeZoneIdentifier
        existing.expectedPrayerCount = materialized.expectedPrayerCount
        existing.loggedPrayerCount = materialized.loggedPrayerCount
        existing.onTimeCount = materialized.onTimeCount
        existing.lateCount = materialized.lateCount
        existing.missedCount = materialized.missedCount
        existing.qadaLoggedCount = materialized.qadaLoggedCount
        existing.jamaahCount = materialized.jamaahCount
        existing.pausedDayCount = materialized.pausedDayCount
        existing.traveledDayCount = materialized.traveledDayCount
        existing.byPrayerJSON = materialized.byPrayerJSON
        existing.dhikrSessionCount = materialized.dhikrSessionCount
        existing.lastRecomputedAt = now

        if changed {
            existing.aiInsightText = nil
            existing.aiInsightGeneratedAt = nil
            existing.aiInsightModelVersion = nil
            existing.modifiedAt = now
        }

        return changed
    }

    static func periodKind(for period: TrajectoryPeriod) -> PeriodKind? {
        switch period {
        case .sevenDays: .week
        case .thirtyDays: .month
        case .ninetyDays, .year: nil
        }
    }

    private static func jamaahCount(
        for prayer: Prayer,
        in days: [DayCompletion]
    ) -> Int {
        days
            .filter { !$0.isPaused }
            .compactMap { day in
                day.prayerCompletions.first { $0.prayer == prayer }
            }
            .filter { $0.status != nil && $0.withJamaah }
            .count
    }

    private static func dataFingerprint(_ summary: PeriodSummary) -> String {
        [
            summary.periodKindRaw,
            String(summary.periodStart.timeIntervalSinceReferenceDate),
            String(summary.periodEnd.timeIntervalSinceReferenceDate),
            summary.loggedTimeZoneIdentifier,
            String(summary.expectedPrayerCount),
            String(summary.loggedPrayerCount),
            String(summary.onTimeCount),
            String(summary.lateCount),
            String(summary.missedCount),
            String(summary.qadaLoggedCount),
            String(summary.jamaahCount),
            String(summary.pausedDayCount),
            String(summary.traveledDayCount),
            String(summary.dhikrSessionCount),
            summary.byPrayerJSON
        ].joined(separator: "|")
    }
}
