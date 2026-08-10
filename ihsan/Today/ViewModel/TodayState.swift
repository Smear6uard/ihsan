import Foundation
import IhsanCore
import IhsanLocation
import IhsanPrayerTimes

enum TodayState {
    case loading
    case needsLocationPermission
    case ready(Snapshot)
    case error(String)

    struct Snapshot {
        let place: LocatedPlace
        /// Three days of schedule bracketing the refresh moment. The
        /// views derive the current/next prayer, window ends, and
        /// countdown targets from this on every clock tick — the
        /// snapshot itself stores no "current" state that could go
        /// stale between refreshes.
        let scheduleWindow: PrayerScheduleWindow
        let ramadanContext: RamadanContext
        /// The night relevant to this moment: the one in progress during
        /// the pre-dawn hours, otherwise the night ahead of today. The
        /// plate only draws it while the moment is inside its span.
        let night: NightIntervals?
        /// The user's masjid, when they have set one. A value copy, not
        /// the model: `@Model` types are not `Sendable`. `nil` renders
        /// every surface exactly as it was before this existed.
        let myMasjid: MyMasjidSnapshot?

        var isCurrentlyRamadan: Bool {
            ramadanContext.isCurrentlyRamadan
        }
    }
}
