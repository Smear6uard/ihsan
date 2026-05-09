import Foundation

/// View state for the Trajectory screen. Three branches: a brief loading
/// flash before SwiftData hands us the first results, an empty branch when
/// the user has logged nothing yet, and a ready snapshot otherwise.
enum TrajectoryState: Equatable {
    case loading
    case empty
    case ready(Snapshot)

    struct Snapshot: Equatable {
        let period: TrajectoryPeriod
        let days: [DayCompletion]
        let aggregate: TrajectoryAggregate
    }
}
