import Foundation

/// Ordered steps in the first-launch flow.
///
/// The order is the source of truth — `progressIndex` and `totalSteps`
/// are derived so the progress dots stay in sync if a step is added.
enum OnboardingStep: Int, CaseIterable, Hashable, Identifiable {
    case welcome
    case location
    case calculationMethod
    case madhab
    case notifications

    var id: Int { rawValue }

    var progressIndex: Int { rawValue }

    static var totalSteps: Int { OnboardingStep.allCases.count }
}
