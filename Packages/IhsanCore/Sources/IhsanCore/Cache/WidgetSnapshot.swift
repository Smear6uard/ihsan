import Foundation

/// The one versioned snapshot every iOS widget renders from.
///
/// The host app writes it whenever the day resolves — foreground,
/// significant location change, any settings or worship mutation — and
/// widgets read it and nothing else. A widget process never calculates
/// prayer times, never opens SwiftData, never consults the device
/// timezone, and never invents a fallback schedule: when this snapshot
/// is missing or stale the widget renders its "Open Ihsan" state.
///
/// Two full civil days travel together so a quiet day — the app never
/// opened — does not leave the next morning's widgets orphaned: the
/// timeline crosses one rollover on the exact table the app computed,
/// and staleness begins only where computed truth ends.
///
/// Everything a widget face needs beyond the times themselves is
/// precomputed here in the app's register (Hijri inscriptions, fasting
/// facts, the pause) so no second interpretation path exists in an
/// extension. Coordinates are never present — only the resolved city
/// name and timezone, per the privacy contract on `LocatedPlace`.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    /// Bump when the payload shape changes; readers reject foreign
    /// versions and fall back to the missing-snapshot state rather
    /// than guessing at fields.
    public static let currentSchemaVersion = 2

    /// One civil day's resolver boundaries, exactly as the app
    /// calculated them.
    public struct DayTable: Codable, Sendable, Equatable {
        /// Start of the civil day in the place timezone.
        public let civilDayStart: Date
        public let fajr: Date
        public let sunrise: Date
        public let dhuhr: Date
        public let asr: Date
        public let maghrib: Date
        public let isha: Date

        public init(
            civilDayStart: Date,
            fajr: Date,
            sunrise: Date,
            dhuhr: Date,
            asr: Date,
            maghrib: Date,
            isha: Date
        ) {
            self.civilDayStart = civilDayStart
            self.fajr = fajr
            self.sunrise = sunrise
            self.dhuhr = dhuhr
            self.asr = asr
            self.maghrib = maghrib
            self.isha = isha
        }
    }

    /// One night's divisions, precomputed by the app from
    /// `NightIntervals` — the widget reads instants, it never divides
    /// a span itself.
    public struct NightTable: Codable, Sendable, Equatable {
        /// Maghrib — the night begins.
        public let start: Date
        /// The following Fajr — the night ends.
        public let end: Date
        public let nisfAlLayl: Date
        public let lastThirdStart: Date

        public init(start: Date, end: Date, nisfAlLayl: Date, lastThirdStart: Date) {
            self.start = start
            self.end = end
            self.nisfAlLayl = nisfAlLayl
            self.lastThirdStart = lastThirdStart
        }

        /// Half-open at Fajr, matching `NightIntervals.contains`.
        public func contains(_ date: Date) -> Bool {
            date >= start && date < end
        }
    }

    /// One civil day's Hijri identity, offset already applied by the
    /// app. Strings are precomputed so an extension never re-derives
    /// an inscription with a different offset than the app displays.
    public struct HijriStamp: Codable, Sendable, Equatable {
        public let civilDayStart: Date
        public let day: Int
        public let monthName: String
        public let year: Int
        /// The significant-day line in the inscription register
        /// ("White day · Muharram 13"), or nil for an unmarked day.
        public let significantLine: String?
        public let isRamadan: Bool

        public init(
            civilDayStart: Date,
            day: Int,
            monthName: String,
            year: Int,
            significantLine: String?,
            isRamadan: Bool
        ) {
            self.civilDayStart = civilDayStart
            self.day = day
            self.monthName = monthName
            self.year = year
            self.significantLine = significantLine
            self.isRamadan = isRamadan
        }

        /// "Muharram 14, 1448 AH" — the one display form, assembled
        /// from the same parts the app assembles it from.
        public var displayLine: String {
            "\(monthName) \(day), \(year) AH"
        }
    }

    /// One civil day's fasting fact. Suhoor ends at that day's Fajr
    /// and iftar arrives at its Maghrib — both live in the day table,
    /// so this carries only the fact of the fast.
    public struct FastingStamp: Codable, Sendable, Equatable {
        public let civilDayStart: Date
        /// A fast is recorded for the day (intended or kept).
        public let isFasting: Bool
        public let isRamadan: Bool

        public init(civilDayStart: Date, isFasting: Bool, isRamadan: Bool) {
            self.civilDayStart = civilDayStart
            self.isFasting = isFasting
            self.isRamadan = isRamadan
        }
    }

    public let schemaVersion: Int
    public let writtenAt: Date

    public let timeZoneIdentifier: String
    public let cityName: String?
    public let qiblaBearingDegrees: Double?

    /// The previous day's Isha — today's pre-Fajr window belongs to it.
    public let yesterdayIsha: Date
    public let today: DayTable
    public let tomorrow: DayTable
    /// Fajr of the day after tomorrow — tomorrow's terminal boundary.
    public let dayAfterTomorrowFajr: Date

    public let tonight: NightTable
    public let tomorrowNight: NightTable

    /// Today's then tomorrow's stamps.
    public let hijri: [HijriStamp]
    public let fasting: [FastingStamp]

    /// Logged status per prayer raw value, for today's civil day.
    /// Absence means no log exists.
    public let loggedStatusByPrayerRaw: [String: String]
    /// The jamāʿah axis for today's logs, keyed like the statuses.
    public let jamaahByPrayerRaw: [String: Bool]

    /// An excused pause is active. Widgets show times and nothing
    /// that asks for logging while this is true.
    public let isPaused: Bool
    public let pauseExpectedEnd: Date?

    /// Total qadā prayers remaining across ledgers, or nil when
    /// tracking is off. Feeds the Repair accessory so it never opens
    /// the store from a widget process. Optional so older payloads
    /// decode.
    public let qadaRemaining: Int?

    public init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        writtenAt: Date,
        timeZoneIdentifier: String,
        cityName: String?,
        qiblaBearingDegrees: Double?,
        yesterdayIsha: Date,
        today: DayTable,
        tomorrow: DayTable,
        dayAfterTomorrowFajr: Date,
        tonight: NightTable,
        tomorrowNight: NightTable,
        hijri: [HijriStamp],
        fasting: [FastingStamp],
        loggedStatusByPrayerRaw: [String: String],
        jamaahByPrayerRaw: [String: Bool],
        isPaused: Bool,
        pauseExpectedEnd: Date?,
        qadaRemaining: Int? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.writtenAt = writtenAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.cityName = cityName
        self.qiblaBearingDegrees = qiblaBearingDegrees
        self.yesterdayIsha = yesterdayIsha
        self.today = today
        self.tomorrow = tomorrow
        self.dayAfterTomorrowFajr = dayAfterTomorrowFajr
        self.tonight = tonight
        self.tomorrowNight = tomorrowNight
        self.hijri = hijri
        self.fasting = fasting
        self.loggedStatusByPrayerRaw = loggedStatusByPrayerRaw
        self.jamaahByPrayerRaw = jamaahByPrayerRaw
        self.isPaused = isPaused
        self.pauseExpectedEnd = pauseExpectedEnd
        self.qadaRemaining = qadaRemaining
    }
}

