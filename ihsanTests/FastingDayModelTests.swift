import Foundation
import IhsanCore
import Testing
@testable import ihsan

/// The fasting layer's day logic, pinned: offers appear only behind
/// their toggles, never on paused days, never over an existing fast;
/// the inscription follows suhoor/iftar by the real schedule; and no
/// negative state can be expressed anywhere.
@Suite("Fasting day model")
struct FastingDayModelTests {

    private let timeZone = TimeZone(identifier: "America/Chicago")!

    private func whiteDay(_ day: Int = 14) -> HijriConverter.Components {
        .init(year: 1448, month: 2, day: day)
    }

    private func plainDay() -> HijriConverter.Components {
        .init(year: 1448, month: 2, day: 5)
    }

    private func line(
        components: HijriConverter.Components,
        weekday: Int = 3,
        evening: Bool = false,
        isRamadan: Bool = false,
        monThu: Bool = false,
        whiteDays: Bool = false,
        paused: Bool = false,
        hasFast: Bool = false,
        dismissed: Bool = false
    ) -> FastingDayModel.HeaderLine? {
        FastingDayModel.headerLine(
            components: components,
            weekday: weekday,
            isEveningBeforeFast: evening,
            isRamadan: isRamadan,
            monThuOfferEnabled: monThu,
            whiteDaysOfferEnabled: whiteDays,
            isPaused: paused,
            hasFastToday: hasFast,
            dismissedForToday: dismissed
        )
    }

    // MARK: - Offers are opt-in and quiet

