#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.2, *)
struct PrayerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            PrayerLockScreenActivityView(context: context)
                .activitySystemActionForegroundColor(IhsanColor.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PrayerIslandExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PrayerIslandExpandedActions(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PrayerIslandExpandedBottom(context: context)
                }
            } compactLeading: {
                PrayerSymbol(context.attributes.prayer, size: 14)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(context.attributes.englishName)
            } compactTrailing: {
                PrayerCountdownText(context: context, mode: .compact)
                    .frame(minWidth: 42, alignment: .trailing)
            } minimal: {
                PrayerSymbol(context.attributes.prayer, size: 13)
                    .accessibilityLabel(context.attributes.englishName)
            }
            .keylineTint(IhsanColor.textSecondary)
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerLockScreenActivityView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                PrayerSymbol(context.attributes.prayer, size: 24)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(context.attributes.englishName)
                            .font(IhsanFont.bodyEnglishBold)
                            .foregroundStyle(IhsanColor.textPrimary)
                        Text(context.attributes.arabicName)
                            .font(IhsanFont.bodyArabic)
                            .foregroundStyle(IhsanColor.textSecondary)
                    }
                    Text(context.attributes.scheduledTime, format: .dateTime.hour().minute())
                        .font(IhsanFont.tabular)
                        .foregroundStyle(IhsanColor.textSecondary)
                }

                Spacer(minLength: 8)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    PrayerCountdownText(context: context, mode: .lockScreen)
                    Text(statusLine)
                        .font(IhsanFont.smallCaps)
                        .foregroundStyle(IhsanColor.textSecondary)
                }

                Spacer(minLength: 8)

                PrayerActivityLogButton(context: context, compact: false)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        if context.state.hasBeenLoggedThisActivity {
            return "Logged"
        }

        switch context.state.countdownPhase {
        case .preAdhan:
            return "Until adhan"
        case .adhanWindow:
            return "Adhan time"
        case .postAdhan:
            return "After adhan"
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerIslandExpandedLeading: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            PrayerSymbol(context.attributes.prayer, size: 20)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.englishName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IhsanColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(context.attributes.arabicName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(IhsanColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerIslandExpandedActions: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            PrayerActivityLogButton(context: context, compact: true)
            Button(intent: DismissPrayerActivityIntent(
                prayer: context.attributes.prayer,
                scheduledTime: context.attributes.scheduledTime
            )) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(IhsanColor.textSecondary)
            .accessibilityLabel("Dismiss \(context.attributes.englishName) activity")
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerIslandExpandedBottom: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            PrayerCountdownText(context: context, mode: .expanded)
            Spacer(minLength: 8)
            Text(context.attributes.scheduledTime, format: .dateTime.hour().minute())
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(IhsanColor.textSecondary)
        }
        .padding(.top, 2)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerActivityLogButton: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let compact: Bool

    var body: some View {
        if context.state.hasBeenLoggedThisActivity {
            Label("Logged", systemImage: "checkmark.circle.fill")
                .font(buttonFont)
                .foregroundStyle(IhsanColor.textPrimary)
                .frame(minWidth: compact ? 70 : 104, minHeight: compact ? 32 : 44)
                .accessibilityLabel("\(context.attributes.englishName) logged")
        } else {
            Button(intent: LogPrayerIntent(prayer: context.attributes.prayer)) {
                Label(compact ? "Prayed" : "I prayed", systemImage: "checkmark")
                    .font(buttonFont)
                    .frame(minWidth: compact ? 70 : 104, minHeight: compact ? 32 : 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(buttonForeground)
            .background {
                Capsule()
                    .fill(buttonFill)
            }
            .overlay {
                Capsule()
                    .strokeBorder(IhsanColor.textPrimary.opacity(isPrimaryMoment ? 0.32 : 0.16), lineWidth: 0.75)
            }
            .accessibilityLabel("I prayed \(context.attributes.englishName)")
        }
    }

    private var isPrimaryMoment: Bool {
        context.state.countdownPhase == .adhanWindow
    }

    private var buttonFont: Font {
        .system(size: compact ? 13 : 15, weight: .semibold, design: .rounded)
    }

    private var buttonForeground: Color {
        isPrimaryMoment ? .black.opacity(0.92) : IhsanColor.textPrimary
    }

    private var buttonFill: Color {
        isPrimaryMoment ? .white.opacity(0.92) : .white.opacity(0.14)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerCountdownText: View {
    enum Mode {
        case lockScreen
        case expanded
        case compact
    }

    let context: ActivityViewContext<PrayerActivityAttributes>
    let mode: Mode

    var body: some View {
        Group {
            if context.state.hasBeenLoggedThisActivity {
                Text("Logged")
            } else {
                switch context.state.countdownPhase {
                case .preAdhan:
                    Text("-\(context.attributes.scheduledTime, style: .timer)")
                case .adhanWindow:
                    Text("Now")
                case .postAdhan:
                    Text("Now")
                }
            }
        }
        .font(font)
        .monospacedDigit()
        .foregroundStyle(IhsanColor.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .accessibilityLabel(accessibilityLabel)
    }

    private var font: Font {
        switch mode {
        case .lockScreen:
            return .system(size: 40, weight: .medium, design: .rounded)
        case .expanded:
            return .system(size: 22, weight: .semibold, design: .rounded)
        case .compact:
            return .system(size: 13, weight: .semibold, design: .rounded)
        }
    }

    private var accessibilityLabel: String {
        if context.state.hasBeenLoggedThisActivity {
            return "\(context.attributes.englishName) logged"
        }

        switch context.state.countdownPhase {
        case .preAdhan:
            return "Time remaining until \(context.attributes.englishName)"
        case .adhanWindow, .postAdhan:
            return "\(context.attributes.englishName) is now"
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
struct DismissPrayerActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss Prayer Activity"
    static var description = IntentDescription("Dismisses the current prayer Live Activity.")
    static var openAppWhenRun: Bool = false

    @available(iOSApplicationExtension 16.2, *)
    @Parameter(title: "Prayer")
    var prayer: PrayerEntity

    @available(iOSApplicationExtension 16.2, *)
    @Parameter(title: "Scheduled Time")
    var scheduledTime: Date

    init() {}

    init(prayer: Prayer, scheduledTime: Date) {
        self.prayer = PrayerEntity(prayer: prayer)
        self.scheduledTime = scheduledTime
    }

    func perform() async throws -> some IntentResult {
        guard let prayer = prayer.prayer else {
            return .result()
        }

        for activity in Activity<PrayerActivityAttributes>.activities where
            activity.attributes.prayer == prayer &&
            abs(activity.attributes.scheduledTime.timeIntervalSince(scheduledTime)) < 1
        {
            let state = PrayerActivityAttributes.ContentState(
                countdownPhase: activity.content.state.countdownPhase,
                hasBeenLoggedThisActivity: activity.content.state.hasBeenLoggedThisActivity
            )
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        return .result()
    }
}
#endif
