import Foundation
import IhsanCore

/// The congregation line, in the state line's own register.
///
/// `IqamahResolver` decides *which* time a prayer keeps; this only dresses
/// it. Both the card and the log sheet read this one function, so the two
/// surfaces cannot phrase the same fact differently.
///
/// The line always states the resolved time and never the rule that
/// produced it: "IQAMAH · 1:30 PM", never "Fajr + 20 min". A person
/// standing in the doorway needs the time.
enum IqamahInscription {

    /// The visible inscription, or nil when this prayer keeps no
    /// congregation time.
    static func text(
        masjid: MyMasjidSnapshot?,
        prayer: Prayer,
        adhan: Date,
        timeZone: TimeZone
    ) -> String? {
        guard let resolved = IqamahResolver.resolved(
            masjid: masjid, prayer: prayer, adhan: adhan, timeZone: timeZone
        ) else {
            return nil
        }
        return "\(label(for: resolved.kind)) · \(PlateTimeFormat.time(resolved.time, in: timeZone))"
    }

    /// The spoken form. VoiceOver reads a middot as "middle dot", so the
    /// separator becomes a comma and the label becomes a word.
    static func spoken(
        masjid: MyMasjidSnapshot?,
        prayer: Prayer,
        adhan: Date,
        timeZone: TimeZone
    ) -> String? {
        guard let resolved = IqamahResolver.resolved(
            masjid: masjid, prayer: prayer, adhan: adhan, timeZone: timeZone
        ) else {
            return nil
        }
        let name = resolved.kind == .khutbah ? "Khutbah" : "Iqamah"
        return "\(name), \(PlateTimeFormat.time(resolved.time, in: timeZone))"
    }

    private static func label(for kind: IqamahKind) -> String {
        switch kind {
        case .iqamah: "IQAMAH"
        case .khutbah: "KHUTBAH"
        }
    }
}
