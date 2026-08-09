import Foundation

/// One prayer's iqamah, as the person entered it.
///
/// A fixed time is stored as **minutes from local midnight**, never as an
/// instant. A board on a masjid wall reading 1:30 PM means 1:30 PM — civil
/// wall-clock time. An instant would need a stored timezone to interpret
/// and would drift the moment the user travels or the region shifts for
/// DST; minutes-from-midnight needs nothing and cannot drift.
public struct IqamahEntry: Codable, Sendable, Equatable {

    public enum Mode: String, Codable, Sendable {
        /// No iqamah recorded for this prayer. It renders nowhere.
        case none
        /// A wall-clock time read off the masjid's board.
        case fixed
        /// A duration after this day's calculated adhan.
        case offset
    }

    public var prayer: Prayer
    public var mode: Mode
    /// Minutes from local midnight, `0..<1440`. Meaningful only in `.fixed`.
    public var fixedMinutesFromMidnight: Int?
    /// Minutes AFTER the adhan. Meaningful only in `.offset`.
    public var offsetMinutes: Int?
    /// Whether this prayer's iqamah reminder is armed. The lead time itself
    /// is shared across the masjid and lives on `MyMasjid` — someone thinks
    /// about their journey there once, not five times.
    public var reminderEnabled: Bool

    public init(
        prayer: Prayer,
        mode: Mode = .none,
        fixedMinutesFromMidnight: Int? = nil,
        offsetMinutes: Int? = nil,
        reminderEnabled: Bool = false
    ) {
        self.prayer = prayer
        self.mode = mode
        self.fixedMinutesFromMidnight = fixedMinutesFromMidnight
        self.offsetMinutes = offsetMinutes
        self.reminderEnabled = reminderEnabled
    }

    /// Decoded leniently so a payload written by an earlier build still
    /// reads, rather than discarding times someone typed in by hand.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prayer = try container.decode(Prayer.self, forKey: .prayer)
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .none
        fixedMinutesFromMidnight = try container.decodeIfPresent(
            Int.self, forKey: .fixedMinutesFromMidnight
        )
        offsetMinutes = try container.decodeIfPresent(Int.self, forKey: .offsetMinutes)
        reminderEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .reminderEnabled
        ) ?? false
    }

    /// True when this entry would render a time somewhere. A mode without
    /// its value is a half-finished edit, not a time.
    public var isSet: Bool {
        switch mode {
        case .none: false
        case .fixed: fixedMinutesFromMidnight != nil
        case .offset: offsetMinutes != nil
        }
    }
}
