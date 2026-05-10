import Foundation

public struct RamadanContext: Sendable, Equatable {
    public static let ramadanMonth = 9

    public let date: Date
    public let calendar: Calendar

    public init(
        at date: Date = .now,
        calendar: Calendar = RamadanContext.currentHijriCalendar
    ) {
        self.date = date
        self.calendar = calendar
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
        Self.isCurrentlyRamadan(at: date, calendar: calendar)
    }

    public var daysIntoRamadan: Int? {
        Self.daysIntoRamadan(at: date, calendar: calendar)
    }

    public var daysRemainingInRamadan: Int? {
        Self.daysRemainingInRamadan(at: date, calendar: calendar)
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
