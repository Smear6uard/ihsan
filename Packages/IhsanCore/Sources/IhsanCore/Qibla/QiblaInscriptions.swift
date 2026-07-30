import Foundation

/// The instrument's written voice — every string the qibla surfaces
/// render or speak. Centralized so the visual inscriptions, the static
/// bearing card, and the VoiceOver guidance can never drift apart.
public enum QiblaInscriptions {

    /// Small-caps distance inscription: "10 306 KM" (narrow no-break
    /// space grouping, whole kilometers).
    public static func distance(km: Double) -> String {
        "\(grouped(Int(km.rounded()))) KM"
    }

    /// Small-caps live direction inscription: "48° TO YOUR RIGHT".
    /// Near the half-turn the side is meaningless — say "BEHIND YOU".
    /// Rounds to whole degrees but never to zero: sub-degree deltas
    /// only occur inside the aligned band, which replaces this line
    /// with "FACING QIBLA" — if asked anyway, show 1°.
    public static func relativeDirection(signedDelta: Double) -> String {
        if abs(signedDelta) >= 172 { return "BEHIND YOU" }
        let degrees = max(1, Int(abs(signedDelta).rounded()))
        let side = signedDelta >= 0 ? "RIGHT" : "LEFT"
        return "\(degrees)° TO YOUR \(side)"
    }

    /// The no-compass fallback card's single line:
    /// "QIBLA IS 58° NE OF TRUE NORTH".
    public static func staticBearing(qiblaBearing: Double) -> String {
        let degrees = Int(qiblaBearing.rounded()) % 360
        return "QIBLA IS \(degrees)° \(cardinal(qiblaBearing)) OF TRUE NORTH"
    }

    /// Spoken counterpart of `relativeDirection`, for VoiceOver
    /// guidance: "40 degrees to your right".
    public static func spokenDirection(signedDelta: Double) -> String {
        if abs(signedDelta) >= 172 { return "Behind you" }
        let degrees = max(1, Int(abs(signedDelta).rounded()))
        let side = signedDelta >= 0 ? "right" : "left"
        return "\(degrees) degrees to your \(side)"
    }

    /// Spoken distance: "10,306 kilometers to Makkah".
    public static func spokenDistance(km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        let number = formatter.string(from: NSNumber(value: Int(km.rounded())))
            ?? "\(Int(km.rounded()))"
        return "\(number) kilometers to Makkah"
    }

    // MARK: - Pieces

    /// Eight-wind cardinal abbreviation for a bearing.
    static func cardinal(_ bearing: Double) -> String {
        let winds = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((QiblaMath.normalized(bearing) + 22.5) / 45) % 8
        return winds[index]
    }

    /// Thousands grouping with a narrow no-break space (U+202F) — the
    /// engraved-numeral convention: "10 306".
    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "\u{202F}"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
