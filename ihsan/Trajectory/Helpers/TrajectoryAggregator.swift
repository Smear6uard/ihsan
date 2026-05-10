import Foundation
import IhsanCore

/// Pure aggregation. SwiftData logs + pause/travel intervals + period →
/// `[DayCompletion]` and `TrajectoryAggregate`. No view dependencies, no
/// SwiftData fetches inside — testable in isolation.
enum TrajectoryAggregator {

    /// Builds the chronological day-by-day record for the period. Days with
    /// no logs render as zero-completion ghost dots; days covered by a
    /// `PauseInterval` are flagged for the dash glyph; days covered by a
    /// `TravelInterval` are flagged for the airplane overlay.
    static func buildDays(
        period: TrajectoryPeriod,
        logs: [PrayerLog],
        pauseIntervals: [PauseInterval],
        travelIntervals: [TravelInterval],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DayCompletion] {
        let (start, end) = period.window(now: now, calendar: calendar)
        var days: [DayCompletion] = []
        var cursor = start

        while cursor <= end {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor

            let dayLogs = logs.filter { log in
                log.prayerDate >= cursor && log.prayerDate < nextDay
            }

            let isPaused = pauseIntervals.contains { $0.contains(cursor) }
            let isTraveling = travelIntervals.contains { $0.contains(cursor) }

            let completions = Prayer.allCases.map { prayer -> PrayerCompletion in
                // Qada is tracked separately — exclude it from the day's
                // 5-prayer slate so a made-up Fajr from yesterday doesn't
                // overwrite today's actual Fajr status.
                let log = dayLogs.first { $0.prayer == prayer && $0.status != .qada }
                return PrayerCompletion(
                    prayer: prayer,
                    status: log?.status,
                    withJamaah: log?.withJamaah ?? false
                )
            }

            days.append(
                DayCompletion(
                    id: cursor,
                    date: cursor,
                    prayerCompletions: completions,
                    isPaused: isPaused,
                    isTraveling: isTraveling
                )
            )

            cursor = nextDay
        }

        return days
    }

    /// Period-level summary. `qadaLogs` is supplied separately because qada
    /// is filtered out of `buildDays` to keep the daily slate honest.
    static func aggregate(
        days: [DayCompletion],
        qadaLogs: [PrayerLog]
    ) -> TrajectoryAggregate {
        let activeDays = days.filter { !$0.isPaused }
        let pausedCount = days.count - activeDays.count
        let travelingCount = days.filter { $0.isTraveling }.count

        var onTime = 0
        var late = 0
        var missed = 0
        var jamaah = 0
        for day in activeDays {
            for completion in day.prayerCompletions {
                switch completion.status {
                case .onTime: onTime += 1
                case .late: late += 1
                case .missed: missed += 1
                case .qada, .none: break
                }
                if completion.withJamaah && completion.status != nil {
                    jamaah += 1
                }
            }
        }

        let totalLogged = onTime + late + missed
        let totalPossible = activeDays.count * 5
        let qadaCount = qadaLogs.count

        let perPrayer = Prayer.allCases.map { prayer -> TrajectoryAggregate.PrayerAggregate in
            var pOn = 0
            var pLate = 0
            var pMissed = 0
            for day in activeDays {
                let completion = day.prayerCompletions.first { $0.prayer == prayer }
                switch completion?.status {
                case .onTime: pOn += 1
                case .late: pLate += 1
                case .missed: pMissed += 1
                case .qada, .none: break
                }
            }
            let pQada = qadaLogs.filter { $0.prayer == prayer }.count

            let fractions: [Double?] = days.map { day in
                if day.isPaused { return nil }
                let completion = day.prayerCompletions.first { $0.prayer == prayer }
                switch completion?.status {
                case .onTime: return 1.0
                case .late: return 0.55
                case .qada: return 0.4   // partial credit — made up later
                case .missed, .none: return 0.0
                }
            }

            return TrajectoryAggregate.PrayerAggregate(
                prayer: prayer,
                onTimeCount: pOn,
                lateCount: pLate,
                missedCount: pMissed,
                qadaCount: pQada,
                totalActiveDays: activeDays.count,
                dailyFractions: fractions
            )
        }

        return TrajectoryAggregate(
            totalActiveDays: activeDays.count,
            pausedDays: pausedCount,
            travelingDays: travelingCount,
            totalLogged: totalLogged,
            totalPossible: totalPossible,
            onTimeCount: onTime,
            lateCount: late,
            missedCount: missed,
            qadaCount: qadaCount,
            jamaahCount: jamaah,
            perPrayer: perPrayer
        )
    }
}
