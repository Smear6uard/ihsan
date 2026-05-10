import WidgetKit

/// Thin façade so the watch app can poke complications when its
/// prayer-times cache changes. Pulled out into its own helper so
/// view models don't need to import WidgetKit directly.
@MainActor
enum WidgetReloader {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
