import Foundation
import IhsanCore

/// Owns Trajectory's derived state. The screen passes in `@Query` results;
/// the view-model caches them so a `period` change can re-aggregate without
/// the screen having to re-fetch.
@Observable
@MainActor
final class TrajectoryViewModel {
    var state: TrajectoryState = .loading
    var period: TrajectoryPeriod = .thirtyDays {
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
            now: nowProvider.now()
        )

        let qadaLogs = cachedLogs.filter { $0.status == .qada }
        let aggregate = TrajectoryAggregator.aggregate(days: days, qadaLogs: qadaLogs)

        state = .ready(.init(period: period, days: days, aggregate: aggregate))
    }
}
