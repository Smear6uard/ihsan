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
                .activitySystemActionForegroundColor(
                    activityTokens(at: context.attributes.scheduledTime).leafGold
                )
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
                LockOrnament(prayer: context.attributes.prayer, size: 14, isEmphasised: true)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(context.attributes.englishName)
            } compactTrailing: {
                PrayerCountdownText(context: context, mode: .compact)
                    .frame(minWidth: 42, alignment: .trailing)
            } minimal: {
                LockOrnament(prayer: context.attributes.prayer, size: 13, isEmphasised: true)
                    .accessibilityLabel(context.attributes.englishName)
            }
            .keylineTint(activityTokens(at: context.attributes.scheduledTime).leafGold)
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerLockScreenActivityView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                PrayerMarkerOrnament(
                    prayer: context.attributes.prayer,
                    size: 26,
                    state: context.state.countdownPhase == .preAdhan ? .upcoming : .current,
                    tokens: tokens
                )
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(context.attributes.englishName)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(tokens.ink)
                        Text(context.attributes.arabicName)
                            .font(IhsanFont.bodyArabic)
                            .foregroundStyle(tokens.inkSecondary)
                    }
                    Text(context.attributes.scheduledTime, format: .dateTime.hour().minute())
                        .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(tokens.inkSecondary)
                }

                Spacer(minLength: 8)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    PrayerCountdownText(context: context, mode: .lockScreen)
                        .foregroundStyle(tokens.ink)
                    Text(statusLine)
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(tokens.inkSecondary)
                }

                Spacer(minLength: 8)

                PrayerActivityLogButton(context: context, compact: false)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// The inscription register: small caps, stating where in the
    /// prayer's own window this moment is. Never "soon", never a nudge.
    private var statusLine: String {
        if context.state.hasBeenLoggedThisActivity {
            return "LOGGED"
        }

        switch context.state.countdownPhase {
        case .preAdhan:
            return "UNTIL ADHAN"
        case .adhanWindow:
            return "ADHAN"
        case .postAdhan:
            return "THE WINDOW IS OPEN"
        }
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
            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.englishName)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(context.attributes.arabicName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(tokens.inkSecondary)
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
        let tokens = activityTokens(at: context.attributes.scheduledTime)
        HStack(spacing: 8) {
            PrayerActivityLogButton(context: context, compact: true)
            Button(intent: DismissPrayerActivityIntent(
                prayer: context.attributes.prayer,
                scheduledTime: context.attributes.scheduledTime
            )) {
                // A drawn cross, like every other mark in the app.
                DismissMark()
                    .stroke(
                        tokens.inkSecondary,
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )
                    .frame(width: 11, height: 11)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss \(context.attributes.englishName) activity")
        }
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerIslandExpandedBottom: View {
    let context: ActivityViewContext<PrayerActivityAttributes>

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)
        HStack(spacing: 8) {
            PrayerCountdownText(context: context, mode: .expanded)
                .foregroundStyle(tokens.ink)
            Spacer(minLength: 8)
            Text(context.attributes.scheduledTime, format: .dateTime.hour().minute())
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(tokens.inkSecondary)
        }
        .padding(.top, 2)
    }
}

@available(iOSApplicationExtension 16.2, *)
private struct PrayerActivityLogButton: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let compact: Bool

    var body: some View {
        let tokens = activityTokens(at: context.attributes.scheduledTime)

        if context.state.hasBeenLoggedThisActivity {
            Text("LOGGED")
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(tokens.leafGold)
                .frame(minWidth: compact ? 70 : 104, minHeight: compact ? 32 : 44)
                .accessibilityLabel("\(context.attributes.englishName) logged")
        } else {
            Button(intent: LogPrayerIntent(prayer: context.attributes.prayer)) {
                Text(compact ? "Prayed" : "I prayed")
                    .font(buttonFont)
                    .frame(minWidth: compact ? 70 : 104, minHeight: compact ? 32 : 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // At the adhan itself the button is gold leaf on lapis —
            // the same gilding the current ornament wears. Before it,
            // the same shape, quiet.
            .foregroundStyle(isPrimaryMoment ? tokens.lapis : tokens.ink)
            .background {
                Capsule().fill(isPrimaryMoment ? tokens.leafGold : tokens.panelFill)
            }
            .overlay {
                Capsule().strokeBorder(
                    isPrimaryMoment ? tokens.keyline.opacity(0.6) : tokens.panelStroke,
                    lineWidth: 0.75
                )
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
}

/// The dismissal cross, drawn rather than borrowed.
private struct DismissMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
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
#endif
