import SwiftUI
import IhsanDesignSystem

enum Tab: Int, CaseIterable, Hashable, Identifiable {
    case today
    case trajectory
    case reflection
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .trajectory: "Trajectory"
        case .reflection: "Reflection"
        case .settings: "Settings"
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

    var accessibilityLabel: String {
        "\(title) tab"
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var committedDragOffset: CGFloat = 0

    private let commitThreshold: CGFloat = 50
    private let rubberBandLimit: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(Tab.allCases.count)
            let effectiveOffset = rubberBandedOffset(
                committedDragOffset + dragTranslation,
                itemWidth: itemWidth
            )

            ZStack(alignment: .leading) {
                selectedCapsule(itemWidth: itemWidth)
                    .offset(x: selectedCapsuleX(itemWidth: itemWidth) + effectiveOffset)

                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        tabButton(tab)
                            .frame(width: itemWidth)
                    }
                }
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
        .ihsanGlass(
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            ),
            intensity: .regular
        )
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            committedDragOffset = 0
            guard selectedTab != tab else { return }
            Haptics.impact(.medium)
            withAnimation(tabAnimation) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: IhsanSpacing.xxs) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(IhsanFont.tabBar)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selectedTab == tab ? IhsanColor.textPrimary : IhsanColor.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
    }

    private func selectedCapsule(itemWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: IhsanSpacing.smallCardRadius, style: .continuous)
            .fill(.clear)
            .frame(width: max(0, itemWidth - IhsanSpacing.xs * 2), height: IhsanSpacing.tabBarHeight - IhsanSpacing.sm)
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                ),
                intensity: .subtle
            )
            .allowsHitTesting(false)
    }

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

    private func selectedCapsuleX(itemWidth: CGFloat) -> CGFloat {
        CGFloat(selectedTab.rawValue) * itemWidth + IhsanSpacing.xs
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
    .ihsanBackground()
}
