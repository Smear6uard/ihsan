import Foundation
import SwiftData

/// One event in the append-only makeup ledger log. Ledger state is derived
/// by replaying entries in `createdAt` order; the log itself also draws the
/// Repair thread and the pace forecast.
@Model
public final class QadaEntry {
    public var id: UUID = UUID()

    public var categoryRaw: String = QadaCategory.fajr.rawValue
    public var kindRaw: String = QadaEntryKind.estimated.rawValue

    /// Meaning depends on `kind`: `.estimated` → initial count,
    /// `.adjusted` → signed delta, `.madeUp` → prayers made up,
    /// `.missedFlowedIn` → always 1.
    public var amount: Int = 0

    /// The day this event credits or refers to: the day a makeup was prayed,
    /// or the day whose prayer flowed in. Nil for estimates and adjustments.
    public var forDate: Date?

    @Attribute(.allowsCloudEncryption)
    public var reason: String?

    public var sourceSurfaceRaw: String = SourceSurface.app.rawValue

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<QadaEntry>([\.createdAt])

    public init(
        id: UUID = UUID(),
        category: QadaCategory,
        kind: QadaEntryKind,
        amount: Int,
        forDate: Date? = nil,
        reason: String? = nil,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.forDate = forDate
        self.reason = reason
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension QadaEntry {
    var category: QadaCategory? {
        QadaCategory(rawValue: categoryRaw)
    }

    var kind: QadaEntryKind? {
        QadaEntryKind(rawValue: kindRaw)
    }

    var sourceSurface: SourceSurface? {
        SourceSurface(rawValue: sourceSurfaceRaw)
    }

    static func estimated(
        category: QadaCategory,
        count: Int,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now
    ) -> QadaEntry {
        QadaEntry(
            category: category,
            kind: .estimated,
            amount: count,
            sourceSurface: sourceSurface,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    static func adjusted(
        category: QadaCategory,
        delta: Int,
        reason: String?,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now
    ) -> QadaEntry {
        QadaEntry(
            category: category,
            kind: .adjusted,
            amount: delta,
            reason: reason,
            sourceSurface: sourceSurface,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    static func madeUp(
        category: QadaCategory,
        count: Int,
        date: Date,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now
    ) -> QadaEntry {
        QadaEntry(
            category: category,
            kind: .madeUp,
            amount: count,
            forDate: date,
            sourceSurface: sourceSurface,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }

    static func missedFlowedIn(
        prayer: Prayer,
        date: Date,
        sourceSurface: SourceSurface = .app,
        createdAt: Date = .now
    ) -> QadaEntry {
        QadaEntry(
            category: QadaCategory(prayer: prayer),
            kind: .missedFlowedIn,
            amount: 1,
            forDate: date,
            sourceSurface: sourceSurface,
            createdAt: createdAt,
            modifiedAt: createdAt
        )
    }
}
