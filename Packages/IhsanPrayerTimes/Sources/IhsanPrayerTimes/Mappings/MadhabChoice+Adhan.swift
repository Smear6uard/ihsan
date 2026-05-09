import Adhan
import IhsanCore

extension IhsanCore.MadhabChoice {
    func toAdhanMadhab() -> Madhab {
        return switch self {
        case .standard:
            .shafi
        case .hanafi:
            .hanafi
        }
    }
}
