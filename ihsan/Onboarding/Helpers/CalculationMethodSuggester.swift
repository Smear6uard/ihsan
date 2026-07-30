import Foundation
import IhsanCore
import IhsanPrayerTimes

/// Where onboarding gets its starting method from.
///
/// The region map itself lives in `IhsanPrayerTimes` beside the angles,
/// so onboarding and Settings offer the same starting point rather than
/// two drifting tables. Anything unmapped falls through to Muslim World
/// League, which is the most globally portable default. The mapping
/// reflects the dominant convention in a region, not a preference —
/// every method is one tap away and stays changeable forever.
enum CalculationMethodSuggester {
    static func method(forCountryCode code: String?) -> CalculationMethodChoice {
        CalculationMethodChoice.commonMethod(forCountryCode: code)
    }

    /// Region used when the user skipped the location grant. Prefers
    /// the device locale; iOS exposes this without any permission.
    static func suggestedFromLocale(_ locale: Locale = .current) -> CalculationMethodChoice {
        method(forCountryCode: locale.region?.identifier)
    }
}
