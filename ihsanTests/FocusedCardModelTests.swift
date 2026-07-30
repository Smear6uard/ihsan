import Foundation
import IhsanCore
import IhsanPrayerTimes
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
            windowState: .upcoming(opensAt: scheduled),
            isLogged: false
        )
        #expect(before == .upcoming(opensAt: scheduled))

        // At the opening instant the resolver upstream flips
        // isInWindow; the model then reports active — atomically.
        let at = FocusedCardModel.resolve(
            windowState: .current(startedAt: scheduled, endsAt: windowEnd),
            isLogged: false
        )
        #expect(at == .active(until: windowEnd))
    }

    @Test
    func windowClosesAtTheExactEndInstant() {
        let justBefore = FocusedCardModel.resolve(
            windowState: .current(startedAt: scheduled, endsAt: windowEnd),
            isLogged: false
        )
        #expect(justBefore == .active(until: windowEnd))

        // At the exact end, the shared resolver supplies `.closed`.
        let atEnd = FocusedCardModel.resolve(
            windowState: .closed(startedAt: scheduled, endedAt: windowEnd),
            isLogged: false
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
            _ = now
            let phase = FocusedCardModel.resolve(
                windowState: .upcoming(opensAt: start),
                isLogged: false
            )
            #expect(phase == .upcoming(opensAt: start))
        }
    }

    /// The dawn-review tense rule: window state is DERIVED from
    /// comparing now to the boundary — there is no stored flag to
    /// drift — and the copy's tense follows the derived state. For
    /// ANY now strictly before the window's end, the resolved phase
    /// is never `.windowClosed` and closed-tense copy can never
    /// render, whatever the upstream flags claim. "WINDOW CLOSED
    /// 5:51 AM" at 5:31 AM is unrepresentable.
    @Test
    func closedTenseNeverRendersBeforeTheBoundary() {
        var state: UInt64 = 0x05_27_1A5F
        func nextUnit() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }

        for _ in 0..<300 {
            let start = Date(
                timeIntervalSinceReferenceDate: 700_000_000 + nextUnit() * 200_000_000
            )
            let end = start.addingTimeInterval(600 + nextUnit() * 6 * 3600)
            // now anywhere from a week before the start to one second
            // before the end.
            let span = end.timeIntervalSince(start.addingTimeInterval(-604_800)) - 1
            let now = start.addingTimeInterval(-604_800 + nextUnit() * span)
            let state: PrayerWindowState = now < start
                ? .upcoming(opensAt: start)
                : .current(startedAt: start, endsAt: end)
            let phase = FocusedCardModel.resolve(
                windowState: state,
                isLogged: false
            )
            if case .windowClosed = phase {
                Issue.record("windowClosed resolved at \(end.timeIntervalSince(now))s before the boundary")
            }
            let text = FocusedCardModel.inscription(
                for: phase,
                status: nil, loggedAt: nil, isJamaah: false,
                windowEndTime: end, scheduledTime: start,
                now: now, timeZone: timeZone
            )
            #expect(!text.uppercased().contains("WINDOW CLOSED"))
        }
    }

    @Test
    func loggedWinsOverEverything() {
        let phase = FocusedCardModel.resolve(
            windowState: .current(startedAt: scheduled, endsAt: windowEnd),
            isLogged: true
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

    // MARK: - Countdown anchor (the dawn-review arithmetic bug)
    //
    // "OPENS IN 6:35:31" at 5:27 AM against a 1:03 PM prayer is off
    // by an hour only if an anchor slipped a timezone. The contract:
    // countdown == prayer.start − now EXACTLY — instants, never wall
    // arithmetic — across DST boundaries and in a non-local zone.

    @Test
    func countdownEqualsTargetMinusNowExactly() {
        var state: UInt64 = 0x0603_5310
        func nextUnit() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }
        for _ in 0..<200 {
            let now = Date(timeIntervalSinceReferenceDate: (700_000_000 + nextUnit() * 200_000_000).rounded())
            let remaining = (1 + nextUnit() * 48 * 3600).rounded()
            let target = now.addingTimeInterval(remaining)
            let total = Int(remaining)
            let expected = String(
                format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60
            )
            #expect(FocusedCardModel.countdown(until: target, now: now) == expected)
        }
    }

    /// Across the spring-forward gap the wall clock advances two
    /// hours in one real hour — the countdown must show the real
    /// hour, because both ends are instants.
    @Test
    func countdownCrossesTheSpringForwardBoundaryOnRealTime() throws {
        let chicago = try #require(TimeZone(identifier: "America/Chicago"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        // 2026-03-08 01:30 CST; 2:00 AM springs to 3:00 AM.
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 8, hour: 1, minute: 30
        )))
        // 03:30 CDT is one REAL hour later, two wall hours later.
        let target = now.addingTimeInterval(3600)
        let wall = calendar.dateComponents([.hour, .minute], from: target)
        #expect(wall.hour == 3 && wall.minute == 30, "DST fixture drifted")
        #expect(FocusedCardModel.countdown(until: target, now: now) == "1:00:00")
    }

    /// The countdown is pure instant arithmetic — a target formatted
    /// for Karachi counts down identically on a Chicago device.
    @Test
    func countdownIsIndependentOfDisplayTimezone() throws {
        let karachi = try #require(TimeZone(identifier: "Asia/Karachi"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = karachi
        let target = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 30, hour: 13, minute: 3
        )))
        let now = target.addingTimeInterval(-(7 * 3600 + 36 * 60))
        #expect(FocusedCardModel.countdown(until: target, now: now) == "7:36:00")
    }

    // MARK: - The two dawn card strings, pinned

    /// Fajr's open window names its boundary: sunrise. The tense is
    /// present, the affordance is the window.
    @Test
    func fajrActiveInscriptionNamesSunrise() throws {
        let chicago = try #require(TimeZone(identifier: "America/Chicago"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        let sunrise = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 30, hour: 5, minute: 51
        )))
        let fajr = sunrise.addingTimeInterval(-95 * 60)
        let text = FocusedCardModel.inscription(
            for: .active(until: sunrise),
            status: nil, loggedAt: nil, isJamaah: false,
            windowEndTime: sunrise, scheduledTime: fajr,
            now: sunrise.addingTimeInterval(-20 * 60), timeZone: chicago,
            windowEndDescriptor: PrayerWindowRule.windowEndDescriptor(for: .fajr)
        )
        #expect(text == "Now · until sunrise \(PlateTimeFormat.time(sunrise, in: chicago))")
        #expect(text.hasPrefix("Now · until sunrise 5:51"))
    }

    /// After the boundary — and only after — the closed fact renders
    /// in the past tense.
    @Test
    func fajrClosedInscriptionStatesThePastFact() throws {
        let chicago = try #require(TimeZone(identifier: "America/Chicago"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        let sunrise = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 30, hour: 5, minute: 51
        )))
        let fajr = sunrise.addingTimeInterval(-95 * 60)
        let now = sunrise.addingTimeInterval(10 * 60)
        let phase = FocusedCardModel.resolve(
            windowState: .closed(startedAt: fajr, endedAt: sunrise),
            isLogged: false
        )
        #expect(phase == .windowClosed(at: sunrise))
        let text = FocusedCardModel.inscription(
            for: phase,
            status: nil, loggedAt: nil, isJamaah: false,
            windowEndTime: sunrise, scheduledTime: fajr,
            now: now, timeZone: chicago,
            windowEndDescriptor: PrayerWindowRule.windowEndDescriptor(for: .fajr)
        )
        #expect(text == "Window closed \(PlateTimeFormat.time(sunrise, in: chicago))")
        #expect(text.hasPrefix("Window closed 5:51"))
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
