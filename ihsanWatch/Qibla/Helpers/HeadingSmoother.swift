import Foundation

/// Exponential moving average for compass heading. Compass values
/// jitter at the sensor; without smoothing the dial would visibly
/// shimmer. Wraparound is handled by computing the shortest signed
/// delta in [-180, 180] before the lerp, so a transition from 359°
/// to 1° travels 2° across the seam rather than 358° the long way
/// around.
///
/// Mirrors iOS's HeadingSmoother — duplicated rather than vended from
/// IhsanLocation because the on-watch view model is the only consumer
/// here, and the type is too small to merit cross-target plumbing.
final class HeadingSmoother {
    /// 0 = no update (frozen), 1 = no smoothing (raw passes through).
    let alpha: Double
    private var current: Double?

    init(alpha: Double = 0.18) {
        self.alpha = alpha
    }

    func smooth(_ raw: Double) -> Double {
        guard let last = current else {
            current = raw
            return raw
        }
        var delta = raw - last
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let next = (last + alpha * delta).truncatingRemainder(dividingBy: 360)
        let normalized = next < 0 ? next + 360 : next
        current = normalized
        return normalized
    }
}