// MARK: - Freshness

/// What a widget may claim about the world from this snapshot.
public enum WidgetSnapshotFreshness: Sendable, Equatable {
    /// The instant falls inside the snapshot's computed truth.
    case fresh
    /// The snapshot exists but its truth has run out — too old, or
    /// past the last boundary it carries. Render the dignified
    /// "Open Ihsan" state; never its times.
    case stale
}

public extension WidgetSnapshot {
    /// Truth older than this is stale regardless of coverage — the
    /// task's 36-hour rule.
    static let maximumAge: TimeInterval = 36 * 60 * 60

    func freshness(at instant: Date) -> WidgetSnapshotFreshness {
        if instant.timeIntervalSince(writtenAt) > Self.maximumAge { return .stale }
        if instant >= dayAfterTomorrowFajr { return .stale }
        // A snapshot "from the future" means the device clock moved
        // backwards across a day boundary; its tables no longer
        // describe this instant's day.
        if instant < today.civilDayStart { return .stale }
        return .fresh
    }

    /// The day table whose prayer bracket contains `instant`:
    /// today's from yesterday's Isha window up to tomorrow's Fajr,
    /// tomorrow's from there to its own terminal Fajr.
    func dayTable(containing instant: Date) -> DayTable? {
        guard freshness(at: instant) == .fresh else { return nil }
        return instant < tomorrow.fajr ? today : tomorrow
    }

    /// The night containing `instant`, when it is night at all.
    func night(containing instant: Date) -> NightTable? {
        if tonight.contains(instant) { return tonight }
        if tomorrowNight.contains(instant) { return tomorrowNight }
        return nil
    }

    /// The night a face should speak about at `instant`: the one in
    /// progress, or else the one ahead — through the day that is
    /// tonight, and late in day two it is tomorrow night.
    func relevantNight(at instant: Date) -> NightTable? {
        if let containing = night(containing: instant) { return containing }
        if instant < tonight.start { return tonight }
        if instant < tomorrowNight.start { return tomorrowNight }
        return nil
    }

