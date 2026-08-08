enum MasjidFinderState {
    case loading
    case needsLocationPermission
    case ready([MasjidResult])
    case empty
    case failure
}
