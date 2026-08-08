#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import IhsanPrayerTimes
import SwiftUI
import WidgetKit

/// The palette a Live Activity paints with.
///
/// The activity has no timeline entry, but it runs in the same process
/// family as the widgets and can read the same App Group schedule — so
/// its ground rides the real solar events rather than a clock guess,
/// exactly like every other surface.
@available(iOSApplicationExtension 16.2, *)
private func activityTokens(at date: Date) -> SkyPaletteTokens {
    guard
        let cache = PrayerTimesCacheStore.read(),
        let schedule = cache.resolverSchedule
    else {
        return IhsanPageChrome.tokens(at: date)
    }
    return PaletteState.resolved(for: SkyPhase.resolve(
        at: date,
        events: SolarDayEvents(
            fajr: schedule.fajr.scheduledTime,
            sunrise: schedule.sunrise,
            solarNoon: schedule.dhuhr.scheduledTime,
            maghrib: schedule.maghrib.scheduledTime,
            isha: schedule.isha.scheduledTime
        )
    ))
}

@available(iOSApplicationExtension 16.2, *)
struct PrayerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            PrayerLockScreenActivityView(context: context)
                .activityBackgroundTint(
                    activityTokens(at: context.attributes.scheduledTime).ground
                )
                .widgetURL(WidgetDeeplink.logSheet(for: context.attributes.prayer))
                .activitySystemActionForegroundColor(
                    activityTokens(at: context.attributes.scheduledTime).leafGold
                )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PrayerIslandExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PrayerCountdownText(context: context, mode: .expanded)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PrayerIslandExpandedBottom(context: context)
                }
            } compactLeading: {
                LockOrnament(prayer: context.attributes.prayer, size: 14, isEmphasised: true)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(context.attributes.englishName)
            } compactTrailing: {
                PrayerCountdownText(context: context, mode: .compact)
                    .frame(minWidth: 42, alignment: .trailing)
            } minimal: {
                PrayerCountdownText(context: context, mode: .minimal)
                    .frame(maxWidth: 30)
            }
            .widgetURL(WidgetDeeplink.logSheet(for: context.attributes.prayer))
            .keylineTint(activityTokens(at: context.attributes.scheduledTime).leafGold)
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerLockScreenActivityView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)

        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 12) {
                PrayerMarkerOrnament(
                    prayer: context.attributes.prayer,
                    size: 28,
                    state: context.state.countdownPhase == .preAdhan ? .upcoming : .current,
                    tokens: tokens
                )
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 5) {
                    PrayerActivityNameLine(context: context, mode: .lockScreen)
                    PrayerActivityStateLine(context: context)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            if !context.state.hasBeenLoggedThisActivity {
                HStack {
                    Spacer(minLength: 0)
                    PrayerActivityActions(context: context, compact: false)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerIslandExpandedLeading: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)
        HStack(spacing: 8) {
            PrayerMarkerOrnament(
                prayer: context.attributes.prayer,
                size: 20,
                state: context.state.countdownPhase == .preAdhan ? .upcoming : .current,
                tokens: tokens
            )
            .frame(width: 26, height: 26)
            PrayerActivityNameLine(context: context, mode: .expanded)
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerIslandExpandedBottom: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PrayerActivityStateLine(context: context, usesDarkSurface: true)
                .layoutPriority(1)
            Spacer(minLength: 4)
            PrayerActivityActions(context: context, compact: true)
        }
        .padding(.top, 4)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerActivityNameLine: View {
    enum Mode { case lockScreen, expanded }

    let context: ActivityViewContext<PrayerActivityAttributes>
    let mode: Mode

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)
        let english = Text(context.attributes.englishName)
            .font(.system(size: mode == .lockScreen ? 19 : 16, weight: .semibold, design: .serif))
            .foregroundColor(mode == .lockScreen ? tokens.ink : tokens.metalHighlight)
        let arabic = Text(context.attributes.arabicName)
            .font(mode == .lockScreen ? IhsanFont.bodyArabic : .system(size: 15, weight: .regular))
            .foregroundColor(mode == .lockScreen ? tokens.inkSecondary : tokens.metal)

        Text("\(english) \(arabic)")
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .accessibilityLabel("\(context.attributes.englishName), \(context.attributes.arabicName)")
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerActivityStateLine: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    var usesDarkSurface = false

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)
        Group {
            if context.state.hasBeenLoggedThisActivity {
                Text("LOGGED")
            } else if context.state.countdownPhase == .preAdhan {
                HStack(spacing: 3) {
                    Text("OPENS IN ·")
                    Text(context.attributes.scheduledTime, style: .timer)
                        .monospacedDigit()
                }
            } else {
                Text(activeWindowLine.uppercased())
            }
        }
        .font(IhsanFont.inscription)
        .tracking(1.05)
        .foregroundStyle(usesDarkSurface ? tokens.metal : tokens.inkSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .allowsTightening(true)
    }

    private var activeWindowLine: String {
        let timeZone = TimeZone(identifier: context.attributes.timeZoneIdentifier) ?? .current
        return PrayerWindowText.activeLine(
            until: context.attributes.windowEnd,
            timeZone: timeZone,
            windowEndDescriptor: PrayerWindowText.windowEndDescriptor(
                for: context.attributes.prayer
            )
        )
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerActivityActions: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let compact: Bool

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)
        if context.state.hasBeenLoggedThisActivity {
            Text("LOGGED")
                .font(IhsanFont.inscription)
                .tracking(1.2)
                .foregroundStyle(tokens.inkSecondary)
        } else if context.state.countdownPhase == .preAdhan {
            Link(destination: WidgetDeeplink.logSheet(for: context.attributes.prayer)) {
                Text("Open")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                    .frame(minWidth: compact ? 50 : 62, minHeight: compact ? 30 : 36)
            }
            .foregroundStyle(compact ? tokens.metalHighlight : tokens.ink)
            .accessibilityLabel("Open \(context.attributes.englishName) in Ihsan")
        } else {
            HStack(spacing: compact ? 7 : 9) {
                Link(destination: WidgetDeeplink.logSheet(for: context.attributes.prayer)) {
                    Text("Other")
                        .font(IhsanFont.inscription)
                        .tracking(0.8)
                        .lineLimit(1)
                }
                .foregroundStyle(compact ? tokens.metal : tokens.inkSecondary)
                .accessibilityLabel("Choose another \(context.attributes.englishName) status")

                PrayerActivityLogButton(context: context, compact: compact)
            }
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerActivityLogButton: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let compact: Bool

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)

        Button(intent: LogPrayerIntent(prayer: context.attributes.prayer)) {
            Text("I prayed")
                .font(buttonFont)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: compact ? 72 : 94, minHeight: compact ? 32 : 40)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tokens.keyline)
        .background { Capsule().fill(tokens.leafGold) }
        .overlay {
            Capsule().strokeBorder(tokens.keyline.opacity(0.6), lineWidth: 0.75)
        }
        .accessibilityLabel("I prayed \(context.attributes.englishName), on time")
    }

    private var buttonFont: Font {
        .system(size: compact ? 13 : 15, weight: .semibold, design: .rounded)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerCountdownText: View {
    enum Mode {
        case expanded
        case compact
        case minimal
    }

    let context: ActivityViewContext<PrayerActivityAttributes>
    let mode: Mode

    var body: some View {
        Group {
            if context.state.hasBeenLoggedThisActivity {
                Text("Logged")
            } else {
                Text(countdownTarget, style: .timer)
            }
        }
        .font(font)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.62)
        .allowsTightening(true)
        .accessibilityLabel(accessibilityLabel)
    }

    private var countdownTarget: Date {
        context.state.countdownPhase == .preAdhan
            ? context.attributes.scheduledTime
            : context.attributes.windowEnd
    }

    private var font: Font {
        switch mode {
        case .expanded:
            return .system(size: 17, weight: .semibold, design: .rounded)
        case .compact:
            return .system(size: 12, weight: .semibold, design: .rounded)
        case .minimal:
            return .system(size: 10, weight: .bold, design: .rounded)
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
            return "Time remaining in the \(context.attributes.englishName) window"
        }
    }
}

