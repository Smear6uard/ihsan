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
///
/// Resolved once per presentation and handed down: the moment is the
/// prayer's own instant, deliberately, so a Maghrib activity keeps
/// Maghrib's sky for its whole life instead of drifting toward night
/// while it stands.
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

/// The prayer's clock time in the place's own zone — the widget target
/// cannot see the app's `PlateTimeFormat`, and `Text(_, style: .time)`
/// would silently format in the device zone instead.
private func placeTime(_ date: Date, timeZoneIdentifier: String) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    return formatter.string(from: date)
}

struct PrayerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            PrayerLockScreenActivityView(
                context: context,
                tokens: activityTokens(at: context.attributes.scheduledTime)
            )
            .activityBackgroundTint(
                activityTokens(at: context.attributes.scheduledTime).ground
            )
            .widgetURL(WidgetDeeplink.logSheet(for: context.attributes.prayer))
            .activitySystemActionForegroundColor(
                activityTokens(at: context.attributes.scheduledTime).leafGold
            )
        } dynamicIsland: { context in
            let tokens = activityTokens(at: context.attributes.scheduledTime)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PrayerIslandExpandedLeading(context: context, tokens: tokens)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PrayerCountdownText(context: context, tokens: tokens, mode: .expanded)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PrayerIslandExpandedBottom(context: context, tokens: tokens)
                }
            } compactLeading: {
                LockOrnament(prayer: context.attributes.prayer, size: 14, isEmphasised: true)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(context.attributes.englishName)
            } compactTrailing: {
                PrayerCountdownText(context: context, tokens: tokens, mode: .compact)
                    .frame(minWidth: 42, alignment: .trailing)
            } minimal: {
                // Identity over arithmetic: a truncated H:MM:SS in a
                // 30-point slot said nothing. The ornament names the
                // prayer at a glance; the numbers live one tap away.
                LockOrnament(prayer: context.attributes.prayer, size: 14, isEmphasised: true)
                    .frame(width: 18, height: 18)
                    .accessibilityLabel(context.attributes.englishName)
            }
            .widgetURL(WidgetDeeplink.logSheet(for: context.attributes.prayer))
            .keylineTint(tokens.leafGold)
        }
    }
}

// MARK: - Lock screen

