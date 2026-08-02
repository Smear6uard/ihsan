import Foundation
import SwiftData
import Testing
@testable import IhsanCore

private let nightOf = Date(timeIntervalSinceReferenceDate: 700_000_000)

@MainActor
private func makeContext() throws -> ModelContext {
    let schema = Schema(IhsanSchemaV7.models)
    // Unique store name per test — unnamed in-memory configurations share
    // one backing store within a process, which corrupts parallel runs.
    let configuration = ModelConfiguration(
        UUID().uuidString, schema: schema,
        isStoredInMemoryOnly: true, cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: configuration)
    return ModelContext(container)
}

@Test
func naflKindStorageKeysRoundTrip() throws {
    let kinds: [NaflKind] = [
        .rawatibBefore(.fajr), .rawatibAfter(.isha),
        .duha, .qiyam, .witr,
    ]

    for kind in kinds {
        #expect(NaflKind(storageKey: kind.storageKey) == kind)
    }

    #expect(NaflKind(storageKey: "rawatibBefore.fajr") == .rawatibBefore(.fajr))
    #expect(NaflKind(storageKey: "witr") == .witr)
    #expect(NaflKind(storageKey: "tarawih") == .tarawih)
    // Unknown keys stay nil instead of trapping — the kind design is
    // extensible and old builds must tolerate newer data.
    #expect(NaflKind(storageKey: "sunriseWalk") == nil)
    #expect(NaflKind(storageKey: "rawatibBefore.tea") == nil)
}

@Test
func naflKindEnumeratesAllKnownKinds() {
    let all = NaflKind.allKnownKinds
    #expect(all.count == 14)
    #expect(all.contains(.tarawih))
    #expect(all.contains(.duha))
    #expect(all.contains(.rawatibBefore(.dhuhr)))
    #expect(Set(all.map(\.storageKey)).count == all.count)
}

@MainActor
@Test
func naflLogPersistsKindDateAndOptionalRakah() throws {
    let context = try makeContext()
    let log = NaflLog(
        kind: .rawatibAfter(.maghrib),
        naflDate: nightOf,
        rakahCount: 2,
        loggedAt: nightOf.addingTimeInterval(600)
    )
    context.insert(log)
    try context.save()

    let fetched = try #require(try context.fetch(FetchDescriptor<NaflLog>()).first)
    #expect(fetched.kind == .rawatibAfter(.maghrib))
    #expect(fetched.naflDate == nightOf)
    #expect(fetched.rakahCount == 2)
    #expect(fetched.loggedAt == nightOf.addingTimeInterval(600))
}

@MainActor
@Test
func naflLogRakahCountDefaultsToNil() throws {
    let context = try makeContext()
    let log = NaflLog(kind: .qiyam, naflDate: nightOf)
    context.insert(log)
    try context.save()

    let fetched = try #require(try context.fetch(FetchDescriptor<NaflLog>()).first)
    #expect(fetched.rakahCount == nil)
}

@Test
func naflLogDedupKeyIsStablePerKindAndDay() {
    let sameDayLater = nightOf.addingTimeInterval(3600)
    let a = NaflLog(kind: .witr, naflDate: nightOf)
    let b = NaflLog(kind: .witr, naflDate: sameDayLater)
    let c = NaflLog(kind: .qiyam, naflDate: nightOf)
    let d = NaflLog(kind: .witr, naflDate: nightOf.addingTimeInterval(86_400))

    #expect(a.dedupKey == b.dedupKey)
    #expect(a.dedupKey != c.dedupKey)
    #expect(a.dedupKey != d.dedupKey)
    #expect(NaflLog.makeDedupKey(kind: .rawatibBefore(.fajr), naflDate: nightOf)
        == "rawatibBefore.fajr-\(NaflLog.makeDedupKey(kind: .witr, naflDate: nightOf).split(separator: "-", maxSplits: 1)[1])")
}

// MARK: - Witr bridge (informational only)

@Test
func witrBridgeIsNotTrackedWhenWitrQadaCategoryIsOff() {
    let log = NaflLog(kind: .witr, naflDate: nightOf)
    let state = NaflWitrBridge.state(
        forNightOf: nightOf,
        witrLogs: [log],
        tracksWitrQada: false
    )
    #expect(state == .notTracked)
}

@Test
func witrBridgeMarksNightCurrentWhenWitrLoggedThatNight() {
    let log = NaflLog(kind: .witr, naflDate: nightOf)
    let state = NaflWitrBridge.state(
        forNightOf: nightOf,
        witrLogs: [log],
        tracksWitrQada: true
    )
    #expect(state == .current)
}

@Test
func witrBridgeStaysOpenWithNoWitrThatNight() {
    let otherNight = NaflLog(kind: .witr, naflDate: nightOf.addingTimeInterval(86_400))
    let notWitr = NaflLog(kind: .qiyam, naflDate: nightOf)

    let state = NaflWitrBridge.state(
        forNightOf: nightOf,
        witrLogs: [otherNight, notWitr],
        tracksWitrQada: true
    )
    #expect(state == .open)
}

@Test
func rawatibDefaultsAreNeutralAndDecodable() throws {
    let data = try #require(UserSettings.defaultRawatibConfigJSON.data(using: .utf8))
    let configs = try JSONDecoder().decode([RawatibConfig].self, from: data)

    #expect(configs.count == 5)
    let byPrayer = Dictionary(uniqueKeysWithValues: configs.map { ($0.prayer, $0) })
    #expect(byPrayer[.fajr]?.beforeCount == 2)
    #expect(byPrayer[.fajr]?.afterCount == 0)
    #expect(byPrayer[.dhuhr]?.beforeCount == 4)
    #expect(byPrayer[.dhuhr]?.afterCount == 2)
    #expect(byPrayer[.maghrib]?.afterCount == 2)
    #expect(byPrayer[.isha]?.afterCount == 2)
}
