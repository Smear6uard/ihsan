import Foundation

/// The first launch, in three screens.
///
/// It used to be five, and the first of them was a wordmark and a
/// tagline — a slideshow about an app, in front of the app. This opens
/// on the thing itself: a live plate, drawing a real day, while the
/// location question is asked in place over it. Then one screen of
/// calculation, then the close.
///
/// The order is the source of truth; `progressIndex` and `totalSteps`
/// derive from it.
enum OnboardingStep: Int, CaseIterable, Hashable, Identifiable {
    /// The app, immediately — a live plate for a default place, with
    /// the location request on it.
    case plate
    /// Method and Asr together. Madhab stays here rather than getting
    /// a page of its own: it moves Asr by an hour for a large part of
    /// the world, and burying it in Set would leave those people with
    /// quietly wrong times.
    case calculation
    /// Two quiet lines and the notification question, which is asked
    /// here because here is where it becomes relevant.
    case close

    var id: Int { rawValue }

    var progressIndex: Int { rawValue }

    static var totalSteps: Int { OnboardingStep.allCases.count }
}
