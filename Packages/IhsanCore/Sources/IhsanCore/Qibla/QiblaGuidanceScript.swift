import Foundation

/// The VoiceOver script for finding the qibla by ear: decides, from
/// the stream of deltas, exactly when to speak and what to say. A
/// blind user should be able to find the qibla with this guidance
/// alone — enough updates to steer by, never chatter.
///
/// Policy:
///
/// - The first reading speaks immediately ("42 degrees to your
///   right"), so the screen orients the user on entry.
/// - Direction updates speak when the delta crosses into a new band
///   (90/60/40/25/15/8°) or the side flips, rate-limited to one
///   utterance per 2.5 s.
/// - Alignment speaks "Facing qibla" immediately — it outranks the
///   rate limit — and then holds silent while alignment lasts. (The
///   alignment haptic doubles as the non-visual confirmation.)
/// - Losing alignment resumes direction guidance on the next band
///   update, with no negative phrasing.
public struct QiblaGuidanceScript: Sendable {

    /// Band edges in degrees of absolute delta, matching the spoken
    /// granularity a turning body can act on — coarse far out, finer
    /// as the qibla nears.
    static let bands: [Double] = [90, 60, 45, 30, 20, 12, 6]

    /// Minimum spacing between non-alignment utterances.
    static let quietInterval: TimeInterval = 2.5

    private struct SpokenState: Equatable {
        var band: Int
        var side: Bool // true = right
    }

    private var lastSpoken: SpokenState?
    private var lastSpokeAt: Date?
    private var announcedAlignment = false

    public init() {}

    /// Feeds one reading; returns a line to announce, or nil to stay
    /// silent.
    public mutating func update(
        signedDelta: Double,
        isAligned: Bool,
        at time: Date
    ) -> String? {
        if isAligned {
            guard !announcedAlignment else { return nil }
            announcedAlignment = true
            lastSpokeAt = time
            lastSpoken = nil
            return "Facing qibla"
        }
        announcedAlignment = false

        let state = SpokenState(
            band: Self.bandIndex(for: abs(signedDelta)),
            side: signedDelta >= 0
        )

        // First reading orients immediately; later readings speak only
        // on a band or side change.
        if let lastSpoken, lastSpoken == state { return nil }

        if let lastSpokeAt, time.timeIntervalSince(lastSpokeAt) < Self.quietInterval {
            return nil
        }

        lastSpoken = state
        lastSpokeAt = time
        return QiblaInscriptions.spokenDirection(signedDelta: signedDelta)
    }

    static func bandIndex(for absDelta: Double) -> Int {
        for (index, edge) in bands.enumerated() where absDelta > edge {
            return index
        }
        return bands.count
    }
}
