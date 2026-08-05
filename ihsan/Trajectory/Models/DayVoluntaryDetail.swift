import Foundation
import IhsanCore

/// What one cycle holds beyond its five fardh: the voluntary prayers
/// recorded in it, and the sittings at the tasbīḥ.
///
/// Facts, in the order they were offered in — never figures. There is
/// no count of kinds here, no share of anything, and nothing that
/// could be totalled across days. The pattern card says a day carried
/// voluntary worship; this says WHAT, for the one day a person asked
/// about, and stops there.
struct DayVoluntaryDetail: Equatable, Sendable {

    /// One sitting: what was said, and how far it was counted.
    struct Sitting: Equatable, Sendable, Identifiable {
        let id: UUID
        let label: String
        let count: Int
    }

    var naflKinds: [NaflKind] = []
    var sittings: [Sitting] = []

    var isEmpty: Bool { naflKinds.isEmpty && sittings.isEmpty }

    /// Build the per-cycle detail for a window of days.
    ///
    /// Keyed by the cycle date — the same key the records themselves
    /// carry — so a night act offered after midnight appears under the
    /// evening it belongs to, exactly where the pattern card marks it.
    static func index(
        naflLogs: [NaflLog],
        dhikrSessions: [DhikrSession],
        calendar: Calendar = .current
    ) -> [Date: DayVoluntaryDetail] {
        var index: [Date: DayVoluntaryDetail] = [:]

        for log in naflLogs.sorted(by: { $0.loggedAt < $1.loggedAt }) {
            guard let kind = log.kind else { continue }
            let day = calendar.startOfDay(for: log.naflDate)
            index[day, default: DayVoluntaryDetail()].naflKinds.append(kind)
        }

        for session in dhikrSessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let day = calendar.startOfDay(for: session.sessionDate)
            index[day, default: DayVoluntaryDetail()].sittings.append(
                Sitting(id: session.id, label: session.displayLabel, count: session.count)
            )
        }

        return index
    }

    /// The spoken form, for the row that carries this detail.
    var spokenSummary: String {
        var parts: [String] = []
        if !naflKinds.isEmpty {
            parts.append(
                "Voluntary prayer: " + naflKinds.map(\.displayNameEnglish)
                    .joined(separator: ", ")
            )
        }
        if !sittings.isEmpty {
            parts.append(
                "Remembrance: " + sittings
                    .map { "\($0.label), \($0.count)" }
                    .joined(separator: "; ")
            )
        }
        return parts.joined(separator: ". ")
    }
}
