import Foundation
import SwiftData

/// The user's own masjid: a name they typed, optionally the venue they
/// picked out of the nearby search, and the iqamah times they know.
///
/// Nothing here is fetched. There is no masjid-times network dependency
/// anywhere in this app, by design — these are the times a person read off
/// a board and entered.
///
/// The stored coordinate is the single carve-out to privacy invariant #1
/// (see CLAUDE.md): device-derived coordinates remain transient, but a
/// venue the user deliberately chose and typed times for is their own
/// datum. It is encrypted at rest and never leaves the private database.
@Model
public final class MyMasjid {
    public static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    public var id: UUID = MyMasjid.singletonID

    @Attribute(.allowsCloudEncryption)
    public var name: String?

    @Attribute(.allowsCloudEncryption)
    public var streetLabel: String?

    @Attribute(.allowsCloudEncryption)
    public var latitude: Double?

    @Attribute(.allowsCloudEncryption)
    public var longitude: Double?

    public var iqamahConfigJSON: String = "[]"

    /// The khutbah's wall-clock time, minutes from local midnight. Fixed
    /// only — a khutbah is announced, not derived from the solar math.
    public var jumuahKhutbahMinutesFromMidnight: Int?

    /// One lead time for the whole masjid. Someone thinks about the journey
    /// there once, not five separate times.
    public var reminderLeadMinutes: Int = 10

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = MyMasjid.singletonID,
        name: String? = nil,
        streetLabel: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        iqamahConfigJSON: String = "[]",
        jumuahKhutbahMinutesFromMidnight: Int? = nil,
        reminderLeadMinutes: Int = 10,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.streetLabel = streetLabel
        self.latitude = latitude
        self.longitude = longitude
        self.iqamahConfigJSON = iqamahConfigJSON
        self.jumuahKhutbahMinutesFromMidnight = jumuahKhutbahMinutesFromMidnight
        self.reminderLeadMinutes = reminderLeadMinutes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// The record, or nil.
    ///
    /// The display surfaces ask this on every refresh — they must be able to
    /// find out that no masjid is set without creating one as a side effect
    /// of having asked.
    public static func fetchExisting(in context: ModelContext) -> MyMasjid? {
        let singletonID = MyMasjid.singletonID
        var descriptor = FetchDescriptor<MyMasjid>(
            predicate: #Predicate<MyMasjid> { $0.id == singletonID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public static func fetchOrCreate(in context: ModelContext) throws -> MyMasjid {
        if let existing = fetchExisting(in: context) { return existing }
        let masjid = MyMasjid()
        context.insert(masjid)
        return masjid
    }

    // MARK: - Entries

    /// Every prayer, in the day's order, whatever order they were entered
    /// in and whatever an older payload happens to hold.
    public var iqamahEntries: [IqamahEntry] {
        let stored = IqamahSchedule.decode(iqamahConfigJSON)
        guard !stored.isEmpty else { return IqamahSchedule.empty }
        return Prayer.allCases.map { prayer in
            stored.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
        }
    }

    public func entry(for prayer: Prayer) -> IqamahEntry {
        iqamahEntries.first { $0.prayer == prayer } ?? IqamahEntry(prayer: prayer)
    }

    public func setEntry(_ entry: IqamahEntry) {
        var entries = iqamahEntries
        if let index = entries.firstIndex(where: { $0.prayer == entry.prayer }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        iqamahConfigJSON = IqamahSchedule.encode(entries)
        modifiedAt = .now
    }

    public var hasAnyIqamah: Bool {
        iqamahEntries.contains(where: \.isSet) || jumuahKhutbahMinutesFromMidnight != nil
    }

    /// Point this record at a different venue.
    ///
    /// The times go with the old one: they described that congregation's
    /// schedule, and carrying them across would present another masjid's
    /// times as this one's.
    public func replaceVenue(
        name: String?,
        streetLabel: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.name = name
        self.streetLabel = streetLabel
        self.latitude = latitude
        self.longitude = longitude
        self.iqamahConfigJSON = "[]"
        self.jumuahKhutbahMinutesFromMidnight = nil
        self.modifiedAt = .now
    }

    public var snapshot: MyMasjidSnapshot {
        MyMasjidSnapshot(
            name: name,
            streetLabel: streetLabel,
            entries: iqamahEntries,
            jumuahKhutbahMinutesFromMidnight: jumuahKhutbahMinutesFromMidnight,
            reminderLeadMinutes: reminderLeadMinutes
        )
    }
}
