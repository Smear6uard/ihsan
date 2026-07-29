import SwiftUI

/// Illuminated-panel material for the celestial Today screen.
///
/// A solid surface — `IhsanCelestialPalette.day.surface` parchment cream
/// during the day, `.night.surface` warm espresso at night — bordered
/// with the iridescent brass stroke from `IhsanIridescence.brassStroke`
/// and sitting on the page with a subtle drop shadow. The focused-
/// prayer card on the celestial Today screen consumes this modifier.
///
/// This is NOT Liquid Glass. Liquid Glass is reserved for the tab bar
/// and modal sheets (system chrome); content surfaces on the celestial
/// scene are solid illuminated panels so the brass border reads as gold
/// leaf inscribed on parchment, not as a glassy refraction effect.
public struct CelestialPanelModifier: ViewModifier {
    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Corner radius of the panel. Defaults to 20pt per spec for the
    /// focused-prayer card; smaller surfaces (chips, status capsules)
    /// can opt down via the `cornerRadius` parameter on `.celestialPanel`.
    let cornerRadius: CGFloat

    /// Active state. When `true` the brass border opacity strengthens
    /// from 0.70 to 0.95 and an inner gold halo lifts the panel — used
    /// during the iridescent-border slow rotation when the focused-
    /// prayer card is showing the currently-open prayer window.
    let isActive: Bool

    public func body(content: Content) -> some View {
        let date = override ?? .now
        let palette = IhsanCelestialPalette.current(at: date)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            // Reduce-Transparency drops the iridescent gradient and the
            // shadow, but keeps the surface and a solid brass border so
            // the panel boundary remains unambiguous.
            content
                .background { shape.fill(palette.surface) }
                .overlay {
                    shape.strokeBorder(
                        palette.accent.opacity(isActive ? 0.95 : 0.70),
                        lineWidth: 1.0
                    )
                }
                .clipShape(shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(palette.surface)
                        if isActive {
                            shape.fill(
                                RadialGradient(
                                    colors: [
                                        palette.accentBright.opacity(0.20),
                                        palette.accentBright.opacity(0.06),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 220
                                )
                            )
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .overlay {
                    shape.strokeBorder(
                        IhsanIridescence.brassStroke(opacity: isActive ? 0.95 : 0.70),
                        lineWidth: 1.0
                    )
                }
                .clipShape(shape)
                .shadow(
                    color: .black.opacity(0.10),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        }
    }
}

public extension View {
    /// Apply the celestial illuminated-panel material — solid surface,
    /// iridescent brass border, subtle drop shadow.
    ///
    /// Legacy variant: resolves its own palette from the clock. New
    /// surfaces should use `celestialPanel(tokens:)`, which takes the
    /// resolved v2 tokens and follows the flat + luminous rule.
    ///
    /// - Parameters:
    ///   - cornerRadius: Defaults to 20pt (focused-prayer card spec).
    ///   - isActive: Lifts the border to full opacity and adds an
    ///     inner gold halo. Use when the panel represents an active
    ///     state (the focused-prayer card during an open prayer window).
    func celestialPanel(
        cornerRadius: CGFloat = 20,
        isActive: Bool = false
    ) -> some View {
        modifier(
            CelestialPanelModifier(
                cornerRadius: cornerRadius,
                isActive: isActive
            )
        )
    }

    /// The v2 illuminated panel: `panelFill` body, a fine 1 pt
    /// `panelStroke` hairline, the parchment-fiber texture at the
    /// palette's capped opacity — and, per the flat + luminous rule,
    /// no drop shadow. An active panel is lifted by a faint interior
    /// glow, never by depth effects.
    func celestialPanel(
        tokens: SkyPaletteTokens,
        cornerRadius: CGFloat = 20,
        isActive: Bool = false
    ) -> some View {
        modifier(
            TokenCelestialPanelModifier(
                tokens: tokens,
                cornerRadius: cornerRadius,
                isActive: isActive
            )
        )
    }
}

/// The v2 panel material. Depth comes from glow and layered opacity
/// only — no shadow, no specular, no volume gradient.
public struct TokenCelestialPanelModifier: ViewModifier {
    let tokens: SkyPaletteTokens
    let cornerRadius: CGFloat
    let isActive: Bool

    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.celestialForceReducedTransparency) private var forceReducedTransparency

    private var reduceTransparency: Bool {
        systemReduceTransparency || forceReducedTransparency
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let onDarkGround = tokens.groundBottomValue.relativeLuminance < 0.5

        content
            .background {
                ZStack {
                    shape.fill(tokens.panelFill)
                    if isActive && !reduceTransparency {
                        // The active lift: interior glow, clipped to the
                        // panel, additive only against jewel grounds.
                        shape.fill(
                            RadialGradient(
                                colors: [
                                    tokens.glow.opacity(onDarkGround ? 0.16 : 0.10),
                                    tokens.glow.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                        .blendMode(onDarkGround ? .plusLighter : .normal)
                        .allowsHitTesting(false)
                    }
                    if !reduceTransparency {
                        // Parchment fiber: the seeded grain speckle in the
                        // palette's texture tint, hard-capped below the
                        // tokens' 8% ceiling.
                        PlateGrainOverlay(
                            tint: tokens.panelTextureValue.color,
                            seed: 0x9A3F_11C2,
                            intensity: tokens.panelTextureOpacity
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    tokens.panelStroke.opacity(isActive ? 1.0 : 0.75),
                    lineWidth: 1.0
                )
            }
            .clipShape(shape)
    }
}

// MARK: - Preview

#Preview("Celestial panel — night and day") {
    VStack(spacing: 32) {
        ZStack {
            LinearGradient(
                colors: [IhsanCelestialPalette.night.skyDeep, IhsanCelestialPalette.night.sky],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("Fajr الفجر")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(IhsanCelestialPalette.night.text)
                Text("PRAYING WINDOW OPENS IN")
                    .font(.system(size: 11, weight: .semibold).smallCaps())
                    .tracking(1.1)
                    .foregroundStyle(IhsanCelestialPalette.night.accent)
                Text("4:54:21")
                    .font(.system(.title, design: .monospaced).monospacedDigit())
                    .fontWeight(.light)
                    .foregroundStyle(IhsanCelestialPalette.night.text)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .celestialPanel()
            .padding(.horizontal, 16)
            .environment(\.timeOfDayOverride, dateAt(hour: 23, minute: 0))
        }

        ZStack {
            LinearGradient(
                colors: [IhsanCelestialPalette.day.sky, IhsanCelestialPalette.day.skyDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("Asr العصر")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(IhsanCelestialPalette.day.text)
                Text("PRAYING NOW · WINDOW ENDS IN")
                    .font(.system(size: 11, weight: .semibold).smallCaps())
                    .tracking(1.1)
                    .foregroundStyle(IhsanCelestialPalette.day.accent)
                Text("1:23:45")
                    .font(.system(.title, design: .monospaced).monospacedDigit())
                    .fontWeight(.light)
                    .foregroundStyle(IhsanCelestialPalette.day.text)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .celestialPanel(isActive: true)
            .padding(.horizontal, 16)
            .environment(\.timeOfDayOverride, dateAt(hour: 15, minute: 30))
        }
    }
}

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? .now
}
