import Foundation

/// The one gate every debug launch argument passes through.
///
/// The screenshot and verification harnesses drive the app with
/// arguments — open this tab, present that sheet, override the clock.
/// None of it may exist in a shipped binary: a release build that reads
/// launch arguments can be told to do things nobody asked it to, and
/// the reader of the code cannot tell at a glance which affordances are
/// real.
///
/// In release this compiles to `false` and the optimiser removes the
/// branch behind it entirely.
enum DebugLaunch {
    static func flag(_ name: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(name)
        #else
        false
        #endif
    }

    /// The value following `name`, or nil.
    static func value(after name: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1)
        else { return nil }
        return arguments[index + 1]
        #else
        nil
        #endif
    }
}
