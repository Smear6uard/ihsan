import Foundation
import IhsanFiqhConfig

/// Maps a wall-clock hour to a `PromptTimeOfDay` bucket so the
/// FiqhConfigService can pick a prompt that fits the moment.
///
/// Buckets are deliberately wide and overlap with the Islamic day's natural
/// rhythm — but the FiqhConfigService falls back to the unfiltered set when
/// no prompt matches the requested bucket, so this only narrows the pool
/// rather than risking an empty result.
enum ReflectionTimeOfDay {
    /// Returns the bucket for the given calendar hour in the user's timezone.
    static func bucket(for date: Date = .now) -> PromptTimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<10:   return .morning
        case 10..<13:  return .midday
        case 13..<16:  return .afternoon
        case 16..<19:  return .evening
        case 19..<23:  return .night
        case 23..<24, 0..<3:
            return .lastThird
        default:
            return .night
        }
    }
}
