import Foundation
import IhsanCore
import Testing
@testable import IhsanDesignSystem

// MARK: - State derivation

@Test
func markerStateForFuturePrayerIsFuture() {
    let now = dateAt(hour: 12, minute: 0)
    let prayerTime = dateAt(hour: 15, minute: 30) // asr later today
    let state = PrayerMarker.State.derive(
        scheduledTime: prayerTime,
        isNextUpcoming: false,
        now: now
    )
    #expect(state == .future)
}

@Test
func markerStateForPastPrayerIsPast() {
    let now = dateAt(hour: 14, minute: 0)
    let prayerTime = dateAt(hour: 12, minute: 30) // dhuhr earlier today
    let state = PrayerMarker.State.derive(
        scheduledTime: prayerTime,
        isNextUpcoming: false,
        now: now
    )
    #expect(state == .past)
}

@Test
func markerStateForNextUpcomingIsCurrentRegardlessOfTime() {
    // Even a past prayer that's flagged "next upcoming" (e.g., during
    // its window before sunrise / before next prayer) should render
    // as current.
    let now = dateAt(hour: 5, minute: 30)
    let prayerTime = dateAt(hour: 5, minute: 15) // fajr just passed
    let state = PrayerMarker.State.derive(
        scheduledTime: prayerTime,
        isNextUpcoming: true,
        now: now
    )
    #expect(state == .current)
}

// MARK: - PrayerMarker label initialiser

@Test
func prayerMarkerLabelIsUppercasedEnglishPrayerName() {
    let marker = PrayerMarker(prayer: .fajr, state: .future)
    #expect(marker.label == "FAJR")

    let dhuhr = PrayerMarker(prayer: .dhuhr, state: .past)
    #expect(dhuhr.label == "DHUHR")

    let isha = PrayerMarker(prayer: .isha, state: .current)
    #expect(isha.label == "ISHA")
}

@Test
func prayerMarkerPreservesArbitraryLabel() {
    // Caller-provided labels are passed through without modification —
    // used by abbreviation logic or future localisation paths.
    let marker = PrayerMarker(label: "Custom", state: .past)
    #expect(marker.label == "Custom")
}

// MARK: - PrayerMarkerData carries prayer + scheduled time

@Test
func prayerMarkerDataIsValueEqual() {
    let prayerTime = dateAt(hour: 12, minute: 0)
    let a = PrayerMarkerData(prayer: .dhuhr, scheduledTime: prayerTime)
    let b = PrayerMarkerData(prayer: .dhuhr, scheduledTime: prayerTime)
    let c = PrayerMarkerData(prayer: .asr, scheduledTime: prayerTime)
    #expect(a == b)
    #expect(a != c)
}

// MARK: - Helpers

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? .now
}