/// The lock-screen presentation, in the plate's own language: the
/// activity sits on the deepened 17-stop sky ramp every widget uses,
/// carries the prayer's ornament in its lifecycle state, and — while
/// the window is open — drains a gilded gauge toward the window's end
/// so the remaining time is visible without reading a numeral.
private struct PrayerLockScreenActivityView: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens

    private var isLogged: Bool { context.state.hasBeenLoggedThisActivity }
    private var phase: PrayerActivityAttributes.CountdownPhase { context.state.countdownPhase }

    private var ornamentState: PrayerMarkerState {
        if isLogged { return .logged }
        return phase == .preAdhan ? .upcoming : .current
    }

    var body: some View {
        ZStack {
            WidgetSkyGround(tokens: tokens, deepen: 0.10)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    PrayerMarkerOrnament(
                        prayer: context.attributes.prayer,
                        size: 30,
                        state: ornamentState,
                        tokens: tokens
                    )
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        PrayerActivityNameLine(context: context, tokens: tokens, mode: .lockScreen)
                        PrayerActivityStateLine(context: context, tokens: tokens)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    if !isLogged {
                        PrayerActivityCountdownNumeral(context: context, tokens: tokens)
                    }
                }
                .accessibilityElement(children: .combine)

                if !isLogged, phase == .adhanWindow {
                    PrayerWindowGauge(context: context, tokens: tokens)
                }

                if !isLogged {
                    HStack {
                        Spacer(minLength: 0)
                        PrayerActivityActions(context: context, tokens: tokens, compact: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// The one number that matters right now, in the plate's numeral
/// register: to the adhan before the window opens, to the window's end
/// once it has.
private struct PrayerActivityCountdownNumeral: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens

    var body: some View {
        Text(target, style: .timer)
            .font(.system(size: 24, weight: .light, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(tokens.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 92, alignment: .trailing)
            .accessibilityLabel(
                context.state.countdownPhase == .preAdhan
                    ? "Time remaining until \(context.attributes.englishName)"
                    : "Time remaining in the \(context.attributes.englishName) window"
            )
    }

    private var target: Date {
        context.state.countdownPhase == .preAdhan
            ? context.attributes.scheduledTime
            : context.attributes.windowEnd
    }
}

/// The window draining, as a thin gilded band. Auto-updating — the
/// system advances a timer-interval gauge without any push or process.
private struct PrayerWindowGauge: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens

    var body: some View {
        // min() mirrors WidgetTimerInterval's guard: a ClosedRange with
        // start after end traps, and a malformed schedule must degrade
        // to a full bar, never a blank activity.
        let start = min(context.attributes.scheduledTime, context.attributes.windowEnd)
        ProgressView(
            timerInterval: start...context.attributes.windowEnd,
            countsDown: true,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.linear)
        .tint(tokens.leafGold)
        .accessibilityLabel("Time remaining in the \(context.attributes.englishName) window")
    }
}

// MARK: - Dynamic Island

private struct PrayerIslandExpandedLeading: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens

    var body: some View {
        HStack(spacing: 8) {
            PrayerMarkerOrnament(
                prayer: context.attributes.prayer,
                size: 20,
                state: context.state.hasBeenLoggedThisActivity
                    ? .logged
                    : (context.state.countdownPhase == .preAdhan ? .upcoming : .current),
                tokens: tokens
            )
            .frame(width: 26, height: 26)
            PrayerActivityNameLine(context: context, tokens: tokens, mode: .expanded)
        }
    }
}

private struct PrayerIslandExpandedBottom: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !context.state.hasBeenLoggedThisActivity,
               context.state.countdownPhase == .adhanWindow {
                PrayerWindowGauge(context: context, tokens: tokens)
            }
            HStack(alignment: .center, spacing: 10) {
                PrayerActivityStateLine(context: context, tokens: tokens, usesDarkSurface: true)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                PrayerActivityActions(context: context, tokens: tokens, compact: true)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Shared lines

private struct PrayerActivityNameLine: View {
    enum Mode { case lockScreen, expanded }

    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens
    let mode: Mode

    var body: some View {
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

private struct PrayerActivityStateLine: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens
    var usesDarkSurface = false

    var body: some View {
        Group {
            if context.state.hasBeenLoggedThisActivity {
                Text("LOGGED")
            } else if context.state.countdownPhase == .preAdhan {
                Text("OPENS · \(placeTime(context.attributes.scheduledTime, timeZoneIdentifier: context.attributes.timeZoneIdentifier))")
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

// MARK: - Actions

private struct PrayerActivityActions: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens
    let compact: Bool

    var body: some View {
        if context.state.hasBeenLoggedThisActivity {
            Text("LOGGED")
                .font(IhsanFont.inscription)
                .tracking(1.2)
                .foregroundStyle(compact ? tokens.metalHighlight : tokens.inkSecondary)
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
                        .frame(minHeight: compact ? 30 : 40)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(compact ? tokens.metal : tokens.inkSecondary)
                .accessibilityLabel("Choose another \(context.attributes.englishName) status")

                PrayerActivityLogButton(context: context, tokens: tokens, compact: compact)
            }
        }
    }
}

private struct PrayerActivityLogButton: View {
    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens
    let compact: Bool

    var body: some View {
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

// MARK: - Island countdown

private struct PrayerCountdownText: View {
    enum Mode {
        case expanded
        case compact
    }

    let context: ActivityViewContext<PrayerActivityAttributes>
    let tokens: SkyPaletteTokens
    let mode: Mode

    var body: some View {
        Group {
            if context.state.hasBeenLoggedThisActivity {
                Image(systemName: "checkmark")
                    .font(.system(size: mode == .expanded ? 15 : 11, weight: .semibold))
                    .foregroundStyle(tokens.metalHighlight)
            } else {
                Text(countdownTarget, style: .timer)
                    .font(font)
                    .monospacedDigit()
            }
        }
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

// MARK: - Live Activity capture states

private let prayerActivityPreviewAttributes = PrayerActivityAttributes(
    prayer: .isha,
    scheduledTime: .now.addingTimeInterval(-20 * 60),
    windowEnd: .now.addingTimeInterval(7 * 3_600),
    timeZoneIdentifier: "America/Chicago",
    arabicName: Prayer.isha.displayNameArabic,
    englishName: Prayer.isha.displayNameEnglish
)

private let prayerActivityPreviewState = PrayerActivityAttributes.ContentState(
    countdownPhase: .adhanWindow
)

private let prayerActivityPreviewLoggedState = PrayerActivityAttributes.ContentState(
    countdownPhase: .postAdhan,
    hasBeenLoggedThisActivity: true
)

#Preview("Live Activity · Lock Screen", as: .content, using: prayerActivityPreviewAttributes) {
    PrayerActivityWidget()
} contentStates: {
    prayerActivityPreviewState
    prayerActivityPreviewLoggedState
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
