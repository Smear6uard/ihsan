import SwiftUI
import WidgetKit

/// Entry point for the widget extension. Registers all six families:
/// three home screen sizes and three lock screen accessory families.
@main
struct IhsanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home screen
        NextPrayerSmallWidget()
        PrayerStatusMediumWidget()
        PrayerOverviewLargeWidget()
        // Lock screen
        NextPrayerRectangularWidget()
        PrayerProgressCircularWidget()
        NextPrayerInlineWidget()
        RepairMakeupCircularWidget()
        // Control Center
        RepairMakeupControl()
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOSApplicationExtension 16.2, *) {
            PrayerActivityWidget()
        }
        #endif
    }
}
