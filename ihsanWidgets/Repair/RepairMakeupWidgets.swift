import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Snapshot

struct RepairTimelineEntry: TimelineEntry {
    let date: Date
    let isTracking: Bool
    let totalRemaining: Int

    static func placeholder() -> RepairTimelineEntry {
        RepairTimelineEntry(date: .now, isTracking: true, totalRemaining: 214)
    }
}

/// Reads the shared store directly, degrading to the placeholder whenever
/// the container is unavailable — same posture as `WidgetSnapshotLoader`.
@MainActor
private struct RepairSnapshotLoader {
    func entry(at date: Date) -> RepairTimelineEntry {
        guard let container = try? IhsanModelContainerFactory.makeContainer() else {
            return .placeholder()
        }
        let context = ModelContext(container)
        let settings = (try? UserSettings.fetchOrCreate(in: context))
        let ledgers = (try? context.fetch(FetchDescriptor<QadaLedger>())) ?? []
        return RepairTimelineEntry(
            date: date,
            isTracking: settings?.qadaTrackingEnabled ?? false,
            totalRemaining: ledgers.reduce(0) { $0 + $1.remainingCount }
        )
    }
}

struct RepairTimelineProvider: TimelineProvider {
    typealias Entry = RepairTimelineEntry

    func placeholder(in context: Context) -> RepairTimelineEntry {
        .placeholder()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (RepairTimelineEntry) -> Void
    ) {
        Task { @MainActor in
            if context.isPreview {
                completion(.placeholder())
                return
            }
            completion(RepairSnapshotLoader().entry(at: .now))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<RepairTimelineEntry>) -> Void
    ) {
        Task { @MainActor in
            let entry = RepairSnapshotLoader().entry(at: .now)
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

// MARK: - Lock Screen widget

/// One-tap "+1 made up" from the Lock Screen. The face is the Lawzina
/// terminal ornament over the quiet remaining count; the whole face is the
/// button, writing through `LogMakeupPrayerIntent` — the same funnel as
/// every other surface, so counts reconcile on next app foreground.
struct RepairMakeupCircularWidgetView: View {
    let entry: RepairTimelineEntry

    var body: some View {
        Button(intent: LogMakeupPrayerIntent()) {
            VStack(spacing: 1) {
                PrayerOrnamentShape(prayer: .maghrib, mode: .filled)
                    .fill(.primary, style: FillStyle(eoFill: true))
                    .frame(width: 20, height: 20)

                if entry.isTracking, entry.totalRemaining > 0 {
                    Text(entry.totalRemaining.formatted(.number.grouping(.automatic)))
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("+1")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .widgetAccentable()
        .accessibilityLabel(
            entry.isTracking
                ? "Log one made up. \(entry.totalRemaining) remaining."
                : "Log one made up."
        )
    }
}

struct RepairMakeupCircularWidget: Widget {
    static let kind: String = "RepairMakeupCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RepairTimelineProvider()) { entry in
            RepairMakeupCircularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Makeup Prayer")
        .description("One tap logs one made-up prayer, at your pace.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Control Center control

/// The Control Center "+1 made up" button. Runs the same intent funnel;
/// the glyph is the app's own qadā mark (the return arrow used across the
/// design system), not a decorative star.
struct RepairMakeupControl: ControlWidget {
    static let kind: String = "RepairMakeupControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogMakeupPrayerIntent()) {
                Label("+1 made up", systemImage: "arrow.uturn.backward")
            }
        }
        .displayName("Makeup Prayer")
        .description("Log one made-up prayer, at your pace.")
    }
}
