import Foundation

/// Which congregation time a prayer is showing.
public enum IqamahKind: String, Sendable, Equatable {
    case iqamah
    /// Friday's khutbah, which stands in place of the Dhuhr iqamah.
    case khutbah
}

/// One congregation time, resolved to an absolute instant. Formatting
/// happens at the UI layer, in the place's timezone, like every other date
/// in this app.
public struct ResolvedIqamah: Sendable, Equatable {
    public let kind: IqamahKind
    public let time: Date

    public init(kind: IqamahKind, time: Date) {
        self.kind = kind
        self.time = time
    }
}

/// Decides what a prayer's congregation line says — and whether it says
/// anything at all.
///
/// Kept here rather than beside the views because it is pure and because
/// the card, the log sheet, and the reminder scheduler must not be able to
/// disagree about which time a prayer keeps.
public enum IqamahResolver {

    public static func resolved(
        masjid: MyMasjidSnapshot?,
        prayer: Prayer,
        adhan: Date,
        timeZone: TimeZone
    ) -> ResolvedIqamah? {
        guard let masjid else { return nil }

        // Friday's Dhuhr is Jumu'ah, and the khutbah is the time a person
        // actually needs to arrive for. Where one is set it replaces the
        // ordinary iqamah; where it is not, Dhuhr keeps its own.
        if prayer == .dhuhr,
           isFriday(adhan, in: timeZone),
           let khutbahMinutes = masjid.jumuahKhutbahMinutesFromMidnight,
           let khutbah = IqamahSchedule.resolveFixed(
               minutesFromMidnight: khutbahMinutes, onOrAfter: adhan, timeZone: timeZone
           ) {
            return ResolvedIqamah(kind: .khutbah, time: khutbah)
        }

        guard let time = IqamahSchedule.resolve(
            entry: masjid.entry(for: prayer), adhan: adhan, timeZone: timeZone
        ) else {
            return nil
        }
        return ResolvedIqamah(kind: .iqamah, time: time)
    }

    /// Friday belongs to the place, not to the phone. Someone in Tokyo on
    /// Friday afternoon sees the khutbah even while the device's own zone
    /// is still on Thursday.
    private static func isFriday(_ date: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.weekday, from: date) == 6
    }
}
