import SwiftUI
import IhsanDesignSystem

enum Tab: Int, CaseIterable, Hashable, Identifiable {
    case today
    case trajectory
    case reflection
    case settings

    var id: Self { self }

    /// Manuscript-style small caps inscription rendered beneath the
    /// icon. Kept terse so each label fits its tab column on every
    /// iPhone width.
    var title: String {
        switch self {
        case .today: "TODAY"
        case .trajectory: "PATH"
        case .reflection: "REFLECT"
        case .settings: "SET"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "calendar"
        case .trajectory: "chart.dots.scatter"
        case .reflection: "book.closed"
        case .settings: "gearshape"
        }
    }

    /// Long form spoken by VoiceOver. The visible label is small caps
    /// shorthand ("SET") but the spoken label is the full word
    /// ("Settings tab") so the rotor reads naturally.
    var accessibilityLabel: String {
        switch self {
        case .today: "Today tab"
        case .trajectory: "Trajectory tab"
        case .reflection: "Reflection tab"
        case .settings: "Settings tab"
        }
    }
}

/// The bottom tab bar.
///
/// The container reads as iOS 26 Liquid Glass — `.glassEffect()`
/// applied to a rounded rectangle so the platform's native iridescence
/// and refraction of the manuscript page beneath comes through. In
/// daytime mode a thin warm-amber backing (`parchmentDeep` at 30 %
/// opacity) sits BEHIND the glass so the bar reads against the cream
/// daylight sky — without that backing the glass blends into the page
/// and the tab labels lose contrast. Night mode leaves the glass over
/// the dark page as-is.
///
/// Per-tab cells render an SF Symbol over a small-caps inscription
/// (TODAY · PATH · REFLECT · SET); the active tab is marked by a gold
/// icon and a small brass underline that slides between cells along
/// with the drag gesture.
struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var committedDragOffset: CGFloat = 0

    private let commitThreshold: CGFloat = 50
    private let rubberBandLimit: CGFloat = 36
    private let underlineWidth: CGFloat = 22
    private let underlineHeight: CGFloat = 1.5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            tabBar(referenceDate: context.date)
        }
    }

    @ViewBuilder
    private func tabBar(referenceDate: Date) -> some View {
        let isDayMode = !IhsanCelestialPalette.isNight(at: referenceDate)
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(Tab.allCases.count)
            let effectiveOffset = rubberBandedOffset(
                committedDragOffset + dragTranslation,
                itemWidth: itemWidth
            )

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        tabButton(tab)
                            .frame(width: itemWidth)
                    }
                }

                // The active-tab underline. Centred horizontally on
                // the selected cell and offset by the drag gesture so
                // the user sees their finger move the marker before
                // commit. Drawn last so it sits above the tab content.
                activeUnderline
                    .frame(width: underlineWidth, height: underlineHeight)
                    .offset(
                        x: underlineX(itemWidth: itemWidth) + effectiveOffset,
                        y: underlineY
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: IhsanSpacing.cardRadius, style: .continuous))
            .gesture(dragGesture(itemWidth: itemWidth))
            .accessibilityElement(children: .contain)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    selectAdjacent(delta: 1)
                case .decrement:
                    selectAdjacent(delta: -1)
                @unknown default:
                    break
                }
            }
        }
        .frame(height: IhsanSpacing.tabBarHeight)
        .padding(IhsanSpacing.xs)
        .background {
            // Daytime: a thin warm-amber backing sits behind the
            // glass so the bar reads against the cream daylight sky.
            // The glass effect above refracts this backing along with
            // the page beneath, producing a visible "footer band".
            if isDayMode {
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.cardRadius,
                    style: .continuous
                )
                .fill(IhsanColor.parchmentDeep.opacity(0.30))
            }
        }
        // iOS 26 native Liquid Glass — system iridescence and
        // refraction of the manuscript page beneath. The bare
        // `.glassEffect` (no custom tint) is intentional: chrome
        // surfaces are the only places the platform's native glass
        // appears, and applying our own tint here would muddy that.
        // Daytime contrast is solved by the backing layer above, not
        // by tinting the glass itself.
        .glassEffect(
            .regular,
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            )
        )
    }

    // MARK: - Tab button

    private func tabButton(_ tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            committedDragOffset = 0
            guard selectedTab != tab else { return }
            Haptics.impact(.medium)
            withAnimation(tabAnimation) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        isSelected
                            ? IhsanColor.gold
                            : IhsanColor.brass.opacity(0.60)
                    )

                Text(tab.title)
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(
                        isSelected
                            ? IhsanColor.brass
                            : IhsanColor.brass.opacity(0.60)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Active underline

    private var activeUnderline: some View {
        Capsule(style: .continuous)
            .fill(IhsanIridescence.brassStroke(opacity: 0.95))
    }

    private func underlineX(itemWidth: CGFloat) -> CGFloat {
        CGFloat(selectedTab.rawValue) * itemWidth + (itemWidth - underlineWidth) / 2
    }

    /// Vertical position of the underline. Tuned to sit just below
    /// the icon row and just above the label. The constant is
    /// stable across iPhone sizes because the tab cell's content
    /// metrics (icon ~17pt, spacing 8pt) don't scale with width.
    private var underlineY: CGFloat {
        // Icon (17pt) + half of the 8pt VStack spacing + small
        // optical adjustment so the underline reads as separating
        // the icon from the label, not as belonging to either.
        17 + 4
    }

    // MARK: - Drag gesture

    private func dragGesture(itemWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                finishDrag(value.translation.width, itemWidth: itemWidth)
            }
    }

    private func finishDrag(_ translation: CGFloat, itemWidth: CGFloat) {
        let offset = rubberBandedOffset(translation, itemWidth: itemWidth)
        let targetIndex: Int
        if offset > commitThreshold {
            targetIndex = min(Tab.allCases.count - 1, selectedTab.rawValue + 1)
        } else if offset < -commitThreshold {
            targetIndex = max(0, selectedTab.rawValue - 1)
        } else {
            targetIndex = selectedTab.rawValue
        }

        let targetTab = Tab.allCases[targetIndex]
        if targetTab != selectedTab {
            Haptics.impact(.medium)
        }

        withAnimation(tabAnimation) {
            selectedTab = targetTab
            committedDragOffset = 0
        }
    }

    private func selectAdjacent(delta: Int) {
        let targetIndex = min(max(selectedTab.rawValue + delta, 0), Tab.allCases.count - 1)
        guard targetIndex != selectedTab.rawValue else { return }
        Haptics.impact(.medium)
        withAnimation(tabAnimation) {
            selectedTab = Tab.allCases[targetIndex]
            committedDragOffset = 0
        }
    }

    private func rubberBandedOffset(_ translation: CGFloat, itemWidth: CGFloat) -> CGFloat {
        let minOffset: CGFloat = selectedTab.rawValue > 0 ? -itemWidth : 0
        let maxOffset: CGFloat = selectedTab.rawValue < Tab.allCases.count - 1 ? itemWidth : 0

        if translation < minOffset {
            return minOffset + rubberBand(translation - minOffset)
        }
        if translation > maxOffset {
            return maxOffset + rubberBand(translation - maxOffset)
        }
        return translation
    }

    private func rubberBand(_ extra: CGFloat) -> CGFloat {
        guard extra != 0 else { return 0 }
        let sign: CGFloat = extra < 0 ? -1 : 1
        let distance = abs(extra)
        return sign * ((rubberBandLimit * distance) / (distance + rubberBandLimit))
    }

    private var tabAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }
}

#Preview {
    @Previewable @State var selectedTab: Tab = .today

    return VStack {
        Spacer()
        CustomTabBar(selectedTab: $selectedTab)
            .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
