import Foundation

/// The nine readings the Path card is able to reach.
///
/// The split is deliberate. The app decides which reading the ledger
/// actually supports — that is arithmetic over the user's own logs, and
/// it belongs next to the logs. This package decides what may be *said*
/// about a reading once it is reached, which is religious copy and
/// belongs in one reviewable file with its sources attached.
///
/// Nothing here is generated. The on-device model is forbidden from
/// producing religious content (`InsightSystemInstructions`), so every
/// cited line the Path shows is authored, versioned, and listed in
/// `PATH_FIQH_REVIEW.md`.
public enum PathFindingKind: String, Codable, Sendable, CaseIterable {
    /// The period has enough empty slots that no other reading of it
    /// would be honest.
    case unrecordedSlots
    /// Prayers recorded missed outnumber the make-ups recorded against
    /// them.
    case outstandingMakeups
    /// Fajr or ʿIshāʾ is the period's weakest prayer.
    case weakFajrOrIsha
    /// ʿAṣr is the period's weakest prayer.
    case weakAsr
    /// Ẓuhr or Maghrib is the period's weakest prayer.
    case weakOtherPrayer
    /// ʿAṣr is habitually taken at the end of its window.
    case delayedAsr
    /// Another prayer is habitually taken at the end of its window.
    case delayedOtherPrayer
    /// The period holds together, and none of it was in congregation.
    case noJamaah
    /// Nothing in the period is slipping.
    case steady
}

/// Cited context for one Path reading.
///
/// The two registers stay visibly separate on screen: the finding above
/// it counts what the user did, and this explains the category the
/// count belongs to. Neither turns into a ruling about the person.
public struct TrajectoryFindingFraming: Codable, Sendable, Equatable {
    public let kind: PathFindingKind
    public let title: String
    public let body: String
    public let citation: String

    public init(kind: PathFindingKind, title: String, body: String, citation: String) {
        self.kind = kind
        self.title = title
        self.body = body
        self.citation = citation
    }
}

public extension TrajectoryFindingFraming {
    /// The copy that ships in the binary.
    ///
    /// A remote config may replace any entry (`FiqhFraming.trajectoryFindings`),
    /// but it can never leave a reading without grounding — an absent or
    /// partial override falls back here, per kind. That is why the
    /// canonical text lives in Swift rather than in the bundled JSON:
    /// one source, no drift between a compiled default and a shipped
    /// file that says something slightly different.
    static func standard(for kind: PathFindingKind) -> TrajectoryFindingFraming {
        switch kind {
        case .unrecordedSlots:
            TrajectoryFindingFraming(
                kind: kind,
                title: "An empty slot is not a missed prayer",
                body: "Ihsan keeps the two apart on purpose. A slot with no record means nothing was entered and the app does not know what happened. Missed means you told it the prayer was not prayed inside its window. Prayer is fixed on the believers at appointed times, so each slot is a real appointment — but only the ones you fill in can tell you anything.",
                citation: "Qur’an 4:103"
            )

        case .outstandingMakeups:
            TrajectoryFindingFraming(
                kind: kind,
                title: "A missed prayer is repaid by praying it",
                body: "Nothing stands in for it — not ṣadaqah, not extra voluntary prayers. The Prophet said that whoever forgets a prayer or sleeps through it should pray it when he remembers, and that there is no expiation for it except that, then recited: establish prayer for My remembrance. The schools differ over the order and the urgency. They do not differ that it is still owed.",
                citation: "Ṣaḥīḥ al-Bukhārī 597 · Ṣaḥīḥ Muslim 684 · Qur’an 20:14"
            )

        case .weakFajrOrIsha:
            TrajectoryFindingFraming(
                kind: kind,
                title: "These are the two that thin out first",
                body: "It is named directly. The Prophet said no prayer is heavier upon the hypocrites than ʿIshāʾ and Fajr, and that if they knew what was in them they would come even if they had to crawl. The point is not the verdict, it is the diagnosis: these two sit at the edges of sleep, and that is where a record thins first for almost everyone.",
                citation: "Ṣaḥīḥ al-Bukhārī 657"
            )

        case .weakAsr:
            TrajectoryFindingFraming(
                kind: kind,
                title: "ʿAṣr carries an explicit warning",
                body: "Whoever misses ʿAṣr, the Prophet said, is like one who lost his family and property. The same ʿAṣr is one of the two cool prayers, and whoever prays both of them enters Paradise. It falls in the working part of the afternoon, which is exactly why it is the one that gets pushed.",
                citation: "Ṣaḥīḥ al-Bukhārī 552 · Ṣaḥīḥ al-Bukhārī 574"
            )

        case .weakOtherPrayer:
            TrajectoryFindingFraming(
                kind: kind,
                title: "At its time, not merely inside it",
                body: "Asked which deed is most beloved to Allah, the Prophet answered: the prayer at its time. Not somewhere in the window — at its time. Maghrib in particular has the narrowest window of the five, so it is the one most often lost to something that looked like it would take five minutes.",
                citation: "Ṣaḥīḥ al-Bukhārī 527"
            )

        case .delayedAsr:
            TrajectoryFindingFraming(
                kind: kind,
                title: "The prayer of the one who watches the sun",
                body: "Anas ibn Mālik described the hypocrite’s ʿAṣr: he sits watching the sun until it sits between the horns of Shayṭān, then gets up and pecks out four rakʿahs with barely any remembrance of Allah in them. A prayer at the edge of its window is valid and it counts. The report is about making the edge your habit.",
                citation: "Ṣaḥīḥ Muslim 622"
            )

        case .delayedOtherPrayer:
            TrajectoryFindingFraming(
                kind: kind,
                title: "Valid, and still at the edge",
                body: "A prayer performed in the last part of its window counts in full. Ihsan records it as Delayed only so it stays distinguishable from a prayer taken at its time — which is the thing the Prophet named as the deed most beloved to Allah. It is a distinction worth being able to see, not a separate ruling.",
                citation: "Ṣaḥīḥ al-Bukhārī 527 · Qur’an 4:103"
            )

        case .noJamaah:
            TrajectoryFindingFraming(
                kind: kind,
                title: "Twenty-seven to one",
                body: "The Prophet said the prayer in congregation is twenty-seven times superior to the prayer prayed alone; other sound narrations give the figure as twenty-five. Either way it is the largest single multiplier available on something already being done five times a day. The schools differ on whether congregation is obligatory. They do not differ on the reward.",
                citation: "Ṣaḥīḥ al-Bukhārī 645"
            )

        case .steady:
            TrajectoryFindingFraming(
                kind: kind,
                title: "Small and constant beats large and occasional",
                body: "ʿĀʾishah reported that the deeds most beloved to Allah are the ones done most constantly, even when they are few. A record that holds is worth more than one that spikes. So the useful question here is not more prayers — it is the same prayers, with other people.",
                citation: "Ṣaḥīḥ al-Bukhārī 6464"
            )
        }
    }

    /// Every reading's shipped copy, in `PathFindingKind` order.
    static var standard: [TrajectoryFindingFraming] {
        PathFindingKind.allCases.map(standard(for:))
    }
}
