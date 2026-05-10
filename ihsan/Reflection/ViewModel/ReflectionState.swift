import Foundation
import IhsanCore
import IhsanFiqhConfig

/// View state for the Reflection screen. The hero prompt and the past-feed
/// load independently — `prompt` may be present while `feed` is still
/// loading, so they are tracked as separate ready snapshots inside a
/// single composite state.
///
/// `loading` is the brief flash before the screen reads SwiftData and the
/// FiqhConfig for the first time. `error` is reserved for catastrophic
/// failures (no fiqh config can be loaded at all); routine failures like
/// "permission denied for microphone" surface inline in the input area.
enum ReflectionState: Equatable {
    case loading
    case ready(Snapshot)
    case error(String)

    struct Snapshot: Equatable {
        let prompt: ReflectionPrompt
        let promptDate: Date
        let framing: FiqhFraming
        let sections: [ReflectionDateGrouping.Section]

        var isEmpty: Bool { sections.isEmpty }
    }
}
