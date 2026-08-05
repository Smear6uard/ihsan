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
///
/// Clock 2 lives here: **the Hijri day begins at Maghrib**, not at
/// midnight. Given the Maghrib of the civil day an instant falls in,
/// every conversion below anchors on the next civil day once that
/// Maghrib has passed — so the evening of the 13th already reads as
/// the 14th, a white day announces itself the night it starts, and the
/// niyyah for tomorrow's fast is offered inside the Hijri day it
/// belongs to. The moonsighting adjustment applies on top, unchanged.
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

    /// The civil day whose tabulated Hijri date applies at `instant`.
    ///
    /// At or past that day's Maghrib the Hijri day has already turned,
    /// so the anchor moves forward one civil day. An unknown Maghrib
    /// (`nil`) leaves the instant where it is — which is the right
    /// answer for the case that produces it, a historical date passed
    /// as a day start.
    static func eveningAnchor(
        _ instant: Date,
        maghrib: Date?,
        timeZone: TimeZone
    ) -> Date {
        guard let maghrib, instant >= maghrib else { return instant }
        return gregorian(timeZone: timeZone)
            .date(byAdding: .day, value: 1, to: instant) ?? instant
    }

    /// The civil day whose DAYTIME belongs to the Hijri day in
    /// progress at `instant` — the day a fast intended now would
    /// actually be kept.
    ///
    /// Before Maghrib that is today; at or after it, tomorrow. This is
    /// the whole of "the night precedes the daytime" in one call, and
    /// it is why a Wednesday-evening niyyah files under Thursday.
    public static func daytimeCivilDay(
        at instant: Date,
        maghrib: Date?,
        timeZone: TimeZone = .current
    ) -> Date {
        gregorian(timeZone: timeZone).startOfDay(
            for: eveningAnchor(instant, maghrib: maghrib, timeZone: timeZone)
        )
    }

    /// The civil day whose daytime belongs to the Hijri day in
    /// progress, using the Maghrib the process has published.
    public static func daytimeCivilDay(
        at instant: Date,
        timeZone: TimeZone = .current
    ) -> Date {
        daytimeCivilDay(
            at: instant,
            maghrib: HijriDisplay.maghrib(forCivilDayOf: instant, in: timeZone),
            timeZone: timeZone
        )
    }

    /// The Hijri date at `date`, with the adjustment applied and the
    /// Hijri day turned at `maghrib` — the civil day's sunset.
    public static func components(
        for date: Date,
        offsetDays: Int,
        maghribOfCivilDay maghrib: Date?,
        timeZone: TimeZone = .current
    ) -> Components {
        let clamped = max(offsetRange.lowerBound, min(offsetRange.upperBound, offsetDays))
        let civil = gregorian(timeZone: timeZone)
        let anchored = eveningAnchor(date, maghrib: maghrib, timeZone: timeZone)
        let shifted = civil.date(byAdding: .day, value: clamped, to: anchored) ?? anchored
        let parts = ummAlQura(timeZone: timeZone).dateComponents(
            [.year, .month, .day], from: shifted
        )
        return Components(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// The Hijri date of `date`, turning at the Maghrib the process has
    /// published for that civil day.
    public static func components(
        for date: Date,
        offsetDays: Int,
        timeZone: TimeZone = .current
    ) -> Components {
        components(
            for: date,
            offsetDays: offsetDays,
            maghribOfCivilDay: HijriDisplay.maghrib(forCivilDayOf: date, in: timeZone),
            timeZone: timeZone
        )
    }

    /// "Safar 14, 1448 AH" — the one display form.
    public static func string(
        for date: Date,
        offsetDays: Int,
        timeZone: TimeZone = .current
    ) -> String {
        string(for: components(for: date, offsetDays: offsetDays, timeZone: timeZone))
    }

    /// The display form for an already-resolved date.
    public static func string(for parts: Components) -> String {
        "\(parts.monthName) \(parts.day), \(parts.year) AH"
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

        // The sheet opens on the month containing the Hijri day the
        // user is IN, so it turns with the evening like every other
        // surface — on the last night of a month, the sheet is already
        // the next month's.
        let anchored = eveningAnchor(
            date,
            maghrib: HijriDisplay.maghrib(forCivilDayOf: date, in: timeZone),
            timeZone: timeZone
        )
        let shiftedToday = civil.date(byAdding: .day, value: clamped, to: anchored) ?? anchored
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
