import Foundation
import IhsanCore
import IhsanIntents
import OSLog
import SwiftUI

/// Every change the Path's day card makes to a record, and the way back
/// from each.
///
/// The same promise the Today card makes: a change is one tap, through
/// the funnel every other surface writes through, and one tap undoes it
/// for a few seconds. A run of changes to one prayer undoes to the state
/// before the first of them, so a double tap on two seals cannot strand
/// someone on the wrong one.
///
/// A removal waits out its Undo before it reaches the store, so taking
/// it back restores the identical row rather than a new one with the
/// same status. The card and the grid both draw the record as gone in
/// the meantime, through `applying(to:)`.
@Observable
@MainActor
final class PathRecordEditor {

    /// The change Undo would take back.
    struct Offer: Equatable {
        let day: Date
        let prayer: Prayer
        /// The record before the run began. Nil means no record.
        let previousStatus: PrayerStatus?
        let previousJamaah: Bool
        /// The store has been written during this run.
        var hasWritten: Bool
        /// The latest change in the run is a removal, still waiting.
        var isRemoval: Bool
    }

    private(set) var offer: Offer?

    @ObservationIgnored private var expiry: Task<Void, Never>?
    /// Writes run one at a time, in the order they were asked for.
    @ObservationIgnored private var writes: Task<Void, Never>?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan",
        category: "PathRecordEditor"
    )

    // MARK: - Changes

    func record(_ status: PrayerStatus, on day: Date, current: PrayerCompletion) {
        begin(on: day, current: current)
        offer?.isRemoval = false
        offer?.hasWritten = true
        let prayer = current.prayer
        enqueue {
            _ = try await LogPrayerWithStatusIntent(prayer: prayer, status: status, date: day).perform()
        }
        announce("\(prayer.displayNameEnglish) recorded as \(status.displayName).")
    }

    func toggleJamaah(on day: Date, current: PrayerCompletion) {
        begin(on: day, current: current)
        offer?.hasWritten = true
        let prayer = current.prayer
        enqueue {
            _ = try await ToggleJamaahIntent(prayer: prayer, date: day).perform()
        }
    }

    func remove(on day: Date, current: PrayerCompletion) {
        begin(on: day, current: current)
        offer?.isRemoval = true
        announce("\(current.prayer.displayNameEnglish) record removed.")
    }

    /// Puts the record back as it was before the run began.
    func undo() {
        guard let run = offer else { return }
        expiry?.cancel()
        offer = nil
        // A removal that has not been written, with nothing before it,
        // is undone by calling it off.
        guard run.hasWritten else { return }
        let prayer = run.prayer
        enqueue {
            if let status = run.previousStatus {
                _ = try await LogPrayerWithStatusIntent(
                    prayer: prayer,
                    status: status,
                    date: run.day,
                    withJamaah: run.previousJamaah
                ).perform()
            } else {
                _ = try await RemovePrayerLogIntent(prayer: prayer, date: run.day).perform()
            }
        }
    }

    /// Ends the offer and writes anything still waiting. Called when
    /// the card moves to another day and when the screen goes away.
    func settle() {
        expiry?.cancel()
        guard let run = offer else { return }
        offer = nil
        if run.isRemoval {
            let prayer = run.prayer
            enqueue {
                _ = try await RemovePrayerLogIntent(prayer: prayer, date: run.day).perform()
            }
        }
    }

    // MARK: - What the screen draws

    /// The days with a waiting removal already taken out.
    func applying(to days: [DayCompletion]) -> [DayCompletion] {
        guard let run = offer, run.isRemoval else { return days }
        return days.map { day in
            guard day.date == run.day else { return day }
            return DayCompletion(
                id: day.id,
                date: day.date,
                prayerCompletions: day.prayerCompletions.map { completion in
                    completion.prayer == run.prayer
                        ? PrayerCompletion(prayer: run.prayer, status: nil, withJamaah: false)
                        : completion
                },
                isPaused: day.isPaused,
                isTraveling: day.isTraveling,
                needsReview: day.needsReview
            )
        }
    }

    // MARK: - Internals

    /// Opens a run, or continues the one already open on this prayer.
    private func begin(on day: Date, current: PrayerCompletion) {
        if let run = offer, run.prayer == current.prayer, run.day == day {
            // The same run: Undo still counts from the latest change,
            // and still returns to the state before the first.
        } else {
            settle()
            offer = Offer(
                day: day,
                prayer: current.prayer,
                previousStatus: current.status,
                previousJamaah: current.withJamaah,
                hasWritten: false,
                isRemoval: false
            )
        }
        startExpiry()
    }

    private func startExpiry() {
        expiry?.cancel()
        let interval = FocusedCardModel.undoInterval(voiceOver: UIAccessibility.isVoiceOverRunning)
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            self?.settle()
        }
    }

    private func enqueue(_ write: @escaping @MainActor () async throws -> Void) {
        let previous = writes
        writes = Task { @MainActor in
            await previous?.value
            do {
                try await write()
            } catch {
                Self.logger.error("Path write failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Said aloud under VoiceOver, with the way back named: the change
    /// is otherwise only seen.
    private func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        AccessibilityNotification.Announcement("\(message) Undo is available.").post()
    }
}
