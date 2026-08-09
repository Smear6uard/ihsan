import Foundation
import Testing
@testable import IhsanFiqhConfig

/// The Path card's cited context.
///
/// This is the only religious copy on the screen — the finding above it
/// is arithmetic and the on-device model is barred from the register
/// entirely. So the invariants are about completeness and attribution:
/// every reading the app can reach has text, every piece of text names
/// its source, and no override can strip either.
@Suite("Path finding grounding")
struct PathFindingGroundingTests {

    @Test("Every reading ships with a title, a body and a citation")
    func everyKindIsGrounded() {
        for kind in PathFindingKind.allCases {
            let framing = TrajectoryFindingFraming.standard(for: kind)
            #expect(framing.kind == kind, "\(kind) is keyed to the wrong reading")
            #expect(!framing.title.trimmingCharacters(in: .whitespaces).isEmpty)
            #expect(framing.body.count >= 80, "\(kind) body is too thin to be worth expanding")
            #expect(framing.body.count <= 900, "\(kind) body is longer than a disclosure should be")
            #expect(!framing.citation.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    /// A claim about the religion carries its reference or it does not
    /// ship. Every citation must name a collection and a number, or a
    /// sura and an ayah.
    @Test("Every citation resolves to a locatable source")
    func citationsAreLocatable() {
        let collections = ["Ṣaḥīḥ al-Bukhārī", "Ṣaḥīḥ Muslim", "Qur’an"]
        for kind in PathFindingKind.allCases {
            let citation = TrajectoryFindingFraming.standard(for: kind).citation
            #expect(
                collections.contains { citation.contains($0) },
                "\(kind) cites no known collection: \(citation)"
            )
            #expect(
                citation.rangeOfCharacter(from: .decimalDigits) != nil,
                "\(kind) cites a collection with no reference number: \(citation)"
            )
        }
    }

    @Test("The shipped set covers every reading exactly once")
    func standardSetIsComplete() {
        let standard = TrajectoryFindingFraming.standard
        #expect(standard.count == PathFindingKind.allCases.count)
        #expect(Set(standard.map(\.kind)).count == standard.count)
    }

    // MARK: - Overrides

    private func framing(findings: [TrajectoryFindingFraming]?) -> FiqhFraming {
        FiqhFraming(
            onTimeLabel: "a", lateLabel: "b", missedLabel: "c", qadaLabel: "d",
            pauseModeTitle: "e", pauseModeDescription: "f",
            travelModeTitle: "g", travelModeDescription: "h",
            reflectionEmptyTitle: "i", reflectionEmptySubtitle: "j",
            trajectoryEmptyTitle: "k", trajectoryEmptySubtitle: "l",
            trajectoryFindings: findings
        )
    }

    @Test("A config that carries no overrides falls back to the shipped text")
    func absentOverridesFallBack() {
        let resolved = framing(findings: nil).findingFraming(for: .weakAsr)
        #expect(resolved == TrajectoryFindingFraming.standard(for: .weakAsr))
    }

    @Test("A complete override wins")
    func completeOverrideIsHonoured() {
        let override = TrajectoryFindingFraming(
            kind: .weakAsr,
            title: "Corrected title",
            body: "Corrected body",
            citation: "Ṣaḥīḥ al-Bukhārī 552"
        )
        let resolved = framing(findings: [override]).findingFraming(for: .weakAsr)
        #expect(resolved == override)
        // An override for one reading leaves the others alone.
        #expect(
            framing(findings: [override]).findingFraming(for: .steady)
                == TrajectoryFindingFraming.standard(for: .steady)
        )
    }

    /// A remote config can correct this copy but it can never leave a
    /// finding standing on nothing — an entry stripped of its citation
    /// is rejected in favour of the reviewed text.
    @Test("A hollowed-out override is refused")
    func incompleteOverrideIsRefused() {
        let hollowed = [
            TrajectoryFindingFraming(kind: .noJamaah, title: "T", body: "B", citation: "   "),
            TrajectoryFindingFraming(kind: .steady, title: "  ", body: "B", citation: "C"),
            TrajectoryFindingFraming(kind: .weakAsr, title: "T", body: "", citation: "C"),
        ]
        for kind in [PathFindingKind.noJamaah, .steady, .weakAsr] {
            #expect(
                framing(findings: hollowed).findingFraming(for: kind)
                    == TrajectoryFindingFraming.standard(for: kind),
                "\(kind) accepted an override with a missing field"
            )
        }
    }

    /// Schema 1 configs — every one shipped or cached so far — carry no
    /// `trajectoryFindings` key at all. Decoding must survive that.
    @Test("A config written before this field existed still decodes")
    func olderPayloadsStillDecode() throws {
        let json = """
        {
          "onTimeLabel": "On Time", "lateLabel": "Delayed",
          "missedLabel": "Missed", "qadaLabel": "Qada",
          "pauseModeTitle": "Pause", "pauseModeDescription": "d",
          "travelModeTitle": "Travel", "travelModeDescription": "d",
          "reflectionEmptyTitle": "t", "reflectionEmptySubtitle": "s",
          "trajectoryEmptyTitle": "t", "trajectoryEmptySubtitle": "s"
        }
        """
        let decoded = try JSONDecoder().decode(FiqhFraming.self, from: Data(json.utf8))
        #expect(decoded.trajectoryFindings == nil)
        #expect(
            decoded.findingFraming(for: .outstandingMakeups)
                == TrajectoryFindingFraming.standard(for: .outstandingMakeups)
        )
    }

    @Test("Overrides survive a round trip")
    func overridesRoundTrip() throws {
        let original = framing(findings: TrajectoryFindingFraming.standard)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FiqhFraming.self, from: data)
        #expect(decoded.trajectoryFindings == TrajectoryFindingFraming.standard)
    }
}
