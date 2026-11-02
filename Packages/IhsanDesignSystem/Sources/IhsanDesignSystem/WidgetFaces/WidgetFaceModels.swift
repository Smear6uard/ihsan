import Foundation
import IhsanCore

/// The pure models widget faces render from.
///
/// Faces live in the design system so every one of them can be
/// rendered and pinned by SwiftPM tests at exact widget geometry —
/// the widget extension is only the translation from a timeline entry
/// to these values. Nothing here imports WidgetKit and nothing is
/// computed: marker states, countdown ranges, and inscriptions arrive
/// resolved.
public struct WidgetDayModel: Sendable, Equatable {
    public struct Slot: Sendable, Equatable, Identifiable {
        public let prayer: Prayer
        /// Where the ornament sits on the arc — the cycle's own instant,
        /// so the arc stays the day's scale.
        public let time: Date
        /// What the face prints. The same as `time`, except Fajr from
        /// the cycle's Isha onward, which names the dawn ahead — the
        /// Fajr the countdown is counting to.
        public let displayTime: Date
        public let state: PrayerMarkerState

        public var id: String { prayer.rawValue }

        public init(
            prayer: Prayer,
            time: Date,
            displayTime: Date? = nil,
            state: PrayerMarkerState
        ) {
            self.prayer = prayer
            self.time = time
            self.displayTime = displayTime ?? time
            self.state = state
        }
    }

    /// The instant this face describes — sun and moon glyphs ride it.
    public let date: Date
    /// The bracket day's five prayers with resolved marker states.
    public let slots: [Slot]
    public let nextPrayer: Prayer
    public let nextTime: Date
    /// Pre-clamped; safe for `Text(timerInterval:)` by construction.
    public let countdown: ClosedRange<Date>
    public let currentPrayer: Prayer?
    public let currentWindow: ClosedRange<Date>?
    /// The day's sunrise: places the arc's tick and rides the sun.
    public let sunrise: Date
    /// The sunrise the face prints — the one that ends the printed
    /// Fajr's window. After Isha that is tomorrow's.
    public let displayedSunrise: Date
    public let cityName: String?
    public let timeZoneIdentifier: String
    /// During an excused pause faces show times and carry no logging
    /// surface, no status inscriptions, and no fill-in pressure.
    public let isPaused: Bool

    public let hijri: WidgetHijriModel?
    public let fasting: WidgetFastingModel?
    public let night: WidgetNightModel?

    public init(
        date: Date,
        slots: [Slot],
        nextPrayer: Prayer,
        nextTime: Date,
        countdown: ClosedRange<Date>,
        currentPrayer: Prayer?,
        currentWindow: ClosedRange<Date>?,
        sunrise: Date,
        displayedSunrise: Date? = nil,
        cityName: String?,
        timeZoneIdentifier: String,
        isPaused: Bool,
        hijri: WidgetHijriModel? = nil,
        fasting: WidgetFastingModel? = nil,
        night: WidgetNightModel? = nil
    ) {
        self.date = date
        self.slots = slots
        self.nextPrayer = nextPrayer
        self.nextTime = nextTime
        self.countdown = countdown
        self.currentPrayer = currentPrayer
        self.currentWindow = currentWindow
        self.sunrise = sunrise
        self.displayedSunrise = displayedSunrise ?? sunrise
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isPaused = isPaused
        self.hijri = hijri
        self.fasting = fasting
        self.night = night
    }

    /// Wall-clock text in the place timezone — never the device's.
    public func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: date)
    }

    /// Hour and minute without the day period ("4:53", or "16:53" where
    /// the locale keeps a 24-hour clock) — for a row whose order through
    /// the day already says morning or evening, where six "PM"s would
    /// crowd the times they qualify.
    ///
    /// Spelled with patterns rather than `amPM: .omitted`, which pads the
    /// hour to "04:11" in en_US.
    public func compactClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        let usesDayPeriod = DateFormatter
            .dateFormat(fromTemplate: "j", options: 0, locale: formatter.locale)?
            .contains("a") ?? true
        if usesDayPeriod {
            formatter.dateFormat = "h:mm"
        } else {
            formatter.setLocalizedDateFormatFromTemplate("Hmm")
        }
        return formatter.string(from: date)
    }
}

public struct WidgetHijriModel: Sendable, Equatable {
    public let day: Int
    public let monthName: String
    public let year: Int
    /// "White day · Safar 13" — precomputed by the app; nil when the
    /// day is unmarked.
    public let significantLine: String?
    public let isRamadan: Bool

    public init(
        day: Int, monthName: String, year: Int,
        significantLine: String?, isRamadan: Bool
    ) {
        self.day = day
        self.monthName = monthName
        self.year = year
        self.significantLine = significantLine
        self.isRamadan = isRamadan
    }

    public var displayLine: String { "\(monthName) \(day), \(year) AH" }
}

/// Present only on a day with a recorded fast (or in Ramadan).
public struct WidgetFastingModel: Sendable, Equatable {
    /// Suhoor ends at Fajr.
    public let suhoorEnds: Date
    /// Iftar arrives at Maghrib.
    public let iftar: Date
    public let isRamadan: Bool

    public init(suhoorEnds: Date, iftar: Date, isRamadan: Bool) {
        self.suhoorEnds = suhoorEnds
        self.iftar = iftar
        self.isRamadan = isRamadan
    }
}

public struct WidgetNightModel: Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let nisfAlLayl: Date
    public let lastThirdStart: Date

    public init(start: Date, end: Date, nisfAlLayl: Date, lastThirdStart: Date) {
        self.start = start
        self.end = end
        self.nisfAlLayl = nisfAlLayl
        self.lastThirdStart = lastThirdStart
    }
}

/// How a face is being rendered.
///
/// `fullColor` is the standard home screen. `accented` covers the iOS
/// tinted and clear modes: the system flattens colour, so the face
/// pre-decides its hierarchy — ornaments and primary figures accent,
/// grounds recede to nothing, secondary text stays material. Lock
/// accessories have their own faces designed luminance-first and do
/// not use this switch.
public enum WidgetFaceMode: Sendable, Equatable {
    case fullColor
    case accented
}
