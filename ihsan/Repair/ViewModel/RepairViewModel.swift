import Foundation
import IhsanCore
import SwiftData
import SwiftUI
import UserNotifications

/// Drives the Repair surface. Every mutation gives feedback first — the
/// haptic fires before persistence — and every write goes through
/// `QadaLedgerWriter` so the ledger and its log stay consistent.
@MainActor @Observable
final class RepairViewModel {
    enum ZeroEvent: Identifiable {
        case category(QadaCategory)
        case whole

        var id: String {
            switch self {
            case .category(let category): category.rawValue
            case .whole: "whole"
            }
        }
    }

    private let modelContext: ModelContext
    private let writer = QadaLedgerWriter()

    /// The just-logged entry, kept briefly so "made up · undo" can retire it
    /// without an alert.
    private(set) var recentEntry: QadaEntry?
    private(set) var recentEntryCategory: QadaCategory?
    var zeroEvent: ZeroEvent?

    @ObservationIgnored
    private var undoExpiry: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func logMadeUp(category: QadaCategory, count: Int = 1) {
        Haptics.impact(.soft)

        let remainingBefore = ledgerRow(for: category)?.remainingCount ?? 0
        do {
            let entry = try writer.recordMadeUp(
                category: category,
                count: count,
                in: modelContext
            )
            recentEntry = entry
            recentEntryCategory = category
            scheduleUndoExpiry()
            detectZeroCrossing(for: category, remainingBefore: remainingBefore)
        } catch {
            Haptics.notification(.warning)
        }
    }

    func undoRecent() {
        guard let recentEntry else {
            return
        }

        Haptics.impact(.light)
        try? writer.undo(recentEntry, in: modelContext)
        clearRecent()
    }

    /// Rewrites a category's remaining count via an adjustment entry, so the
    /// change is part of the append-only history.
    func adjustRemaining(for category: QadaCategory, to newValue: Int) {
        let current = ledgerRow(for: category)?.remainingCount ?? 0
        let delta = max(0, newValue) - current
        guard delta != 0 else {
            return
        }

        do {
            try writer.recordAdjustment(
                category: category,
                delta: delta,
                reason: nil,
                in: modelContext
            )
        } catch {
            Haptics.notification(.warning)
        }
    }

    func setDailyIntention(_ enabled: Bool, settings: UserSettings) {
        settings.qadaDailyIntentionEnabled = enabled
        settings.modifiedAt = .now

        if enabled {
            scheduleIntentionReminder()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [Self.intentionReminderIdentifier]
            )
        }
    }

    // MARK: - Private

    private static let intentionReminderIdentifier = "ihsan.repair.intention"

    private func scheduleIntentionReminder() {
        let content = UNMutableNotificationContent()
        content.title = "At your pace"
        content.body = "One prayer, when you're ready."
        content.sound = nil

        var components = DateComponents()
        components.hour = 21
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.intentionReminderIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func ledgerRow(for category: QadaCategory) -> QadaLedger? {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<QadaLedger>(
            predicate: #Predicate { $0.categoryRaw == raw }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func detectZeroCrossing(for category: QadaCategory, remainingBefore: Int) {
        guard remainingBefore > 0,
              let row = ledgerRow(for: category),
              row.remainingCount == 0
        else {
            return
        }

        let allRows = (try? modelContext.fetch(FetchDescriptor<QadaLedger>())) ?? []
        let wholeLedgerClear = allRows.allSatisfy { $0.remainingCount == 0 }
        zeroEvent = wholeLedgerClear ? .whole : .category(category)
    }

    private func scheduleUndoExpiry() {
        undoExpiry?.cancel()
        undoExpiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else {
                return
            }
            self?.clearRecent()
        }
    }

    private func clearRecent() {
        undoExpiry?.cancel()
        undoExpiry = nil
        recentEntry = nil
        recentEntryCategory = nil
    }
}
