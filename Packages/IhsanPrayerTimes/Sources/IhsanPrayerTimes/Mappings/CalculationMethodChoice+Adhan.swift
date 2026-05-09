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
