import Foundation

/// How Isha is derived. Every published method uses one of these two
/// shapes: a depression angle below the horizon, or a fixed number of
/// minutes after Maghrib (the Umm al-Qura / Gulf convention).
///
/// `.preset` means "whatever the chosen method says" — the app does not
/// substitute a rule the method's own committee did not publish.
public enum IshaRule: Sendable, Equatable, Hashable {
    case preset
    case angle(Double)
    case intervalMinutes(Int)
}

/// Manual per-prayer corrections, in whole minutes. These exist because
/// a local masjid's printed timetable is the timetable a person actually
/// prays by; the app's job is to match it, not to argue with it.
///
/// The range is deliberately narrow (`allowedRange`): an offset is a
/// correction, not a second calculation method.
public struct PrayerOffsets: Codable, Sendable, Equatable, Hashable {
    public static let allowedRange = -10...10

    public var fajr: Int
    public var dhuhr: Int
    public var asr: Int
    public var maghrib: Int
    public var isha: Int

    public static let none = PrayerOffsets()

    public init(
        fajr: Int = 0,
        dhuhr: Int = 0,
        asr: Int = 0,
        maghrib: Int = 0,
        isha: Int = 0
    ) {
        self.fajr = Self.clamp(fajr)
        self.dhuhr = Self.clamp(dhuhr)
        self.asr = Self.clamp(asr)
        self.maghrib = Self.clamp(maghrib)
        self.isha = Self.clamp(isha)
    }

    private static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, allowedRange.lowerBound), allowedRange.upperBound)
    }

    public var isEmpty: Bool {
        self == .none
    }

    public subscript(prayer: Prayer) -> Int {
        get {
            switch prayer {
            case .fajr: fajr
            case .dhuhr: dhuhr
            case .asr: asr
            case .maghrib: maghrib
            case .isha: isha
            }
        }
        set {
            let clamped = Self.clamp(newValue)
            switch prayer {
            case .fajr: fajr = clamped
            case .dhuhr: dhuhr = clamped
            case .asr: asr = clamped
            case .maghrib: maghrib = clamped
            case .isha: isha = clamped
            }
        }
    }
}

/// Everything a person can change about the calculation *beyond* the
/// named method, madhab, and high-latitude rule.
///
/// `.standard` is the identity: the chosen preset, untouched. Every
/// existing call site therefore keeps its exact behavior, which is what
/// keeps the pinned default-method snapshot green.
public struct CalculationTuning: Sendable, Equatable, Hashable {
    /// Twilight-angle bounds the UI offers. 12°–20° covers every angle
    /// any recognised authority publishes with room on either side; the
    /// app clamps rather than trusting an arbitrary number to compute.
    public static let angleRange: ClosedRange<Double> = 12.0...20.0
    public static let angleStep: Double = 0.5

    /// Fixed-interval bounds for the "minutes after Maghrib" Isha rule.
    public static let intervalRange: ClosedRange<Int> = 60...120
    public static let intervalStep: Int = 5

    /// nil — use the method's own Fajr angle.
    public var fajrAngle: Double?
    public var ishaRule: IshaRule
    public var offsets: PrayerOffsets

    public static let standard = CalculationTuning()

    public init(
        fajrAngle: Double? = nil,
        ishaRule: IshaRule = .preset,
        offsets: PrayerOffsets = .none
    ) {
        self.fajrAngle = fajrAngle.map(Self.clampAngle)
        switch ishaRule {
        case .preset:
            self.ishaRule = .preset
        case .angle(let value):
            self.ishaRule = .angle(Self.clampAngle(value))
        case .intervalMinutes(let value):
            self.ishaRule = .intervalMinutes(Self.clampInterval(value))
        }
        self.offsets = offsets
    }

    /// Snap to the nearest offered step inside the allowed range, so a
    /// value that arrives from stale storage or a future build can never
    /// feed the solar math something it was not designed for.
    public static func clampAngle(_ value: Double) -> Double {
        let clamped = min(max(value, angleRange.lowerBound), angleRange.upperBound)
        return (clamped / angleStep).rounded() * angleStep
    }

    public static func clampInterval(_ minutes: Int) -> Int {
        let clamped = min(max(minutes, intervalRange.lowerBound), intervalRange.upperBound)
        return Int((Double(clamped) / Double(intervalStep)).rounded()) * intervalStep
    }

    /// True when the person has changed an angle or an Isha rule — the
    /// condition under which every surface must stop calling the result
    /// by a standard method's name.
    public var overridesAngles: Bool {
        if fajrAngle != nil { return true }
        if ishaRule != .preset { return true }
        return false
    }

    /// Offsets alone do not make a method "custom": a ±3 minute
    /// correction to match a local timetable is still ISNA.
    public var isStandard: Bool {
        self == .standard
    }

    /// Drop every angle override, keeping manual offsets. This is what
    /// "Reset to <preset>" performs.
    public func resettingAngles() -> CalculationTuning {
        CalculationTuning(fajrAngle: nil, ishaRule: .preset, offsets: offsets)
    }
}

// MARK: - Storage

/// `IshaRule` is stored as two independent optional columns on
/// `UserSettings` rather than as an encoded blob, so a CloudKit record
/// merge can never produce an undecodable rule.
public extension IshaRule {
    init(storedAngle: Double?, storedIntervalMinutes: Int?) {
        // The interval wins when both are present: a stored interval is
        // only ever written by explicitly choosing interval mode, while
        // an angle can linger from a previous choice.
        if let storedIntervalMinutes {
            self = .intervalMinutes(CalculationTuning.clampInterval(storedIntervalMinutes))
        } else if let storedAngle {
            self = .angle(CalculationTuning.clampAngle(storedAngle))
        } else {
            self = .preset
        }
    }

    var storedAngle: Double? {
        if case .angle(let value) = self { return value }
        return nil
    }

    var storedIntervalMinutes: Int? {
        if case .intervalMinutes(let value) = self { return value }
        return nil
    }
}