    @Test
    func whiteDayLineIsInformationalUntilTheRhythmIsEnabled() {
        #expect(line(components: whiteDay()) == .info("WHITE DAY · SAFAR 14"))
        #expect(line(components: whiteDay(), whiteDays: true)
            == .offer(text: "WHITE DAY · FAST?", kind: .whiteDay))
    }

    @Test
    func monThuOffersOnlyOnTheirDays() {
        // Monday (weekday 2) and Thursday (weekday 5), plain month day.
        #expect(line(components: plainDay(), weekday: 2, monThu: true)
            == .offer(text: "MONDAY · FAST?", kind: .monThu))
        #expect(line(components: plainDay(), weekday: 5, monThu: true)
            == .offer(text: "THURSDAY · FAST?", kind: .monThu))
        #expect(line(components: plainDay(), weekday: 3, monThu: true) == nil)
        // Toggle off: no offer, and a plain day has no info either.
        #expect(line(components: plainDay(), weekday: 2) == nil)
    }

    /// Clock 2: the Hijri day begins at Maghrib, so a Thursday fast is
    /// offered from Wednesday evening — in the evening's own register,
    /// because that is when the intention for it is made.
    @Test
    func theEveningBeforeOffersTheComingFast() {
        #expect(
            line(components: plainDay(), weekday: 5, evening: true, monThu: true)
                == .offer(text: "TOMORROW'S FAST · THURSDAY", kind: .monThu)
        )
        #expect(
            line(components: whiteDay(), evening: true, whiteDays: true)
                == .offer(text: "TOMORROW'S FAST · WHITE DAY", kind: .whiteDay)
        )
        // And from Fajr onward the day-of wording returns.
        #expect(
            line(components: plainDay(), weekday: 5, monThu: true)
                == .offer(text: "THURSDAY · FAST?", kind: .monThu)
        )
    }

    // MARK: - Excused pause offers nothing

    /// Paused days generate no fasting prompts: with every rhythm
    /// enabled, the offer never renders — the calendar fact may.
    @Test
    func pausedDaysNeverOffer() {
        let paused = line(
            components: whiteDay(), weekday: 2,
            monThu: true, whiteDays: true, paused: true
        )
        #expect(paused == .info("WHITE DAY · SAFAR 14"))
        #expect(line(components: plainDay(), weekday: 2, monThu: true, paused: true) == nil)
    }

    @Test
    func anExistingFastSilencesTheOffer() {
        #expect(line(components: whiteDay(), whiteDays: true, hasFast: true)
            == .info("WHITE DAY · SAFAR 14"))
    }

    @Test
    func dismissalSilencesTheInfoLineButNeverBlocksAnOffer() {
        #expect(line(components: whiteDay(), dismissed: true) == nil)
        #expect(line(components: whiteDay(), whiteDays: true, dismissed: true)
            == .offer(text: "WHITE DAY · FAST?", kind: .whiteDay))
    }

    @Test
    func ramadanKeepsTheHeaderQuiet() {
        let ramadanDay = HijriConverter.Components(year: 1448, month: 9, day: 3)
        #expect(line(components: ramadanDay, isRamadan: true, monThu: true, whiteDays: true) == nil)
    }

    // MARK: - The inscription

    private var fajr: Date { Date(timeIntervalSinceReferenceDate: 800_000_000) }
    private var maghrib: Date { fajr.addingTimeInterval(15 * 3600) }

    private func inscription(
        state: FastState?,
        isRamadan: Bool = false,
        isPaused: Bool = false,
        evening: Bool = false,
        now: Date
    ) -> FastingDayModel.Inscription? {
        FastingDayModel.inscription(
            state: state, isRamadan: isRamadan, isPaused: isPaused,
            isEveningBeforeFast: evening,
            now: now, fajr: fajr, maghrib: maghrib, timeZone: timeZone
        )
    }

    @Test
    func fastingDayShowsSuhoorBeforeFajrAndIftarAfter() throws {
        let beforeFajr = try #require(inscription(state: .kept, now: fajr.addingTimeInterval(-3600)))
        guard case .fact(let suhoor) = beforeFajr else {
            Issue.record("expected a fact"); return
        }
        #expect(suhoor.hasPrefix("FASTING · SUHOOR ENDS"))
        #expect(suhoor.contains(PlateTimeFormat.time(fajr, in: timeZone).uppercased()))

        let midday = try #require(inscription(state: .kept, now: fajr.addingTimeInterval(6 * 3600)))
        guard case .fact(let iftar) = midday else {
            Issue.record("expected a fact"); return
        }
        #expect(iftar.hasPrefix("FASTING · IFTAR"))
        #expect(iftar.contains(PlateTimeFormat.time(maghrib, in: timeZone).uppercased()))
    }

    @Test
    func plainDayShowsNothing() {
        #expect(inscription(state: nil, now: fajr.addingTimeInterval(3600)) == nil)
    }

    @Test
    func ramadanOffersTheDailyFastUnlessPaused() {
        let offered = inscription(state: nil, isRamadan: true, now: fajr.addingTimeInterval(3600))
        guard case .ramadanOffer(let text) = offered else {
            Issue.record("expected the Ramadan offer"); return
        }
        #expect(text.hasPrefix("FASTING TODAY?"))

        // From Maghrib the Ramadan day in progress is tomorrow's, and
        // the offer says so rather than calling it today's.
        let evening = inscription(
            state: nil, isRamadan: true, evening: true, now: fajr.addingTimeInterval(-3600)
        )
        guard case .ramadanOffer(let eveningText) = evening else {
            Issue.record("expected the Ramadan offer"); return
        }
        #expect(eveningText.hasPrefix("FASTING TOMORROW?"))

        // Paused days offer no fasting prompts.
        #expect(inscription(state: nil, isRamadan: true, isPaused: true, now: fajr) == nil)
    }

    @Test
    func anIntentionReachingIftarInvitesCompletion() {
        let atIftar = inscription(state: .intended, now: maghrib.addingTimeInterval(60))
        #expect(atIftar == .keptCompletion("FAST KEPT?"))
        // Before iftar the intention reads as the plain fasting fact.
        let midday = inscription(state: .intended, now: fajr.addingTimeInterval(3600))
        if case .fact = midday {} else {
            Issue.record("expected a fact before iftar")
        }
    }

    /// The model's whole vocabulary: no negative fasting state can be
    /// rendered. (The state enum itself has no such case — this pins
    /// the strings too.)
    @Test
    func noNegativeLanguageExists() {
        let banned = ["broken", "failed", "missed fast", "streak", "behind"]
        var rendered: [String] = []
        for state in [FastState.intended, .kept] {
            for offset in stride(from: -7200.0, through: 16 * 3600, by: 3600) {
                if let value = inscription(state: state, now: fajr.addingTimeInterval(offset)) {
                    switch value {
                    case .fact(let s), .ramadanOffer(let s), .keptCompletion(let s):
                        rendered.append(s.lowercased())
                    }
                }
            }
        }
        for text in rendered {
            for word in banned {
                #expect(!text.contains(word), "\(word) in \(text)")
            }
        }
    }
}
