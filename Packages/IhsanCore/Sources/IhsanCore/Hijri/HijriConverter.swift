import Foundation

/// THE one Hijri converter. Every surface that names a Hijri date —
/// the Today header, the Hijri month sheet, reflection cards, the
/// significant-day line, Ramadan recognition — derives it from here,
/// with the user's moonsighting adjustment applied. No second
/// conversion path exists.
///
/// The base tabulation is Umm al-Qura; `offsetDays` (±2) shifts the
/// civil-day mapping because moonsighting differs by community: a +1
/// adjustment means the user's community is one day AHEAD of the
/// tabulation (their month began a day earlier), so today reads one
/// Hijri day later.
public enum HijriConverter {

    /// The user-adjustable range of the moonsighting offset.
    public static let offsetRange = -2...2

    public struct Components: Sendable, Equatable, Hashable {
        public let year: Int
        /// 1 (Muharram) … 12 (Dhul-Hijjah).
        public let month: Int
        public let day: Int

        public init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }

        public var monthName: String {
            HijriConverter.monthName(month)
        }
    }

    /// One day of a Hijri month, paired with the Gregorian civil day
    /// it falls on under the user's adjustment — the month sheet's
    /// grid rows.
    public struct Day: Sendable, Equatable {
        public let components: Components
        /// Start of the Gregorian civil day this Hijri day maps to.
        public let civilDayStart: Date
        public let significance: [HijriSignificance]
    }

    // MARK: - Conversion

    private static func ummAlQura(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private static func gregorian(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The Hijri date of `date` with the adjustment applied.
    public static func components(
        for date: Date,
        offsetDays: Int,
        timeZone: TimeZone = .current
    ) -> Components {
        let clamped = max(offsetRange.lowerBound, min(offsetRange.upperBound, offsetDays))
        let civil = gregorian(timeZone: timeZone)
        let shifted = civil.date(byAdding: .day, value: clamped, to: date) ?? date
        let parts = ummAlQura(timeZone: timeZone).dateComponents(
            [.year, .month, .day], from: shifted
        )
        return Components(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// "Safar 14, 1448 AH" — the one display form.
    public static func string(
        for date: Date,
        offsetDays: Int,
        timeZone: TimeZone = .current
    ) -> String {
        let parts = components(for: date, offsetDays: offsetDays, timeZone: timeZone)
        return "\(parts.monthName) \(parts.day), \(parts.year) AH"
    }

    /// Every day of the Hijri month containing `date` (adjustment
    /// applied), each paired with the Gregorian civil day it falls on
    /// for this user.
    public static func monthDays(
        containing date: Date,
        offsetDays: Int,
        timeZone: TimeZone = .current
    ) -> [Day] {
        let clamped = max(offsetRange.lowerBound, min(offsetRange.upperBound, offsetDays))
        let hijri = ummAlQura(timeZone: timeZone)
        let civil = gregorian(timeZone: timeZone)

        let shiftedToday = civil.date(byAdding: .day, value: clamped, to: date) ?? date
        let monthParts = hijri.dateComponents([.year, .month], from: shiftedToday)
        guard
            let year = monthParts.year, let month = monthParts.month,
            let monthStart = hijri.date(from: DateComponents(year: year, month: month, day: 1)),
            let dayCount = hijri.range(of: .day, in: .month, for: monthStart)?.count
        else { return [] }

        return (1...dayCount).compactMap { day -> Day? in
            guard let tabulated = hijri.date(
                from: DateComponents(year: year, month: month, day: day)
            ) else { return nil }
            // The user's civil day for this Hijri day is the
            // tabulated one shifted BACK by the adjustment.
            guard let userCivil = civil.date(byAdding: .day, value: -clamped, to: tabulated)
            else { return nil }
            let components = Components(year: year, month: month, day: day)
            return Day(
                components: components,
                civilDayStart: civil.startOfDay(for: userCivil),
                significance: significance(of: components)
            )
        }
    }

    // MARK: - Month names
    //
    // Curated romanizations, following the app's vocabulary style
    // (ʿ = U+02BF for ʿayn). One list, used verbatim everywhere.

    private static let monthNames: [String] = [
        "Muharram", "Safar", "Rabiʿ al-Awwal", "Rabiʿ al-Thani",
        "Jumada al-Ula", "Jumada al-Akhirah", "Rajab", "Shaʿban",
        "Ramadan", "Shawwal", "Dhul-Qaʿdah", "Dhul-Hijjah",
    ]

    public static func monthName(_ month: Int) -> String {
        guard (1...12).contains(month) else { return "" }
        return monthNames[month - 1]
    }

    // MARK: - Significant days (curated static facts)

    /// The significance of a Hijri date — dates and names only, from
    /// curated static data. The app never generates religious
    /// content, never rules, and marks nothing as obligatory beyond
    /// Ramadan's well-established status.
    public static func significance(of components: Components) -> [HijriSignificance] {
        var found: [HijriSignificance] = []
        if components.month == 9 {
            found.append(.ramadan)
        }
        if components.month == 12, components.day == 9 {
            found.append(.arafah)
        } else if components.month == 12, (1...10).contains(components.day) {
            found.append(.firstTenOfDhulHijjah)
        }
        if components.month == 1, components.day == 9 {
            found.append(.ninthOfMuharram)
        }
        if components.month == 1, components.day == 10 {
            found.append(.ashura)
        }
        if components.month != 9, (13...15).contains(components.day) {
            found.append(.whiteDay)
        }
        return found
    }

    /// A month-level range note, where the significance belongs to
    /// the month rather than single days — the six of Shawwal.
    public static func monthNote(forMonth month: Int) -> String? {
        month == 10 ? "The six of Shawwal · any six days after Eid" : nil
    }
}

/// A curated significant day. Facts only — a name and its date rule;
/// no exhortation, no ruling, no obligation language (Ramadan's
/// status is established fact, and even it is only NAMED here).
public enum HijriSignificance: Sendable, Equatable, CaseIterable {
    case ramadan
    case arafah
    case firstTenOfDhulHijjah
    case ninthOfMuharram
    case ashura
    case whiteDay

    /// The small-caps inscription label.
    public var label: String {
        switch self {
        case .ramadan: return "Ramadan"
        case .arafah: return "Day of ʿArafah"
        case .firstTenOfDhulHijjah: return "First ten of Dhul-Hijjah"
        case .ninthOfMuharram: return "9th of Muharram"
        case .ashura: return "ʿAshura"
        case .whiteDay: return "White day"
        }
    }

    /// The Today line's full inscription for a given date — "White
    /// day · Safar 14" register. States the fact; nothing more.
    public func inscription(for components: HijriConverter.Components) -> String {
        switch self {
        case .ramadan:
            return "Ramadan \(components.day)"
        case .arafah:
            return "Day of ʿArafah"
        case .firstTenOfDhulHijjah:
            return "Dhul-Hijjah \(components.day) · First ten"
        case .ninthOfMuharram:
            return "Muharram 9"
        case .ashura:
            return "ʿAshura · Muharram 10"
        case .whiteDay:
            return "White day · \(components.monthName) \(components.day)"
        }
    }
}
