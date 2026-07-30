import Foundation
import SwiftData
import Testing
@testable import IhsanCore

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema(IhsanSchemaV4.models)
    // Unique store name per test — unnamed in-memory configurations share
    // one backing store within a process, which corrupts parallel runs.
    let configuration = ModelConfiguration(
        UUID().uuidString,
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: configuration)
    return ModelContext(container)
}

@MainActor
private func enableFlow(in context: ModelContext, since setupDate: Date) throws {
    let settings = try UserSettings.fetchOrCreate(in: context)
    settings.qadaTrackingEnabled = true
    settings.qadaMissedFlowEnabled = true
    settings.qadaSetupCompletedAt = setupDate
    try context.save()
}

@MainActor
private func remaining(for category: QadaCategory, in context: ModelContext) throws -> Int {
    let raw = category.rawValue
    let descriptor = FetchDescriptor<QadaLedger>(
        predicate: #Predicate { $0.categoryRaw == raw }
    )
    return try context.fetch(descriptor).first?.remainingCount ?? 0
}

@Test
@MainActor
func sweepFlowsEveryUnloggedFardFromEndedDays() throws {
    let context = try makeContext()
    let now = Date(timeIntervalSinceReferenceDate: 790_000_000)
    let twoDaysAgo = utc.date(byAdding: .day, value: -2, to: now)!
    try enableFlow(in: context, since: twoDaysAgo)

    let created = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)

    // Two full days ended with nothing logged: 2 × 5 fard.
    #expect(created.count == 10)
    #expect(try remaining(for: .fajr, in: context) == 2)
    #expect(try remaining(for: .isha, in: context) == 2)
}

@Test
@MainActor
func sweepSkipsPrayersWithAnyLog() throws {
    let context = try makeContext()
    let now = Date(timeIntervalSinceReferenceDate: 790_000_000)
    let yesterday = utc.date(byAdding: .day, value: -1, to: now)!
    try enableFlow(in: context, since: yesterday)

    context.insert(PrayerLog(
        prayer: .fajr,
        prayerDate: utc.startOfDay(for: yesterday),
        loggedTimeZoneIdentifier: "UTC",
        scheduledTime: yesterday,
        status: .onTime
    ))
    context.insert(PrayerLog(
        prayer: .dhuhr,
        prayerDate: utc.startOfDay(for: yesterday),
        loggedTimeZoneIdentifier: "UTC",
        scheduledTime: yesterday,
        status: .missed
    ))
    try context.save()

    let created = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)

    // Fajr was prayed and dhuhr explicitly recorded as missed — an explicit
    // record is a log, so only the three silent prayers flow.
    #expect(created.count == 3)
    #expect(try remaining(for: .fajr, in: context) == 0)
    #expect(try remaining(for: .dhuhr, in: context) == 0)
    #expect(try remaining(for: .asr, in: context) == 1)
}

@Test
@MainActor
func sweepGeneratesNothingForPausedDays() throws {
    let context = try makeContext()
    let now = Date(timeIntervalSinceReferenceDate: 790_000_000)
    let twoDaysAgo = utc.date(byAdding: .day, value: -2, to: now)!
    try enableFlow(in: context, since: twoDaysAgo)

    // Covers both swept days from before their first midnight, matching the
    // Trajectory rule: a day is paused when its start-of-day falls inside
    // the interval.
    context.insert(PauseInterval(
        startDate: utc.startOfDay(for: twoDaysAgo).addingTimeInterval(-3_600),
        loggedTimeZoneIdentifier: "UTC"
    ))
    try context.save()

    let created = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)

    #expect(created.isEmpty)
    #expect(try context.fetch(FetchDescriptor<QadaEntry>()).isEmpty)
}

@Test
@MainActor
func sweepIsIdempotentAcrossRepeatedRuns() throws {
    let context = try makeContext()
    let now = Date(timeIntervalSinceReferenceDate: 790_000_000)
    let yesterday = utc.date(byAdding: .day, value: -1, to: now)!
    try enableFlow(in: context, since: yesterday)

    let first = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)
    let second = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)

    #expect(first.count == 5)
    #expect(second.isEmpty)
    #expect(try remaining(for: .maghrib, in: context) == 1)
}

@Test
@MainActor
func sweepDoesNothingWhenTheChoiceIsOff() throws {
    let context = try makeContext()
    let now = Date(timeIntervalSinceReferenceDate: 790_000_000)
    let settings = try UserSettings.fetchOrCreate(in: context)
    settings.qadaTrackingEnabled = true
    settings.qadaMissedFlowEnabled = false
    settings.qadaSetupCompletedAt = utc.date(byAdding: .day, value: -3, to: now)
    try context.save()

    let created = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)

    #expect(created.isEmpty)
}

@Test
@MainActor
func sweepNeverReachesBeforeSetup() throws {
    let context = try makeContext()
    let now = Date(timeIntervalSinceReferenceDate: 790_000_000)
    let yesterdayNoon = utc.date(byAdding: .day, value: -1, to: now)!
    try enableFlow(in: context, since: yesterdayNoon)

    let created = try QadaMissedFlowSweep().sweep(now: now, calendar: utc, in: context)

    // Only the one day since setup flows, not the open-ended past.
    #expect(created.count == 5)
}
