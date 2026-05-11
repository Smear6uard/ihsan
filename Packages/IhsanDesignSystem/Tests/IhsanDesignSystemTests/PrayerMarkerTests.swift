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

// MARK: - PrayerMarker constructed from Prayer

@Test
func prayerMarkerStoresThePrayerItRepresents() {
    let fajr = PrayerMarker(prayer: .fajr, state: .future)
    #expect(fajr.prayer == .fajr)

    let dhuhr = PrayerMarker(prayer: .dhuhr, state: .past)
    #expect(dhuhr.prayer == .dhuhr)

    let isha = PrayerMarker(prayer: .isha, state: .current)
    #expect(isha.prayer == .isha)
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

// MARK: - aboveHorizon parameter
//
// The aboveHorizon flag is a structural property of the marker — its
// default value, its preservation across initialisers, and its
// participation in the public surface. The visual treatment (muted
// fill, dimmer label) lives in the SwiftUI body and is verified by
// device-level inspection rather than unit assertion.

@Test
func prayerMarkerDefaultsToAboveHorizon() {
    let marker = PrayerMarker(prayer: .fajr, state: .future)
    #expect(marker.aboveHorizon == true)
}

@Test
func prayerMarkerPreservesAboveHorizonWhenSetExplicitly() {
    let belowHorizon = PrayerMarker(
        prayer: .isha,
        state: .future,
        aboveHorizon: false
    )
    #expect(belowHorizon.aboveHorizon == false)
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
