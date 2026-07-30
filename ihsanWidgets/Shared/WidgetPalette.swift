import Foundation
import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// The widget's ground, resolved from the same solar events the plate
/// rides.
///
/// The app publishes its day's events into `IhsanPageChrome`, but a
/// widget is a separate process and sees none of that. It has something
/// better: the exact resolver table the app wrote to the App Group. So
/// the events are rebuilt from the entry, and every widget's ground
/// moves through dawn, morning, afternoon, sunset, and night on the
/// real sun rather than on a clock approximation.
enum WidgetPalette {

    static func events(for entry: PrayerTimelineEntry) -> SolarDayEvents? {
        func time(_ prayer: Prayer) -> Date? {
            entry.todayPrayerTimes.first { $0.prayer == prayer }?.scheduledTime
        }
        guard
            let fajr = time(.fajr),
            let dhuhr = time(.dhuhr),
            let maghrib = time(.maghrib),
            let isha = time(.isha)
        else { return nil }

        // Dhuhr is the app's stand-in for solar noon everywhere else;
        // using anything different here would put the widget's ground a
        // few minutes out of step with the plate's.
        return SolarDayEvents(
            fajr: fajr,
            sunrise: entry.sunrise,
            solarNoon: dhuhr,
            maghrib: maghrib,
            isha: isha
        )
    }

    static func phase(for entry: PrayerTimelineEntry) -> SkyPhase {
        guard let events = events(for: entry) else {
            return SkyPhase.approximate(
                at: entry.date,
                timeZone: TimeZone(identifier: entry.timeZoneIdentifier) ?? .current
            )
        }
        return SkyPhase.resolve(at: entry.date, events: events)
    }

    static func tokens(for entry: PrayerTimelineEntry) -> SkyPaletteTokens {
        PaletteState.resolved(for: phase(for: entry))
    }

    /// The ground a home-screen widget sits on.
    ///
    /// Widgets are read at arm's length against arbitrary wallpaper, so
    /// this is a touch deeper than the app's own page — a widget that
    /// matched the app exactly would wash out on a bright home screen.
    static func homeGround(for entry: PrayerTimelineEntry) -> some View {
        let tokens = tokens(for: entry)
        return LinearGradient(
            colors: [
                tokens.groundTopValue.darkened(by: 0.10).color,
                tokens.groundBottomValue.darkened(by: 0.16).color
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The nightstand ground: the night end of the same ramp, dimmer
    /// still, and never allowed to drift toward day. StandBy is looked
    /// at from a dark room in the small hours.
    static func standByGround(for entry: PrayerTimelineEntry) -> some View {
        let tokens = PaletteState.night.tokens
        return LinearGradient(
            colors: [
                tokens.groundTopValue.darkened(by: 0.45).color,
                tokens.groundBottomValue.darkened(by: 0.55).color
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension SRGBValue {
    func darkened(by amount: Double) -> SRGBValue {
        let k = 1.0 - max(0, min(1, amount))
        return SRGBValue(red: red * k, green: green * k, blue: blue * k)
    }
}

/// Whether this rendering is StandBy or a Lock Screen placement rather
/// than the home screen. Apple's signal for both is the absence of the
/// widget's container background.
extension EnvironmentValues {
    var isBackgroundlessPlacement: Bool {
        !showsWidgetContainerBackground
    }
}
