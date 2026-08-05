import Foundation
import IhsanCore

/// The fasting layer's pure day logic: which quiet line the header
/// carries, and which inscription joins the focused-card region.
/// Pure functions of the day's facts — `FastingDayModelTests` pins
/// the offer rules, the pause exclusions, and the tense of every
/// string.
enum FastingDayModel {

    // MARK: - The header line

    /// What the header's quiet line shows today.
    enum HeaderLine: Equatable {
        /// A calendar fact, dismissible for the day with a tap.
        case info(String)
        /// The fact doubling as a gentle offer — one tap records the
        /// intention. Only when the user enabled the rhythm.
        case offer(text: String, kind: FastKind)
    }

    /// Resolve the header line. Offers require the matching rhythm
    /// toggle, no fast recorded yet, and — always — no excused pause:
    /// paused days offer no fasting prompts and record nothing.
    ///
    /// - Parameters:
    ///   - components: the Hijri day in progress, which began at
    ///     Maghrib.
    ///   - weekday: the weekday of the DAYTIME being offered — after
    ///     Maghrib on a Wednesday that is Thursday.
    ///   - isEveningBeforeFast: Maghrib has turned the Hijri day, so
    ///     the daytime being offered is tomorrow's and the line says
    ///     so. Deliberately not "before Fajr": at 3 AM the fast ahead
    ///     is today's by every clock a person uses, and calling it
    ///     tomorrow's would be the app being clever at their expense.
    static func headerLine(
        components: HijriConverter.Components,
        weekday: Int,
        isEveningBeforeFast: Bool,
        isRamadan: Bool,
        monThuOfferEnabled: Bool,
        whiteDaysOfferEnabled: Bool,
        isPaused: Bool,
        hasFastToday: Bool,
        dismissedForToday: Bool
    ) -> HeaderLine? {
        // Ramadan carries its own row in the card region; the header
        // stays quiet for the month.
        guard !isRamadan else { return nil }

        let significance = HijriConverter.significance(of: components).first

        if !isPaused, !hasFastToday {
            if whiteDaysOfferEnabled, significance == .whiteDay {
                return .offer(
                    text: offerText("White day", isEveningBeforeFast: isEveningBeforeFast),
                    kind: .whiteDay
                )
            }
            if monThuOfferEnabled, let name = weekdayName(weekday) {
                return .offer(
                    text: offerText(name, isEveningBeforeFast: isEveningBeforeFast),
                    kind: .monThu
                )
            }
        }

        if let significance, !dismissedForToday {
            return .info(significance.inscription(for: components).uppercased())
        }
        return nil
    }

    /// Monday and Thursday are the only two the rhythm names.
    private static func weekdayName(_ weekday: Int) -> String? {
        switch weekday {
        case 2: return "Monday"
        case 5: return "Thursday"
        default: return nil
        }
    }

    /// The offer's two registers. At night the fast being intended is
    /// tomorrow's and the line says so; from Fajr onward it is the day
    /// underway.
    private static func offerText(_ subject: String, isEveningBeforeFast: Bool) -> String {
        isEveningBeforeFast
            ? "Tomorrow's fast · \(subject)".uppercased()
            : "\(subject) · Fast?".uppercased()
    }

    // MARK: - The fasting inscription

    /// What the inscription row in the focused-card region shows, and
    /// what a tap on it does.
    enum Inscription: Equatable {
        /// A fact, nothing to tap.
        case fact(String)
        /// The Ramadan offer: one tap records the day's fast, kept.
        case ramadanOffer(String)
        /// An intention whose day has reached iftar: one tap records
        /// it kept. (An untapped intention simply expires — nothing
        /// negative exists to record.)
        case keptCompletion(String)
    }

    /// Resolve the inscription. Maghrib is iftar; Fajr is suhoor's
    /// end — before Fajr the suhoor line shows. Present whenever the
    /// day carries a fast (intended or kept), and always during
    /// Ramadan; absent on excused-pause days unless a fast is
    /// already recorded.
    static func inscription(
        state: FastState?,
        isRamadan: Bool,
        isPaused: Bool,
        isEveningBeforeFast: Bool = false,
        now: Date,
        fajr: Date,
        maghrib: Date,
        timeZone: TimeZone
    ) -> Inscription? {
        let timeline = now < fajr
            ? "Suhoor ends \(PlateTimeFormat.time(fajr, in: timeZone))"
            : "Iftar \(PlateTimeFormat.time(maghrib, in: timeZone))"
        let subject = isEveningBeforeFast ? "Fasting tomorrow?" : "Fasting today?"

        if let state {
            if state == .intended, now >= maghrib {
                return .keptCompletion("Fast kept?".uppercased())
            }
            return .fact("Fasting · \(timeline)".uppercased())
        }

        // No fast recorded. Ramadan keeps its inscriptions present
        // and offers the day's fast — except on excused-pause days,
        // which offer nothing.
        guard isRamadan, !isPaused else { return nil }
        if now < maghrib {
            return .ramadanOffer("\(subject) · \(timeline)".uppercased())
        }
        return .ramadanOffer("\(subject) · Ramadan".uppercased())
    }
}
