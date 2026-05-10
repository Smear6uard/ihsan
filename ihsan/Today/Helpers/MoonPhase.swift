import Foundation

/// Computes the moon's phase for a given date.
///
/// The astronomical phase is approximated from days elapsed since a
/// reference new moon (2000-01-06 18:14 UTC). Accurate to within a
/// fraction of a day for any date within the next century — far more
/// precision than the eight-bucket SF Symbol mapping needs.
enum MoonPhase {
    /// Eight conventional phase buckets, ordered around the synodic
    /// month. The names match the SF Symbol moonphase variants.
    enum Bucket: Sendable {
        case newMoon
        case waxingCrescent
        case firstQuarter
        case waxingGibbous
        case fullMoon
        case waningGibbous
        case lastQuarter
        case waningCrescent

        /// The SF Symbol name for this phase. iOS 26 ships these as
        /// monochrome-compatible filled glyphs.
        var symbolName: String {
            switch self {
            case .newMoon: return "moonphase.new.moon"
            case .waxingCrescent: return "moonphase.waxing.crescent"
            case .firstQuarter: return "moonphase.first.quarter"
            case .waxingGibbous: return "moonphase.waxing.gibbous"
            case .fullMoon: return "moonphase.full.moon"
            case .waningGibbous: return "moonphase.waning.gibbous"
            case .lastQuarter: return "moonphase.last.quarter"
            case .waningCrescent: return "moonphase.waning.crescent"
            }
        }

        /// One-word spoken label for VoiceOver.
        var spokenLabel: String {
            switch self {
            case .newMoon: return "New moon"
            case .waxingCrescent: return "Waxing crescent"
            case .firstQuarter: return "First quarter"
            case .waxingGibbous: return "Waxing gibbous"
            case .fullMoon: return "Full moon"
            case .waningGibbous: return "Waning gibbous"
            case .lastQuarter: return "Last quarter"
            case .waningCrescent: return "Waning crescent"
            }
        }
    }

    /// Reference new moon: 2000-01-06 18:14 UTC. Standard astronomical
    /// anchor — used widely in moon-phase libraries.
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// Mean synodic month in days.
    private static let synodicMonth: Double = 29.530_588_853

    /// Fraction of the synodic month that has elapsed at `date`, in
    /// `[0.0, 1.0)`. 0 = new moon, 0.5 = full moon.
    static func phaseFraction(at date: Date = .now) -> Double {
        let elapsedDays = date.timeIntervalSince(referenceNewMoon) / 86_400
        let fraction = elapsedDays / synodicMonth
        let wrapped = fraction.truncatingRemainder(dividingBy: 1.0)
        return wrapped < 0 ? wrapped + 1.0 : wrapped
    }

    /// Maps the phase fraction to one of the eight conventional buckets.
    /// Each bucket spans 1/8th of the cycle (3.69 days).
    static func bucket(at date: Date = .now) -> Bucket {
        let fraction = phaseFraction(at: date)
        // Eight evenly-spaced buckets centred on the four cardinal phases.
        let normalized = (fraction + 1.0 / 16.0).truncatingRemainder(dividingBy: 1.0)
        let index = Int(normalized * 8) % 8
        switch index {
        case 0: return .newMoon
        case 1: return .waxingCrescent
        case 2: return .firstQuarter
        case 3: return .waxingGibbous
        case 4: return .fullMoon
        case 5: return .waningGibbous
        case 6: return .lastQuarter
        default: return .waningCrescent
        }
    }
}
