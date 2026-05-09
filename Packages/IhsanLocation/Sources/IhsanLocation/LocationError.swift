public enum LocationError: Error, Sendable, Equatable {
    case permissionNotDetermined
    case permissionDenied
    case permissionRestricted
    case locationUnavailable
    case timedOut
    case reverseGeocodingFailed(String)
    case headingUnavailable
    case calibrationRequired

    public var userFacingMessage: String {
        switch self {
        case .permissionNotDetermined:
            return "Location access has not been set up yet."
        case .permissionDenied:
            return "Location access is denied. Enable it in Settings."
        case .permissionRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Could not determine your current location."
        case .timedOut:
            return "Location request timed out. Try again."
        case .reverseGeocodingFailed:
            return "Could not resolve city name."
        case .headingUnavailable:
            return "Compass is not available on this device."
        case .calibrationRequired:
            return "Compass needs calibration. Move the device in a figure-8 pattern."
        }
    }
}