    /// Every instant at which a widget face can change state: prayer
    /// window edges and sunrise for both days, solar midnight and the
    /// last-third start of both nights, and the Hijri day rollovers
    /// (civil midnight in the place timezone). Suhoor and iftar are
    /// Fajr and Maghrib — already here. Sorted, exclusive of `after`,
    /// strictly before `until`.
    func timelineBoundaries(after: Date, until: Date) -> [Date] {
        var boundaries: Set<Date> = []
        for table in [today, tomorrow] {
            boundaries.formUnion([
                table.fajr, table.sunrise, table.dhuhr,
                table.asr, table.maghrib, table.isha,
            ])
        }
        for night in [tonight, tomorrowNight] {
            boundaries.formUnion([night.nisfAlLayl, night.lastThirdStart])
        }
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            var cursor = calendar.startOfDay(for: after)
            for _ in 0..<3 {
                guard let midnight = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                    break
                }
                boundaries.insert(midnight)
                cursor = midnight
            }
        }
        return boundaries.filter { $0 > after && $0 < until }.sorted()
    }

    /// The stamp for the civil day containing `instant`, resolved in
    /// the place timezone.
    func hijriStamp(at instant: Date) -> HijriStamp? {
        stamp(in: hijri, at: instant, dayStart: \.civilDayStart)
    }

    func fastingStamp(at instant: Date) -> FastingStamp? {
        stamp(in: fasting, at: instant, dayStart: \.civilDayStart)
    }

    private func stamp<S>(
        in stamps: [S], at instant: Date, dayStart: KeyPath<S, Date>
    ) -> S? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return stamps.first {
            calendar.isDate($0[keyPath: dayStart], inSameDayAs: instant)
        }
    }

    /// The same snapshot with today's logged states replaced — the
    /// optimistic mirror an intent writes so a widget reflects its
    /// own button press on the very next render.
    func replacingLogs(
        loggedStatusByPrayerRaw: [String: String],
        jamaahByPrayerRaw: [String: Bool]
    ) -> WidgetSnapshot {
        copy(
            loggedStatusByPrayerRaw: loggedStatusByPrayerRaw,
            jamaahByPrayerRaw: jamaahByPrayerRaw
        )
    }

    /// The optimistic mirror for the Repair funnel.
    func replacingQadaRemaining(_ remaining: Int?) -> WidgetSnapshot {
        copy(qadaRemaining: .some(remaining))
    }

    /// The optimistic mirror for the fasting funnel.
    func replacingFasting(_ fasting: [FastingStamp]) -> WidgetSnapshot {
        copy(fasting: fasting)
    }

    private func copy(
        fasting: [FastingStamp]? = nil,
        loggedStatusByPrayerRaw: [String: String]? = nil,
        jamaahByPrayerRaw: [String: Bool]? = nil,
        qadaRemaining: Int?? = nil
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: schemaVersion,
            writtenAt: writtenAt,
            timeZoneIdentifier: timeZoneIdentifier,
            cityName: cityName,
            qiblaBearingDegrees: qiblaBearingDegrees,
            yesterdayIsha: yesterdayIsha,
            today: today,
            tomorrow: tomorrow,
            dayAfterTomorrowFajr: dayAfterTomorrowFajr,
            tonight: tonight,
            tomorrowNight: tomorrowNight,
            hijri: hijri,
            fasting: fasting ?? self.fasting,
            loggedStatusByPrayerRaw: loggedStatusByPrayerRaw ?? self.loggedStatusByPrayerRaw,
            jamaahByPrayerRaw: jamaahByPrayerRaw ?? self.jamaahByPrayerRaw,
            isPaused: isPaused,
            pauseExpectedEnd: pauseExpectedEnd,
            qadaRemaining: qadaRemaining ?? self.qadaRemaining
        )
    }
}

// MARK: - Store

/// App Group persistence for the snapshot. Writers are the host app
/// and the intent funnel's optimistic mirror; readers are widget
/// timeline providers.
public enum WidgetSnapshotStore {
    public static let suiteName = "group.com.sameerstudios.ihsan"
    public static let key = "ihsan.widget-snapshot.v2"

    public static func write(_ snapshot: WidgetSnapshot, defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? UserDefaults(suiteName: suiteName) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// The stored snapshot, or nil when absent, undecodable, or from
    /// a different schema version — all three mean "no truth", and
    /// the widget renders its missing state.
    public static func read(defaults: UserDefaults? = nil) -> WidgetSnapshot? {
        guard let defaults = defaults ?? UserDefaults(suiteName: suiteName) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        guard snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion else { return nil }
        return snapshot
    }

    public static func clear(defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: key)
    }

    /// Read–modify–write for the intent funnel: replace today's
    /// logged states in place so the widget's next render — which the
    /// system schedules immediately after an interactive intent —
    /// already shows the log.
    public static func mirrorLogs(
        loggedStatusByPrayerRaw: [String: String],
        jamaahByPrayerRaw: [String: Bool],
        defaults: UserDefaults? = nil
    ) {
        guard let snapshot = read(defaults: defaults) else { return }
        write(
            snapshot.replacingLogs(
                loggedStatusByPrayerRaw: loggedStatusByPrayerRaw,
                jamaahByPrayerRaw: jamaahByPrayerRaw
            ),
            defaults: defaults
        )
    }
}
