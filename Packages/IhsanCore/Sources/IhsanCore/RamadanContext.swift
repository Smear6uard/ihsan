import Foundation

public struct RamadanContext: Sendable, Equatable {
    public static let ramadanMonth = 9

    public let date: Date
    public let calendar: Calendar
    /// The user's moonsighting adjustment — Ramadan recognition rides
    /// THE one Hijri mapping (`HijriConverter`), offset included, so
    /// the fasting layer and the header can never disagree about the
    /// month.
    public let offsetDays: Int

    public init(
        at date: Date = .now,
        calendar: Calendar = RamadanContext.currentHijriCalendar,
        offsetDays: Int = 0
    ) {
        self.date = date
        self.calendar = calendar
        self.offsetDays = offsetDays
    }

    public static var currentHijriCalendar: Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = .autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }

    public static var isCurrentlyRamadan: Bool {
        isCurrentlyRamadan(at: .now, calendar: currentHijriCalendar)
    }

    public var isCurrentlyRamadan: Bool {
        hijriComponents.month == Self.ramadanMonth
    }

    public var daysIntoRamadan: Int? {
        isCurrentlyRamadan ? hijriComponents.day : nil
    }

    public var daysRemainingInRamadan: Int? {
        guard isCurrentlyRamadan else { return nil }
        // Umm al-Qura months run 29 or 30 days; length comes from the
        // tabulation for the adjusted month.
        let days = HijriConverter.monthDays(
            containing: date, offsetDays: offsetDays, timeZone: calendar.timeZone
        ).count
        return max(0, days - hijriComponents.day)
    }

    private var hijriComponents: HijriConverter.Components {
        HijriConverter.components(
            for: date, offsetDays: offsetDays, timeZone: calendar.timeZone
        )
    }

    public static func isCurrentlyRamadan(
        at date: Date,
        calendar: Calendar
    ) -> Bool {
        var hijriCalendar = calendar
        if hijriCalendar.identifier != .islamicUmmAlQura {
            hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
            hijriCalendar.timeZone = calendar.timeZone
            hijriCalendar.locale = calendar.locale
        }

        return hijriCalendar.component(.month, from: date) == ramadanMonth
    }

    public static func daysIntoRamadan(
        at date: Date,
        calendar: Calendar
    ) -> Int? {
        guard isCurrentlyRamadan(at: date, calendar: calendar) else {
            return nil
        }

        var hijriCalendar = calendar
        if hijriCalendar.identifier != .islamicUmmAlQura {
            hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
            hijriCalendar.timeZone = calendar.timeZone
            hijriCalendar.locale = calendar.locale
        }

        return hijriCalendar.component(.day, from: date)
    }

    public static func daysRemainingInRamadan(
        at date: Date,
        calendar: Calendar
    ) -> Int? {
        guard
            let day = daysIntoRamadan(at: date, calendar: calendar)
        else {
            return nil
        }

        var hijriCalendar = calendar
        if hijriCalendar.identifier != .islamicUmmAlQura {
            hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
            hijriCalendar.timeZone = calendar.timeZone
            hijriCalendar.locale = calendar.locale
        }

        guard let range = hijriCalendar.range(of: .day, in: .month, for: date) else {
            return nil
        }

        return max(0, range.count - day)
    }
}
