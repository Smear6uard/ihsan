import Foundation
import Testing
@testable import IhsanCore

private let day: TimeInterval = 86_400

private func daysAgo(_ days: Double, from reference: Date) -> Date {
    reference.addingTimeInterval(-days * day)
}

@Test
func steadyRecentPaceForecastsCompletion() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    // 14 made up over the last 28 days = 0.5/day; 50 remaining → 100 days out.
    let entries = (0..<14).map { index in
        QadaEntry.madeUp(
            category: .fajr,
            count: 1,
            date: daysAgo(Double(index * 2), from: now),
            createdAt: daysAgo(Double(index * 2), from: now)
        )
    }

    let forecast = QadaPace.forecast(entries: entries, remaining: 50, asOf: now)

    let expected = now.addingTimeInterval(100 * day)
    #expect(forecast != nil)
    if let forecast {
        #expect(abs(forecast.timeIntervalSince(expected)) < day)
    }
}

@Test
func noRecentActivityMeansNoForecast() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let stale = [
        QadaEntry.madeUp(
            category: .fajr,
            count: 30,
            date: daysAgo(90, from: now),
            createdAt: daysAgo(90, from: now)
        )
    ]

    #expect(QadaPace.forecast(entries: stale, remaining: 50, asOf: now) == nil)
    #expect(QadaPace.forecast(entries: [], remaining: 50, asOf: now) == nil)
}

@Test
func zeroRemainingMeansNoForecast() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let entries = [
        QadaEntry.madeUp(category: .fajr, count: 1, date: daysAgo(1, from: now), createdAt: daysAgo(1, from: now))
    ]

    #expect(QadaPace.forecast(entries: entries, remaining: 0, asOf: now) == nil)
}

@Test
func onlyMadeUpEntriesCountTowardPace() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let entries = [
        QadaEntry.estimated(category: .fajr, count: 100, createdAt: daysAgo(5, from: now)),
        QadaEntry.adjusted(category: .fajr, delta: 10, reason: nil, createdAt: daysAgo(4, from: now)),
        QadaEntry.missedFlowedIn(prayer: .fajr, date: daysAgo(3, from: now), createdAt: daysAgo(3, from: now))
    ]

    #expect(QadaPace.forecast(entries: entries, remaining: 50, asOf: now) == nil)
}

@Test
func multiCountEntriesWeighTheirFullAmount() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    // One batch of 28 within the window = 1/day; 30 remaining → 30 days out.
    let entries = [
        QadaEntry.madeUp(category: .asr, count: 28, date: daysAgo(10, from: now), createdAt: daysAgo(10, from: now))
    ]

    let forecast = QadaPace.forecast(entries: entries, remaining: 30, asOf: now)

    let expected = now.addingTimeInterval(30 * day)
    #expect(forecast != nil)
    if let forecast {
        #expect(abs(forecast.timeIntervalSince(expected)) < day)
    }
}
