import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

/// Pins the existing five-prayer calculation outputs for 20 location/date/method
/// combinations. IhsanPrayerTimes is additive-only: night-interval work must never
/// shift a fard time. Any diff here is a regression, not a snapshot to re-record.
private struct FardhSnapshot {
    let label: String
    let latitude: Double
    let longitude: Double
    let timeZone: String
    let dateUTC: String
    let method: CalculationMethodChoice
    let madhab: MadhabChoice
    let rule: IhsanCore.HighLatitudeRule
    /// fajr, sunrise, dhuhr, asr, maghrib, isha, middleOfTheNight,
    /// lastThirdOfTheNight as Unix timestamps.
    let expected: [Double]
}

private let fardhSnapshots: [FardhSnapshot] = [
    FardhSnapshot(label: "chicago-may", latitude: 41.8781, longitude: -87.6298, timeZone: "America/Chicago", dateUTC: "2026-05-15T12:00:00Z", method: .isna, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_835_420, 1_778_841_000, 1_778_867_280, 1_778_881_500, 1_778_893_440, 1_778_899_080, 1_778_907_600, 1_778_912_340]),
    FardhSnapshot(label: "chicago-dst-spring", latitude: 41.8781, longitude: -87.6298, timeZone: "America/Chicago", dateUTC: "2026-03-07T18:00:00Z", method: .northAmerica, madhab: .hanafi, rule: .middleOfNight,
        expected: [1_772_881_140, 1_772_885_760, 1_772_906_520, 1_772_920_980, 1_772_927_280, 1_772_931_840, 1_772_947_380, 1_772_954_100]),
    FardhSnapshot(label: "chicago-dst-fall", latitude: 41.8781, longitude: -87.6298, timeZone: "America/Chicago", dateUTC: "2026-10-31T18:00:00Z", method: .isna, madhab: .standard, rule: .angleBased,
        expected: [1_793_444_640, 1_793_449_320, 1_793_468_100, 1_793_478_060, 1_793_486_760, 1_793_491_440, 1_793_508_960, 1_793_516_340]),
    FardhSnapshot(label: "mecca-may", latitude: 21.4225, longitude: 39.8262, timeZone: "Asia/Riyadh", dateUTC: "2026-05-15T12:00:00Z", method: .ummAlQura, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_807_940, 1_778_812_920, 1_778_836_620, 1_778_848_500, 1_778_860_320, 1_778_865_720, 1_778_877_300, 1_778_882_940]),
    FardhSnapshot(label: "mecca-winter", latitude: 21.4225, longitude: 39.8262, timeZone: "Asia/Riyadh", dateUTC: "2026-12-21T12:00:00Z", method: .ummAlQura, madhab: .standard, rule: .middleOfNight,
        expected: [1_797_820_320, 1_797_825_240, 1_797_844_740, 1_797_855_780, 1_797_864_240, 1_797_869_640, 1_797_885_540, 1_797_892_620]),
    FardhSnapshot(label: "london-solstice", latitude: 51.5074, longitude: -0.1278, timeZone: "Europe/London", dateUTC: "2026-06-21T12:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .angleBased,
        expected: [1_782_005_460, 1_782_013_380, 1_782_043_380, 1_782_059_100, 1_782_073_320, 1_782_080_820, 1_782_082_620, 1_782_085_680]),
    FardhSnapshot(label: "london-dst-spring", latitude: 51.5074, longitude: -0.1278, timeZone: "Europe/London", dateUTC: "2026-03-28T12:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .oneSeventh,
        expected: [1_774_670_940, 1_774_676_700, 1_774_699_620, 1_774_712_040, 1_774_722_420, 1_774_728_240, 1_774_739_820, 1_774_745_640]),
    FardhSnapshot(label: "oslo-solstice", latitude: 59.9139, longitude: 10.7522, timeZone: "Europe/Oslo", dateUTC: "2026-06-21T12:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .middleOfNight,
        expected: [1_781_997_540, 1_782_006_840, 1_782_040_800, 1_782_057_600, 1_782_074_640, 1_782_083_940, 1_782_079_320, 1_782_080_820]),
    FardhSnapshot(label: "reykjavik-solstice", latitude: 64.1466, longitude: -21.9426, timeZone: "Atlantic/Reykjavik", dateUTC: "2026-06-21T12:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .angleBased,
        expected: [1_782_007_440, 1_782_010_500, 1_782_048_660, 1_782_066_180, 1_782_086_640, 1_782_089_580, 1_782_090_240, 1_782_091_440]),
    FardhSnapshot(label: "reykjavik-winter", latitude: 64.1466, longitude: -21.9426, timeZone: "Atlantic/Reykjavik", dateUTC: "2026-12-21T12:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .twilightAngle,
        expected: [1_797_839_640, 1_797_852_120, 1_797_859_620, 1_797_860_820, 1_797_866_940, 1_797_878_880, 1_797_896_520, 1_797_906_360]),
    FardhSnapshot(label: "jakarta", latitude: -6.2088, longitude: 106.8456, timeZone: "Asia/Jakarta", dateUTC: "2026-05-15T06:00:00Z", method: .singapore, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_794_380, 1_778_799_240, 1_778_820_600, 1_778_832_660, 1_778_841_840, 1_778_846_220, 1_778_861_340, 1_778_867_820]),
    FardhSnapshot(label: "sydney-dst-fall", latitude: -33.8688, longitude: 151.2093, timeZone: "Australia/Sydney", dateUTC: "2026-04-04T06:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .middleOfNight,
        expected: [1_775_241_960, 1_775_246_940, 1_775_267_940, 1_775_279_760, 1_775_288_820, 1_775_293_500, 1_775_308_620, 1_775_315_220]),
    FardhSnapshot(label: "sydney-dst-spring", latitude: -33.8688, longitude: 151.2093, timeZone: "Australia/Sydney", dateUTC: "2026-10-03T06:00:00Z", method: .muslimWorldLeague, madhab: .hanafi, rule: .middleOfNight,
        expected: [1_790_964_360, 1_790_969_400, 1_790_991_900, 1_791_007_920, 1_791_014_340, 1_791_019_140, 1_791_032_520, 1_791_038_520]),
    FardhSnapshot(label: "karachi", latitude: 24.8607, longitude: 67.0011, timeZone: "Asia/Karachi", dateUTC: "2026-05-15T08:00:00Z", method: .karachi, madhab: .hanafi, rule: .middleOfNight,
        expected: [1_778_801_040, 1_778_806_080, 1_778_830_140, 1_778_846_940, 1_778_854_140, 1_778_859_240, 1_778_870_760, 1_778_876_280]),
    FardhSnapshot(label: "cairo", latitude: 30.0444, longitude: 31.2357, timeZone: "Africa/Cairo", dateUTC: "2026-05-15T10:00:00Z", method: .egyptian, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_808_180, 1_778_814_120, 1_778_838_720, 1_778_851_740, 1_778_863_260, 1_778_868_540, 1_778_878_920, 1_778_884_080]),
    FardhSnapshot(label: "istanbul", latitude: 41.0082, longitude: 28.9784, timeZone: "Europe/Istanbul", dateUTC: "2026-05-15T10:00:00Z", method: .turkey, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_806_380, 1_778_812_740, 1_778_839_500, 1_778_853_660, 1_778_865_720, 1_778_871_660, 1_778_879_220, 1_778_883_720]),
    FardhSnapshot(label: "anchorage-solstice", latitude: 61.2181, longitude: -149.9003, timeZone: "America/Anchorage", dateUTC: "2026-06-21T20:00:00Z", method: .northAmerica, madhab: .standard, rule: .angleBased,
        expected: [1_782_040_260, 1_782_044_400, 1_782_079_380, 1_782_096_360, 1_782_114_180, 1_782_118_320, 1_782_120_420, 1_782_122_520]),
    FardhSnapshot(label: "buenos-aires", latitude: -34.6037, longitude: -58.3816, timeZone: "America/Argentina/Buenos_Aires", dateUTC: "2026-05-15T12:00:00Z", method: .muslimWorldLeague, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_836_380, 1_778_841_600, 1_778_860_260, 1_778_870_280, 1_778_878_740, 1_778_883_720, 1_778_900_820, 1_778_908_140]),
    FardhSnapshot(label: "kuala-lumpur", latitude: 3.139, longitude: 101.6869, timeZone: "Asia/Kuala_Lumpur", dateUTC: "2026-05-15T06:00:00Z", method: .singapore, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_794_860, 1_778_799_720, 1_778_821_860, 1_778_833_980, 1_778_843_880, 1_778_848_260, 1_778_862_540, 1_778_868_780]),
    FardhSnapshot(label: "tehran", latitude: 35.6892, longitude: 51.389, timeZone: "Asia/Tehran", dateUTC: "2026-05-15T08:00:00Z", method: .tehran, madhab: .standard, rule: .middleOfNight,
        expected: [1_778_802_720, 1_778_808_600, 1_778_833_860, 1_778_847_540, 1_778_860_380, 1_778_863_680, 1_778_874_720, 1_778_879_460]),
]

@Test(arguments: fardhSnapshots.map(\.label))
private func fardhOutputsMatchPinnedSnapshot(label: String) throws {
    let snapshot = try #require(fardhSnapshots.first { $0.label == label })
    let provider = AdhanPrayerTimesProvider()
    let date = try #require(ISO8601DateFormatter().date(from: snapshot.dateUTC))

    let times = try provider.dayTimes(
        for: date,
        coordinates: Coordinates(latitude: snapshot.latitude, longitude: snapshot.longitude),
        timeZone: try #require(TimeZone(identifier: snapshot.timeZone)),
        calculationMethod: snapshot.method,
        madhab: snapshot.madhab,
        highLatitudeRule: snapshot.rule
    )

    let actual = [
        times.fajr.scheduledTime, times.sunrise, times.dhuhr.scheduledTime,
        times.asr.scheduledTime, times.maghrib.scheduledTime, times.isha.scheduledTime,
        times.middleOfTheNight, times.lastThirdOfTheNight,
    ].map(\.timeIntervalSince1970)

    #expect(actual == snapshot.expected, "Fard snapshot drifted for \(label)")
}
