import CoreFoundation

/// Type-safe spacing and radius tokens. Screen code must NEVER hard-code
/// padding, frame, or radius values — every dimension routes through this enum.
public enum IhsanSpacing {
    // MARK: - Base scale

    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48

    // MARK: - Radii

    public static let cardRadius: CGFloat = 24
    public static let smallCardRadius: CGFloat = 16
    /// Resolves to a capsule when applied to a typical row height.
    public static let pillRadius: CGFloat = 999

    // MARK: - Component-specific

    public static let prayerRowHeight: CGFloat = 72
    public static let heatmapDotSize: CGFloat = 12
    public static let heatmapDotSpacing: CGFloat = 6

    // MARK: - Hairline

    /// Atmospheric divider thickness — visually 1 logical point, sub-pixel
    /// rendering pushes it to a single device pixel on most displays.
    public static let hairline: CGFloat = 1
}
