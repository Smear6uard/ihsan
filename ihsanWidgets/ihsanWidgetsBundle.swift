import SwiftUI
import WidgetKit

/// Entry point for the widget extension: three home-screen sizes, the
/// nightstand face for StandBy, three lock-screen accessory families,
/// the Repair complication, and the Control Center button.
@main
struct IhsanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home screen
        NextPrayerSmallWidget()
        HijriDayWidget()
        PrayerStatusMediumWidget()
        PrayerOverviewLargeWidget()
        // StandBy
        StandByPlateWidget()
        // Lock screen
        NextPrayerInlineWidget()
        NextPrayerCircularWidget()
        WindowGaugeCircularWidget()
        NextPrayerRectangularWidget()
        NowNextRectangularWidget()
        DayRowRectangularWidget()
        NightRectangularWidget()
        FastingCircularWidget()
        FastingRectangularWidget()
        RepairMakeupCircularWidget()
        // Control Center
        RepairMakeupControl()
        #if canImport(ActivityKit) && os(iOS)
        PrayerActivityWidget()
        #endif
    }
}
