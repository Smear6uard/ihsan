import SwiftUI

/// The fundamental container. Wraps content with `.ihsanGlass(...)` and
/// standard padding so screens never need to manage glass + padding
/// pairings ad-hoc.
public struct GlassCard<Content: View>: View {
    public let intensity: GlassIntensity
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let content: Content

    public init(
        intensity: GlassIntensity = .regular,
        padding: CGFloat = IhsanSpacing.md,
        cornerRadius: CGFloat = IhsanSpacing.cardRadius,
        @ViewBuilder content: () -> Content
    ) {
        self.intensity = intensity
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                ),
                intensity: intensity
            )
    }
}

#Preview("Glass cards across the day") {
    ScrollView {
        VStack(spacing: IhsanSpacing.md) {
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                GlassCard {
                    HStack {
                        Text(time.displayName)
                            .font(IhsanFont.bodyEnglishBold)
                            .foregroundStyle(IhsanColor.textPrimary)
                        Spacer()
                        Text(
                            time.representativeDate,
                            format: .dateTime.hour().minute()
                        )
                        .font(IhsanFont.tabular)
                        .foregroundStyle(IhsanColor.textSecondary)
                    }
                }
                .environment(\.timeOfDayOverride, time.representativeDate)
            }
        }
        .padding()
    }
    .ihsanBackground()
}
