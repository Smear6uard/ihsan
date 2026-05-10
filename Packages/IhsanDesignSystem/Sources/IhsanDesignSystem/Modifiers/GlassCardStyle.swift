import SwiftUI

/// Convenience modifier that combines standard card padding with the
/// Ihsan Liquid Glass treatment. Use this when applying the glass look
/// to ad-hoc content; for layout-managed surfaces prefer `GlassCard` so
/// the padding is consistent across screens.
public struct GlassCardStyle: ViewModifier {
    public let intensity: GlassIntensity
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let isActive: Bool

    public init(
        intensity: GlassIntensity = .regular,
        padding: CGFloat = IhsanSpacing.md,
        cornerRadius: CGFloat = IhsanSpacing.cardRadius,
        isActive: Bool = false
    ) {
        self.intensity = intensity
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                ),
                intensity: intensity,
                isActive: isActive
            )
    }
}

public extension View {
    func glassCardStyle(
        intensity: GlassIntensity = .regular,
        padding: CGFloat = IhsanSpacing.md,
        cornerRadius: CGFloat = IhsanSpacing.cardRadius,
        isActive: Bool = false
    ) -> some View {
        modifier(
            GlassCardStyle(
                intensity: intensity,
                padding: padding,
                cornerRadius: cornerRadius,
                isActive: isActive
            )
        )
    }
}
