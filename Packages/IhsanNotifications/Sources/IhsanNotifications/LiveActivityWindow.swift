import Foundation

/// The Live Activity's window around a prayer.
///
/// This is the app's one lead time, and the Live Activity is the only
/// surface allowed to have one. Every other surface — the plate, the
/// focused card, widgets, the watch, notifications — enters and leaves
/// a prayer at its exact boundary through `PrayerStateResolver`, which
/// has no tolerance and no lead by design. A countdown that says
/// "Maghrib soon" is a scheduling choice; a screen that says "Maghrib
/// is now" thirty minutes early is a lie, and the two were confused
/// once already.
///
/// Named here so there is exactly one definition. It previously existed
/// as two private copies in two modules, which had already drifted from
/// the intended value.
public enum LiveActivityWindow {
    /// How long before the adhan the activity may appear.
    public static let preAdhanLead: TimeInterval = 30 * 60

}
