import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// The sheet truth pass, pinned as a property: for any (prayer
/// window, now, day-being-logged) the allowed timing set is exactly
/// what can be true at that moment.
@Suite("Timing availability")
struct TimingAvailabilityTests {

    private let calendar = Calendar.current

    /// A synthetic Dhuhr-like window on a fixed civil day: opens at
    /// 13:00, ends at 17:00.
    private var dayStart: Date { calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 790_000_000)) }
    private var scheduled: Date { dayStart.addingTimeInterval(13 * 3600) }
    private var windowEnd: Date { dayStart.addingTimeInterval(17 * 3600) }

    private func allowed(
        now: Date,
        day: Date? = nil,
        scheduledTime: Date?,
        windowEndTime: Date?,
        currentStatus: PrayerStatus? = nil
    ) -> Set<PrayerStatus> {
        let state: PrayerWindowState?
        if let scheduledTime, let windowEndTime {
            if now < scheduledTime {
                state = .upcoming(opensAt: scheduledTime)
            } else if now < windowEndTime {
                state = .current(startedAt: scheduledTime, endsAt: windowEndTime)
            } else {
                state = .closed(startedAt: scheduledTime, endedAt: windowEndTime)
            }
        } else {
            state = nil
        }
        return TimingAvailability.allowedStatuses(
            now: now,
            dayBeingLogged: day ?? now,
            windowState: state,
            currentStatus: currentStatus,
            calendar: calendar
        )
    }

    // MARK: - The corrected mapping, swept across the whole day
    //
    // The timing axis describes when the prayer was PERFORMED, not
    // when the log entry is created. Praying inside the window and
    // logging afterward is the most common pattern — a closed window
    // therefore offers ALL FOUR states, On Time included.

    /// Property: at every minute of the civil day, the allowed set is
    /// exactly one of the three spec answers — pre-window nothing,
    /// open window On Time alone, closed window all four.
    @Test
    func everyMinuteOfTodayMapsToExactlyTheSpecSet() {
        for minute in stride(from: 0, to: 24 * 60, by: 1) {
            let now = dayStart.addingTimeInterval(TimeInterval(minute * 60))
            let result = allowed(
                now: now, scheduledTime: scheduled, windowEndTime: windowEnd
            )
            let expected: Set<PrayerStatus>
            if now < scheduled {
                expected = []
            } else if now < windowEnd {
                expected = [.onTime, .late]
            } else {
                expected = [.onTime, .late, .qada, .missed]
            }
            #expect(result == expected, "minute \(minute): \(result)")
        }
    }

    /// Delayed describes a prayer offered INSIDE its window, late in
    /// it — so it is live for as long as the window is. Only qadā and
    /// missed have to wait for the window to close.
    @Test
    func openWindowOffersOnTimeAndDelayed() {
        let now = scheduled.addingTimeInterval(60)
        #expect(
            allowed(now: now, scheduledTime: scheduled, windowEndTime: windowEnd)
                == [.onTime, .late]
        )
    }

    @Test
    func openWindowWithholdsQadaAndMissed() {
        let now = scheduled.addingTimeInterval(60)
        let result = allowed(now: now, scheduledTime: scheduled, windowEndTime: windowEnd)
        #expect(!result.contains(.qada))
        #expect(!result.contains(.missed))
    }

    /// A prayer performed in its window and logged after it must never
    /// be blocked from On Time — the closed window opens every state.
    @Test
    func closedWindowOffersAllFourOnTimeIncluded() {
        let now = windowEnd.addingTimeInterval(60)
        #expect(
            allowed(now: now, scheduledTime: scheduled, windowEndTime: windowEnd)
                == [.onTime, .late, .qada, .missed]
        )
    }

    @Test
    func boundaryInstantsTurnAtomically() {
        // The exact opening instant is in-window; the exact end
        // instant is past-window — same convention as the card model.
        #expect(
            allowed(now: scheduled, scheduledTime: scheduled, windowEndTime: windowEnd)
                == [.onTime, .late]
        )
        #expect(
            allowed(now: windowEnd, scheduledTime: scheduled, windowEndTime: windowEnd)
                == [.onTime, .late, .qada, .missed]
        )
    }

    // MARK: - Past and future days

    @Test
    func aPastDayOffersAllFourWhateverTheClockSays() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: dayStart)!
        for hour in 0..<24 {
            let now = dayStart.addingTimeInterval(TimeInterval(hour * 3600))
            let result = allowed(
                now: now, day: yesterday, scheduledTime: nil, windowEndTime: nil
            )
            #expect(result == [.onTime, .late, .qada, .missed], "hour \(hour)")
        }
    }

    @Test
    func aFutureDayOffersNothing() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let now = scheduled
        #expect(allowed(now: now, day: tomorrow, scheduledTime: nil, windowEndTime: nil).isEmpty)
    }

    /// The ledger opens today's cells without a schedule; repair is
    /// deliberate there and the full set is the honest fallback.
    @Test
    func todayWithoutAScheduleFallsBackToTheFullSet() {
        let now = scheduled
        #expect(
            allowed(now: now, scheduledTime: nil, windowEndTime: nil)
                == [.onTime, .late, .qada, .missed]
        )
    }

    // MARK: - The existing entry stays selectable

    /// Property: whatever the clock says, an existing entry's status
    /// is in the allowed set — "Save Changes" with an unchanged
    /// selection can never be blocked.
    @Test
    func currentStatusIsAlwaysSelectable() {
        for status in [PrayerStatus.onTime, .late, .qada, .missed] {
            for hour in 0..<24 {
                let now = dayStart.addingTimeInterval(TimeInterval(hour * 3600))
                let result = allowed(
                    now: now,
                    scheduledTime: scheduled,
                    windowEndTime: windowEnd,
                    currentStatus: status
                )
                #expect(result.contains(status), "\(status) at hour \(hour)")
            }
        }
    }
}

/// The commit names the act — fresh entries log THIS prayer, edits
/// save changes.
@Suite("PrayerLogSheet commit copy")
struct PrayerLogSheetCopyTests {

    @Test
    func freshCommitNamesThePrayer() {
        #expect(PrayerLogSheet.commitTitle(prayer: .dhuhr, isEditing: false) == "Log Dhuhr")
        #expect(PrayerLogSheet.commitTitle(prayer: .fajr, isEditing: false) == "Log Fajr")
        #expect(PrayerLogSheet.commitTitle(prayer: .isha, isEditing: false) == "Log Isha")
    }

    @Test
    func editingCommitSaysSaveChanges() {
        for prayer in Prayer.allCases {
            #expect(PrayerLogSheet.commitTitle(prayer: prayer, isEditing: true) == "Save Changes")
        }
    }

    /// The sheet header's tense derives from the boundary, same rule
    /// as the card: "ENDS" while the window is open, "ENDED" after.
    @Test
    func headerTenseFollowsTheDerivedWindowState() {
        let timeZone = TimeZone(identifier: "America/Chicago")!
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let end = start.addingTimeInterval(2 * 3600)

        let open = PrayerLogSheet.timeRangeInscription(
            scheduledTime: start, windowEndTime: end,
            displayDate: nil,
            windowState: .current(startedAt: start, endsAt: end),
            timeZone: timeZone
        )
        #expect(open.contains("ENDS") && !open.contains("ENDED"))

        let closed = PrayerLogSheet.timeRangeInscription(
            scheduledTime: start, windowEndTime: end,
            displayDate: nil,
            windowState: .closed(startedAt: start, endedAt: end),
            timeZone: timeZone
        )
        #expect(closed.contains("ENDED"))
    }
}
