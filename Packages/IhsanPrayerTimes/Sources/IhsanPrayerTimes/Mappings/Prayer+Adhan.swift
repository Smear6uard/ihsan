import Adhan
import IhsanCore

extension IhsanCore.Prayer {
    static func from(adhan: Adhan.Prayer) -> IhsanCore.Prayer? {
        switch adhan {
        case .fajr:
            .fajr
        case .dhuhr:
            .dhuhr
        case .asr:
            .asr
        case .maghrib:
            .maghrib
        case .isha:
            .isha
        case .sunrise:
            nil
        }
    }
}
