import Foundation
import IhsanCore

/// Owns Trajectory's derived state. The screen passes in `@Query` results;
/// the view-model caches them so a `period` change can re-aggregate without
/// the screen having to re-fetch.
@Observable
@MainActor
final class TrajectoryViewModel {
    var state: TrajectoryState = .loading
    /// `-IhsanDebugPeriod 7|30|90|365` stages the range for a capture
    /// run; the selector is the only other way in.
    var period: TrajectoryPeriod = TrajectoryPeriod.debugStaged ?? .thirtyDays {
        didSet {
            guard period != oldValue else { return }
            recompute()
        }
    }

    /// The screen's clock — the same injectable NowProvider every
    /// other surface reads, so a debug now-override moves the period
    /// window together with the rest of the app. `.system` until the
    /// screen injects the environment's provider.
    var nowProvider: NowProvider = .system

    private var cachedLogs: [PrayerLog] = []
    private var cachedPauses: [PauseInterval] = []
    private var cachedTravels: [TravelInterval] = []

    /// Called by the screen with the latest `@Query` results.
    func refresh(
        logs: [PrayerLog],
        pauseIntervals: [PauseInterval],
        travelIntervals: [TravelInterval]
    ) {
        cachedLogs = logs
        cachedPauses = pauseIntervals
        cachedTravels = travelIntervals
        recompute()
    }

    private func recompute() {
        if cachedLogs.isEmpty {
            state = .empty
            return
        }

        let days = TrajectoryAggregator.buildDays(
            period: period,
            logs: cachedLogs,
            pauseIntervals: cachedPauses,
            travelIntervals: cachedTravels,
            cycleDate: PrayerCycleClock.sharedCycleDate(at: nowProvider.now())
        )

        // Qada belongs to the selected Path window, not the account's
        // lifetime total. Keep the same half-open cycle bounds used to
        // build the day rows so the summary and the grid cannot drift.
        let qadaLogs = Self.qadaLogs(in: days, from: cachedLogs)
        let aggregate = TrajectoryAggregator.aggregate(days: days, qadaLogs: qadaLogs)

        state = .ready(.init(period: period, days: days, aggregate: aggregate))
    }

    static func qadaLogs(
        in days: [DayCompletion],
        from logs: [PrayerLog],
        calendar: Calendar = .current
    ) -> [PrayerLog] {
        guard let firstDay = days.first?.date,
              let lastDay = days.last?.date,
              let end = calendar.date(byAdding: .day, value: 1, to: lastDay)
        else { return [] }

        return logs.filter {
            $0.status == .qada
                && $0.prayerDate >= firstDay
                && $0.prayerDate < end
        }
    }
}
