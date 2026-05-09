import Adhan
import IhsanCore

extension IhsanCore.HighLatitudeRule {
    func toAdhanHighLatitudeRule() -> Adhan.HighLatitudeRule {
        return switch self {
        case .middleOfNight:
            .middleOfTheNight
        case .oneSeventh:
            .seventhOfTheNight
        case .angleBased, .twilightAngle:
            .twilightAngle
        }
    }
}
