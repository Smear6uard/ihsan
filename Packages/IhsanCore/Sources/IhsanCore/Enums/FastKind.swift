import Foundation

/// Why a day was fasted — calendar facts from the curated static
/// data, plus the free `other`. String-backed so future kinds can be
/// added without breaking stored data.
///
/// The app marks nothing as obligatory beyond Ramadan's
/// well-established status; every voluntary kind is offered, never
/// pushed.
public enum FastKind: String, Codable, CaseIterable, Sendable {
    case ramadan
    case qada
    case monThu
    case whiteDay
    case arafah
    case ashura
    case shawwal
    case other

    public var displayNameEnglish: String {
        switch self {
        case .ramadan: return "Ramadan"
        case .qada: return "Qadā fast"
        case .monThu: return "Monday/Thursday"
        case .whiteDay: return "White day"
        case .arafah: return "Day of ʿArafah"
        case .ashura: return "ʿAshura"
        case .shawwal: return "Six of Shawwal"
        case .other: return "Fast"
        }
    }
}

/// A fast's simple state. An intention that passes unkept simply
/// expires — it stays `intended` on a past day, which every surface
/// reads as nothing. There is no negative state, deliberately: no
/// "broken", no "failed", ever.
public enum FastState: String, Codable, CaseIterable, Sendable {
    /// Recorded ahead of the day (the niyyah for tomorrow).
    case intended
    /// The fast was kept.
    case kept
}
