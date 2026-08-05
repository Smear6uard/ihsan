import Foundation

/// The app's one vocabulary for the timing axis.
///
/// Every surface — the log sheet's tiles, the focused card's commits,
/// the Path counts, the yesterday sheet, the watch, the complications,
/// Siri's spoken dialog — reads these instead of spelling the words
/// locally, so a status can never again mean one thing on one screen
/// and something else on another.
///
/// ## The distinction these words carry
///
/// The four timings describe one window, and where the prayer fell
/// relative to it:
///
/// - **On Time** — prayed in its window.
/// - **Delayed** — prayed in its window, but late in it. Still adā',
///   still inside the waqt; the Hanafi concern here is the latter
///   portion of the window, not a missed one.
/// - **Qadā** — prayed after the window closed. A make-up.
/// - **Missed** — the window passed and the prayer was not offered.
///
/// On Time and Delayed are *both inside* the window; the single word
/// LATE in Delayed's caption carries the entire difference between
/// them. Qadā is the one that happens *after*.
///
/// This is written down because it was once wrong: `Late` read "PRAYED
/// AFTER ITS WINDOW" while `Qadā` read "MADE UP LATER" — two phrasings
/// of the same fact, with the real distinction stated nowhere.
/// `PrayerStatusVocabularyTests` holds the line.
///
/// ## Why the case is still called `late`
///
/// `PrayerStatus.late.rawValue` is `"late"`, and it is persisted in
/// SwiftData, mirrored into CloudKit, and written into widget snapshot
/// payloads. Renaming the case would buy a nicer identifier at the cost
/// of a schema migration over every historical row. The stored name
/// stays; only the words a person reads changed.
extension PrayerStatus {

    /// Title case, for tiles, buttons, and chips: "Delayed".
    public var displayName: String {
        switch self {
        case .onTime: "On Time"
        case .late: "Delayed"
        case .qada: "Qadā"
        case .missed: "Missed"
        }
    }

    /// The small-caps inscription register: "DELAYED".
    public var inscription: String { displayName.uppercased() }

    /// The one-line explanation beneath a name. Four phrases about one
    /// window, deliberately parallel, so the difference between any two
    /// of them is the words that differ and nothing else.
    public var caption: String {
        switch self {
        case .onTime: "PRAYED IN ITS WINDOW"
        case .late: "PRAYED LATE IN ITS WINDOW"
        case .qada: "PRAYED AFTER ITS WINDOW"
        case .missed: "ITS WINDOW PASSED UNPRAYED"
        }
    }

    /// Mid-sentence, for VoiceOver and spoken dialog: "Fajr prayer,
    /// logged, in jamāʿah, delayed".
    ///
    /// The bare word, with no connective. A caller that wants "logged
    /// as delayed" or "3 qadā" supplies its own grammar around it —
    /// baking "as" in here made every count read "1 as qadā".
    public var spokenLabel: String {
        switch self {
        case .onTime: "on time"
        case .late: "delayed"
        case .qada: "qadā"
        case .missed: "missed"
        }
    }
}
