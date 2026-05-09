import Foundation

enum MasjidFinderState {
    case loading
    case needsLocationPermission
    case ready([MasjidResult])
    case empty
    case error(String)
}

enum SearchRadius: Double, CaseIterable, Identifiable {
    case oneKm = 1
    case fiveKm = 5
    case tenKm = 10

    var id: Double { rawValue }

    var label: String {
        "\(Int(rawValue)) km"
    }
}
