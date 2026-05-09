public enum LocationAuthorization: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    public var isAuthorized: Bool {
        self == .authorizedWhenInUse || self == .authorizedAlways
    }
}
