import IhsanCore
import SwiftUI

extension EnvironmentValues {
    /// The Today surface's single clock. Injected once at the root;
    /// every time-dependent view resolves its moment through this
    /// rather than reading `Date()` directly, so a debug override
    /// re-times the entire screen coherently.
    @Entry var nowProvider: NowProvider = .system
}
