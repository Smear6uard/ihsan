public enum PrayerTimesError: Error, Sendable {
    case calculationFailed(underlying: String)
    case invalidDate(String)
    case invalidCoordinates(String)
    case invalidTimeZone(String)
    case unsupportedCalculationMethod(String)
}
