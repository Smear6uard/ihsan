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
        #expect(text.uppercased().contains("JAMĀ'AH"))
        #expect(!text.uppercased().contains("PRAYING"))
    }
}
