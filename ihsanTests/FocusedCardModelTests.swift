import Foundation
import IhsanCore
import Testing
@testable import ihsan

@Suite("FocusedCardModel")
struct FocusedCardModelTests {

    private let timeZone = TimeZone(identifier: "America/Chicago")!
    private let scheduled = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private var windowEnd: Date { scheduled.addingTimeInterval(3 * 3600) }

    // MARK: - Phase resolution at boundaries

    @Test
    func upcomingUntilTheExactOpeningInstant() {
        let before = FocusedCardModel.resolve(
            scheduledTime: scheduled, windowEndTime: windowEnd,
            isInWindow: false, isLogged: false,
            now: scheduled.addingTimeInterval(-1)
        )
        #expect(before == .upcoming(opensAt: scheduled))

        // At the opening instant the resolver upstream flips
        // isInWindow; the model then reports active — atomically.
        let at = FocusedCardModel.resolve(
            scheduledTime: scheduled, windowEndTime: windowEnd,
            isInWindow: true, isLogged: false,
            now: scheduled
        )
        #expect(at == .active(until: windowEnd))
    }

    @Test
    func windowClosesAtTheExactEndInstant() {
        let justBefore = FocusedCardModel.resolve(
            scheduledTime: scheduled, windowEndTime: windowEnd,
            isInWindow: true, isLogged: false,
            now: windowEnd.addingTimeInterval(-1)
        )
        #expect(justBefore == .active(until: windowEnd))

        // Even if the caller's isInWindow is stale by one frame, the
        // model refuses to stay active at or past the end.
        let atEnd = FocusedCardModel.resolve(
            scheduledTime: scheduled, windowEndTime: windowEnd,
            isInWindow: true, isLogged: false,
            now: windowEnd
        )
        #expect(atEnd == .windowClosed(at: windowEnd))
    }

    /// Corrective G, phase 1: the never-early property at the card.
    /// For ANY now earlier than the prayer's start, the resolved
    /// phase is `.upcoming` — across every combination of the other
    /// inputs, including a stale or wrong `isInWindow` flag and a
    /// missing or inconsistent window end. "Isha · NOW" twenty-two
    /// minutes before Isha is unrepresentable.
    @Test
    func neverActiveBeforeTheStartWhateverTheFlagsSay() {
        var state: UInt64 = 0x0426_1A5F
        func nextUnit() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }

        for _ in 0..<200 {
            let start = Date(
                timeIntervalSinceReferenceDate: 700_000_000 + nextUnit() * 200_000_000
            )
            // now strictly before the start: from one second to a week.
            let now = start.addingTimeInterval(-1 - nextUnit() * 604_800)
            let end: Date? = nextUnit() < 0.2
                ? nil
                : start.addingTimeInterval(-3600 + nextUnit() * 4 * 86_400)
            let phase = FocusedCardModel.resolve(
                scheduledTime: start,
                windowEndTime: end,
                isInWindow: nextUnit() < 0.5,
                isLogged: false,
                now: now
            )
            #expect(phase == .upcoming(opensAt: start))
        }
    }

    @Test
    func loggedWinsOverEverything() {
        let phase = FocusedCardModel.resolve(
            scheduledTime: scheduled, windowEndTime: windowEnd,
            isInWindow: true, isLogged: true,
            now: scheduled.addingTimeInterval(60)
        )
        #expect(phase == .logged)
    }

    // MARK: - Countdown can never rest at zero

    @Test
    func countdownRoundsUpAndNeverShowsZero() {
        let target = scheduled
        #expect(FocusedCardModel.countdown(until: target, now: target.addingTimeInterval(-0.4)) == "0:00:01")
        #expect(FocusedCardModel.countdown(until: target, now: target.addingTimeInterval(-1.0)) == "0:00:01")
        #expect(FocusedCardModel.countdown(until: target, now: target.addingTimeInterval(-3661)) == "1:01:01")
        // Defensive floor: even a degenerate zero-or-negative remainder
        // renders one second, never a resting zero.
        #expect(FocusedCardModel.countdown(until: target, now: target) != "0:00:00")
    }

    // MARK: - Copy rule: describe the window, not the user

    @Test
    func activeCopyDescribesTheWindow() {
        let text = FocusedCardModel.inscription(
            for: .active(until: windowEnd),
            status: nil, loggedAt: nil, isJamaah: false,
            windowEndTime: windowEnd, scheduledTime: scheduled,
            now: scheduled.addingTimeInterval(60), timeZone: timeZone
        )
        #expect(text.uppercased().contains("NOW · UNTIL"))
        #expect(!text.uppercased().contains("PRAYING"))
    }

    @Test
    func upcomingCopyTicksAsAnInscription() {
        let text = FocusedCardModel.inscription(
            for: .upcoming(opensAt: scheduled),
            status: nil, loggedAt: nil, isJamaah: false,
            windowEndTime: windowEnd, scheduledTime: scheduled,
            now: scheduled.addingTimeInterval(-125), timeZone: timeZone
        )
        #expect(text.uppercased().hasPrefix("OPENS IN"))
        #expect(text.contains("0:02:05"))
    }

    /// The logged line shows when the prayer was logged — a stored
    /// fact — never the render clock.
    @Test
    func loggedCopyUsesTheStoredLogTime() {
        let loggedAt = scheduled.addingTimeInterval(600)
        let text = FocusedCardModel.inscription(
            for: .logged,
            status: .onTime, loggedAt: loggedAt, isJamaah: true,
            windowEndTime: windowEnd, scheduledTime: scheduled,
            now: scheduled.addingTimeInterval(9_999), timeZone: timeZone
        )
        #expect(text.contains(PlateTimeFormat.time(loggedAt, in: timeZone)))
        // One romanization app-wide — the inscription must carry the
        // vocabulary's canonical form, never a local respelling.
        #expect(text.uppercased().contains(IhsanVocabulary.jamaahInscription))
        #expect(!text.uppercased().contains("PRAYING"))
        // Corrective E item 6: the logged line renders loggedAt — the
        // prayer's scheduled time must never be mislabeled as the log
        // stamp.
        #expect(!text.contains(PlateTimeFormat.time(scheduled, in: timeZone)))
        #expect(!text.contains(PlateTimeFormat.time(windowEnd, in: timeZone)))
    }
}
