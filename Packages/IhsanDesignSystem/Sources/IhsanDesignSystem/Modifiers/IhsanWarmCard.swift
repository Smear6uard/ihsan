import SwiftUI

/// Intensity tier for the warm card material.
///
/// The new visual direction replaces the previous "tinted dark glass"
/// treatment with cream/amber Liquid Glass that *is* the surface colour,
/// not a wash applied over a dark base. The intensity scales how much of
/// the warm card colour mixes into the system Glass tint.
public enum WarmCardIntensity: Sendable {
    /// Settings rows, secondary surfaces, ambient containers.
    case subtle
    /// Prayer rows, content cards — the default.
    case regular
    /// The countdown card and other primary surfaces. Most pronounced.
    case hero

    /// How strongly the warm card colour tints the Liquid Glass material.
    /// At hero strength the card reads as warm cream/amber paper; at
    /// subtle strength it reads as glass that's caught a warm cast.
    var tintOpacity: Double {
        switch self {
        case .subtle: return 0.55
        case .regular: return 0.78
        case .hero: return 0.88
        }
    }

    /// Top-down sheen contribution. Suggests the surface catching ambient
    /// light from above without making the material itself look painted.
    var sheenOpacity: Double {
        switch self {
        case .subtle: return 0.10
        case .regular: return 0.18
        case .hero: return 0.26
        }
    }

    /// Bottom edge shadow opacity. Anchors the card to the surface beneath
    /// it so it never reads as a flat outlined rectangle.
    var bottomShadeOpacity: Double {
        switch self {
        case .subtle: return 0.06
        case .regular: return 0.10
        case .hero: return 0.14
        }
    }

    /// Specular edge highlight opacity. The thin gradient stroke that
    /// reads as "lit material" rather than "tinted rectangle".
    var edgeHighlightOpacity: Double {
        switch self {
        case .subtle: return 0.22
        case .regular: return 0.35
        case .hero: return 0.50
        }
    }
}

// MARK: - .ihsanWarmCard modifier

public extension View {
    /// Apply the warm card material — cream/amber Liquid Glass that
    /// adapts to the time of day. Use this anywhere a content surface
    /// floats above the `IhsanSkyGradient`.
    ///
    /// - Parameters:
    ///   - shape: Clipping shape.
    ///   - intensity: Tier that scales the warm tint contribution.
    ///   - isActive: Adds a glowing brass ring + inner radial halo for
    ///     the active prayer surface.
    func ihsanWarmCard<S: InsettableShape>(
        in shape: S,
        intensity: WarmCardIntensity = .regular,
        isActive: Bool = false
    ) -> some View {
        modifier(
            IhsanWarmCardModifier(
                shape: shape,
                intensity: intensity,
                isActive: isActive
            )
        )
    }

    /// Default rounded-rectangle variant. Uses the standard card radius.
    func ihsanWarmCard(
        intensity: WarmCardIntensity = .regular,
        isActive: Bool = false
    ) -> some View {
        ihsanWarmCard(
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.cardRadius,
                style: .continuous
            ),
            intensity: intensity,
            isActive: isActive
        )
    }

    /// Hero variant — most pronounced warm Liquid Glass. Use for the
    /// countdown card and other primary surfaces.
    func ihsanWarmCardHero(isActive: Bool = false) -> some View {
        ihsanWarmCard(intensity: .hero, isActive: isActive)
    }
}

internal struct IhsanWarmCardModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let intensity: WarmCardIntensity
    let isActive: Bool
    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let date = override ?? .now
        let surface = IhsanColor.cardSurfaceColor(at: date)
        let tint = surface.opacity(intensity.tintOpacity)
        let accent = IhsanColor.accentWarm(at: date)

        content
            .modifier(
                WarmCardBaseLayer(
                    shape: shape,
                    surface: surface,
                    tint: tint,
                    accent: accent,
                    intensity: intensity,
                    isActive: isActive,
                    reduceTransparency: reduceTransparency
                )
            )
    }
}

/// Splits the layer composition out so the type-checker doesn't have to
/// reason about a deeply nested overlay chain inside the ViewModifier's
/// `body`.
private struct WarmCardBaseLayer<S: InsettableShape>: ViewModifier {
    let shape: S
    let surface: Color
    let tint: Color
    let accent: Color
    let intensity: WarmCardIntensity
    let isActive: Bool
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            // High-contrast path — drop the Liquid Glass entirely and
            // give a flat, opaque warm surface so the card stays
            // unambiguously legible.
            content
                .background {
                    shape
                        .fill(surface)
                        .overlay {
                            shape.strokeBorder(
                                accent.opacity(isActive ? 0.65 : 0.30),
                                lineWidth: isActive ? 1.2 : 0.6
                            )
                        }
                }
        } else {
            content
                // 1. Base fill of the warm surface colour. Sits underneath
                //    the Liquid Glass so the glass refraction picks up
                //    the warm cream / amber rather than the sky behind.
                //    Without this, .glassEffect alone would let the sky
                //    bleed through and the card would lose its identity.
                .background {
                    shape.fill(surface.opacity(intensity.tintOpacity))
                }
                // 2. iOS 26 native Liquid Glass with a stronger warm
                //    tint contribution. The `.tint(...)` lets the system
                //    material refract the light beneath while keeping
                //    the warm cast as part of the material itself.
                .glassEffect(
                    .regular.tint(tint),
                    in: shape
                )
                // 3. Inner radial halo for the active prayer surface.
                //    Drawn before the sheen so the sheen's bottom edge
                //    still reads on top of the halo.
                .overlay {
                    if isActive {
                        shape
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(0.32),
                                        accent.opacity(0.10),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 240
                                )
                            )
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                }
                // 4. Top-down sheen — soft white at the very top,
                //    a hint of accent warmth around 35%, fully transparent
                //    in the middle, a subtle shadow at the bottom edge.
                //    This is the single detail that reads as "lit
                //    material" rather than "tinted rectangle" on device.
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(intensity.sheenOpacity * 1.1), location: 0.0),
                                    .init(color: accent.opacity(intensity.sheenOpacity * 0.5), location: 0.35),
                                    .init(color: .clear, location: 0.65),
                                    .init(color: .black.opacity(intensity.bottomShadeOpacity), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }
                // 5. Specular edge — thin gradient stroke catching warm
                //    light at the top-left and dissolving at bottom-right.
                .overlay {
                    shape
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(intensity.edgeHighlightOpacity), location: 0.0),
                                    .init(color: accent.opacity(intensity.edgeHighlightOpacity * 0.65), location: 0.4),
                                    .init(color: .white.opacity(0.05), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                        .allowsHitTesting(false)
                }
                // 6. Active brass ring — drawn last so it sits above
                //    the sheen and edge highlight.
                .overlay {
                    if isActive {
                        shape
                            .strokeBorder(accent.opacity(0.65), lineWidth: 1.2)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

// MARK: - .ihsanSkyBackground modifier

/// Full-screen time-adaptive sky modifier. Renders the
/// `IhsanSkyGradient` beneath all content. Reduce-Transparency users get
/// a flat `IhsanColor.ground` so the screen stays unambiguously legible.
public struct IhsanSkyBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if reduceTransparency {
                        IhsanColor.ground
                    } else {
                        IhsanSkyGradient()
                    }
                }
                .ignoresSafeArea()
            }
    }
}

public extension View {
    /// Apply the time-adaptive sky background. Use once per screen at
    /// the root, in place of `.ihsanBackground()` for screens that
    /// participate in the new visual direction.
    func ihsanSkyBackground() -> some View {
        modifier(IhsanSkyBackgroundModifier())
    }
}
