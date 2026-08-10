import Foundation
import SwiftData
import Testing
@testable import IhsanCore

@Suite("My Masjid")
@MainActor
struct MyMasjidTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(IhsanSchemaV9.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Nothing exists until one is set")
    func fetchExistingReturnsNilBeforeSetup() throws {
        let context = try makeContext()
        #expect(MyMasjid.fetchExisting(in: context) == nil)
    }

    /// The display surfaces ask "is one set?" on every refresh. Asking must
    /// not be what creates it.
    @Test("fetchExisting does not conjure a record")
    func fetchExistingHasNoSideEffect() throws {
        let context = try makeContext()
        _ = MyMasjid.fetchExisting(in: context)
        #expect(try context.fetch(FetchDescriptor<MyMasjid>()).isEmpty)
    }

    @Test("Only one masjid is ever created")
    func fetchOrCreateIsSingleton() throws {
        let context = try makeContext()
        let first = try MyMasjid.fetchOrCreate(in: context)
        first.name = "Masjid al-Noor"
        let second = try MyMasjid.fetchOrCreate(in: context)

        #expect(first.id == second.id)
        #expect(second.name == "Masjid al-Noor")
        #expect(try context.fetch(FetchDescriptor<MyMasjid>()).count == 1)
    }

    @Test("An entry set on one prayer leaves the others alone")
    func setEntryIsPerPrayer() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)

        masjid.setEntry(
            IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810)
        )

        #expect(masjid.entry(for: .dhuhr).mode == .fixed)
        #expect(masjid.entry(for: .dhuhr).fixedMinutesFromMidnight == 810)
        #expect(masjid.entry(for: .asr).mode == .none)
        #expect(masjid.entry(for: .fajr).mode == .none)
    }

    @Test("Entries come back in the day's order, whatever order they were set")
    func entriesAreInPrayerOrder() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)

        masjid.setEntry(IqamahEntry(prayer: .isha, mode: .offset, offsetMinutes: 10))
        masjid.setEntry(IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 20))

        #expect(masjid.iqamahEntries.map(\.prayer) == Prayer.allCases)
    }

    @Test("A masjid with no times set reports itself empty")
    func reportsWhetherAnythingIsSet() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        #expect(masjid.hasAnyIqamah == false)

        masjid.setEntry(IqamahEntry(prayer: .fajr, mode: .offset, offsetMinutes: 20))
        #expect(masjid.hasAnyIqamah)
    }

    @Test("A khutbah time alone is enough to count as set")
    func khutbahAloneCountsAsSet() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)

        masjid.jumuahKhutbahMinutesFromMidnight = 13 * 60 + 15

        #expect(masjid.hasAnyIqamah)
    }

    /// Times describe a congregation's schedule. Carrying them onto a
    /// different masjid would present another congregation's times as this
    /// one's.
    @Test("Replacing the venue clears the times that described the old one")
    func replacingVenueClearsTimes() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        masjid.name = "Masjid al-Noor"
        masjid.setEntry(
            IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810)
        )
        masjid.jumuahKhutbahMinutesFromMidnight = 795

        masjid.replaceVenue(
            name: "Masjid al-Rahma",
            streetLabel: "12 Mill Rd",
            latitude: 41.88,
            longitude: -87.63
        )

        #expect(masjid.name == "Masjid al-Rahma")
        #expect(masjid.streetLabel == "12 Mill Rd")
        #expect(masjid.latitude == 41.88)
        #expect(masjid.hasAnyIqamah == false)
        #expect(masjid.entry(for: .dhuhr).mode == .none)
        #expect(masjid.jumuahKhutbahMinutesFromMidnight == nil)
    }

    @Test("The snapshot carries the values a view needs")
    func snapshotIsAValueCopy() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        masjid.name = "Masjid al-Noor"
        masjid.reminderLeadMinutes = 15
        masjid.setEntry(
            IqamahEntry(prayer: .dhuhr, mode: .fixed, fixedMinutesFromMidnight: 810)
        )

        let snapshot = masjid.snapshot

        #expect(snapshot.name == "Masjid al-Noor")
        #expect(snapshot.reminderLeadMinutes == 15)
        #expect(snapshot.entry(for: .dhuhr).fixedMinutesFromMidnight == 810)
        #expect(snapshot.entry(for: .asr).mode == .none)
        #expect(snapshot.hasAnyIqamah)
    }

    /// The narrowest snapshot is the one least able to leak. No display
    /// surface needs the coordinate, so it does not travel.
    @Test("The snapshot carries no coordinate")
    func snapshotOmitsTheCoordinate() throws {
        let context = try makeContext()
        let masjid = try MyMasjid.fetchOrCreate(in: context)
        masjid.replaceVenue(
            name: "Masjid al-Rahma", streetLabel: nil,
            latitude: 41.88, longitude: -87.63
        )

        let mirror = Mirror(reflecting: masjid.snapshot)
        let labels = mirror.children.compactMap(\.label)

        #expect(!labels.contains("latitude"))
        #expect(!labels.contains("longitude"))
    }
}
