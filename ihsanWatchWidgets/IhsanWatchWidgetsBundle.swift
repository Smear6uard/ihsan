import WidgetKit
import SwiftUI

/// Single registration point for the three watch complication
/// families. Each family is its own `Widget` so the user can pick
/// any combination on their watch face.
@main
struct IhsanWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerCornerWidget()
        DayProgressCircularWidget()
        PrayerListRectangularWidget()
    }
}