struct DismissPrayerActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss Prayer Activity"
    static var description = IntentDescription("Dismisses the current prayer Live Activity.")
    static var openAppWhenRun: Bool = false

    // No per-property availability: the enclosing intent is already
    // gated at 16.2, and a narrower annotation gives the synthesised
    // setter an availability its own scope cannot honour.
    @Parameter(title: "Prayer")
    var prayer: PrayerEntity

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

// MARK: - Live Activity capture states

@available(iOSApplicationExtension 17.0, *)
private let prayerActivityPreviewAttributes = PrayerActivityAttributes(
    prayer: .isha,
    scheduledTime: .now.addingTimeInterval(-20 * 60),
    windowEnd: .now.addingTimeInterval(7 * 3_600),
    timeZoneIdentifier: "America/Chicago",
    arabicName: Prayer.isha.displayNameArabic,
    englishName: Prayer.isha.displayNameEnglish
)

@available(iOSApplicationExtension 17.0, *)
private let prayerActivityPreviewState = PrayerActivityAttributes.ContentState(
    countdownPhase: .adhanWindow
)

#Preview("Live Activity · Lock Screen", as: .content, using: prayerActivityPreviewAttributes) {
    PrayerActivityWidget()
} contentStates: {
    prayerActivityPreviewState
}

#Preview("Dynamic Island · Compact", as: .dynamicIsland(.compact), using: prayerActivityPreviewAttributes) {
    PrayerActivityWidget()
} contentStates: {
    prayerActivityPreviewState
}

#Preview("Dynamic Island · Minimal", as: .dynamicIsland(.minimal), using: prayerActivityPreviewAttributes) {
    PrayerActivityWidget()
} contentStates: {
    prayerActivityPreviewState
}

#Preview("Dynamic Island · Expanded", as: .dynamicIsland(.expanded), using: prayerActivityPreviewAttributes) {
    PrayerActivityWidget()
} contentStates: {
    prayerActivityPreviewState
}
#endif
