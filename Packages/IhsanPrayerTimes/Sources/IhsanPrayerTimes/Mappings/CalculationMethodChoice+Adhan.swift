import Adhan
import IhsanCore

extension IhsanCore.CalculationMethodChoice {
    func toAdhanCalculationParameters() throws -> CalculationParameters {
        switch self {
        case .muslimWorldLeague:
            return CalculationMethod.muslimWorldLeague.params
        case .isna:
            return CalculationMethod.northAmerica.params
        case .egyptian:
            return CalculationMethod.egyptian.params
        case .ummAlQura:
            return CalculationMethod.ummAlQura.params
        case .karachi:
            return CalculationMethod.karachi.params
        case .dubai:
            return CalculationMethod.dubai.params
        case .qatar:
            return CalculationMethod.qatar.params
        case .kuwait:
            return CalculationMethod.kuwait.params
        case .singapore:
            return CalculationMethod.singapore.params
        case .tehran:
            return CalculationMethod.tehran.params
        case .jafari:
            var params = CalculationMethod.other.params
            params.fajrAngle = 16
            params.ishaAngle = 14
            return params
        case .moonsightingCommittee:
            return CalculationMethod.moonsightingCommittee.params
        case .northAmerica:
            return CalculationMethod.northAmerica.params
        case .turkey:
            return CalculationMethod.turkey.params
        case .other:
            throw PrayerTimesError.unsupportedCalculationMethod(
                "Use a specific method; .other requires manual angle configuration not supported in v1."
            )
        }
    }
}

/// The twilight geometry a method actually computes with.
///
/// Read straight off the parameters the solver will be handed, so what a
/// settings row displays and what the sun math uses can never drift.
public struct CalculationMethodAngles: Sendable, Equatable, Hashable {
    public let fajrAngle: Double
    /// The Isha depression angle, or `nil` when the method defines Isha
    /// as a fixed interval after Maghrib instead.
    public let ishaAngle: Double?
    /// Minutes after Maghrib, or `nil` when Isha is angle-based.
    public let ishaIntervalMinutes: Int?

    public init(fajrAngle: Double, ishaAngle: Double?, ishaIntervalMinutes: Int?) {
        self.fajrAngle = fajrAngle
        self.ishaAngle = ishaAngle
        self.ishaIntervalMinutes = ishaIntervalMinutes
    }
}

public extension IhsanCore.CalculationMethodChoice {
    /// The angles this method publishes, or `nil` for `.other`, which
    /// has none of its own.
    var angles: CalculationMethodAngles? {
        guard let params = try? toAdhanCalculationParameters() else { return nil }
        return CalculationMethodAngles(params)
    }
}

public extension CalculationMethodAngles {
    init(fajrAngle: Double, ishaRule: IshaRule, fallback: CalculationMethodAngles?) {
        let resolvedFajr = fajrAngle
        switch ishaRule {
        case .preset:
            self.init(
                fajrAngle: resolvedFajr,
                ishaAngle: fallback?.ishaAngle,
                ishaIntervalMinutes: fallback?.ishaIntervalMinutes
            )
        case .angle(let value):
            self.init(fajrAngle: resolvedFajr, ishaAngle: value, ishaIntervalMinutes: nil)
        case .intervalMinutes(let value):
            self.init(fajrAngle: resolvedFajr, ishaAngle: nil, ishaIntervalMinutes: value)
        }
    }

    /// The angles that result once a method is tuned — what a "Custom ·
    /// 16° / 90 min" label must read from.
    static func effective(
        method: IhsanCore.CalculationMethodChoice,
        tuning: CalculationTuning
    ) -> CalculationMethodAngles? {
        guard let base = method.angles else { return nil }
        guard tuning.overridesAngles else { return base }
        return CalculationMethodAngles(
            fajrAngle: tuning.fajrAngle ?? base.fajrAngle,
            ishaRule: tuning.ishaRule,
            fallback: base
        )
    }
}

extension CalculationMethodAngles {
    init(_ params: CalculationParameters) {
        let interval = params.ishaInterval
        self.init(
            fajrAngle: params.fajrAngle,
            ishaAngle: interval > 0 ? nil : params.ishaAngle,
            ishaIntervalMinutes: interval > 0 ? interval : nil
        )
    }
}

extension CalculationParameters {
    /// Apply the user's calculation depth on top of a method's published
    /// parameters. Angle overrides also drop the method identity to
    /// `.other`, because a method tag in Adhan-Swift can carry its own
    /// algorithm (the Moonsighting Committee's seasonal twilight above
    /// 55° latitude) that would quietly ignore the angle a person just
    /// typed. Manual offsets ride the `adjustments` slot, which is
    /// separate from a method's own `methodAdjustments`, so a preset's
    /// published corrections survive.
    mutating func apply(_ tuning: CalculationTuning) {
        if tuning.overridesAngles {
            method = .other

            if let fajrAngle = tuning.fajrAngle {
                self.fajrAngle = fajrAngle
            }

            switch tuning.ishaRule {
            case .preset:
                break
            case .angle(let value):
                ishaAngle = value
                ishaInterval = 0
            case .intervalMinutes(let value):
                ishaInterval = value
                ishaAngle = 0
            }
        }

        adjustments.fajr += tuning.offsets.fajr
        adjustments.dhuhr += tuning.offsets.dhuhr
        adjustments.asr += tuning.offsets.asr
        adjustments.maghrib += tuning.offsets.maghrib
        adjustments.isha += tuning.offsets.isha
    }
}
