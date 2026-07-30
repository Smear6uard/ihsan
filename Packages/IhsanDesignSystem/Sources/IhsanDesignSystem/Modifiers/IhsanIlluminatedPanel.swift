import IhsanCore
import SwiftUI

/// Intensity tier for content panels. Under palette v2 the tiers
/// differ only in corner radius — the material itself (panelFill,
/// fine panelStroke keyline, capped texture, no shadow) is one
/// recipe, `TokenCelestialPanelModifier`, shared with the Today
/// card and the log sheet so every panel in the app speaks one
/// language.
public enum PanelIntensity: Sendable {
    /// List rows and small chips.
    case prayerRow
    /// Default content panel — sections, helper cards.
    case regular
    /// Primary surfaces.
    case hero

    var cornerRadius: CGFloat {
        switch self {
        case .prayerRow: return 16
        case .regular: return 18
        case .hero: return 20
        }
    }
}

// MARK: - .ihsanIlluminatedPanel modifier

public extension View {
    /// The illuminated panel of the secondary pages: `panelFill`
    /// body, fine metal `panelStroke` hairline, the parchment-fiber
    /// texture at the palette's capped opacity — flat + luminous,
    /// no drop shadow. Tokens resolve from the page's clock-derived
    /// SkyPhase (`timeOfDayOverride` pins them for previews and
    /// screenshot runs), so panels repaint with the page beneath.
    func ihsanIlluminatedPanel(
        intensity: PanelIntensity = .regular,
        isActive: Bool = false
    ) -> some View {
        modifier(
            IhsanIlluminatedPanelModifier(
                intensity: intensity,
                isActive: isActive
            )
        )
    }
}

internal struct IhsanIlluminatedPanelModifier: ViewModifier {
    let intensity: PanelIntensity
    let isActive: Bool
    @Environment(\.timeOfDayOverride) private var override

    func body(content: Content) -> some View {
        if let override {
            content.modifier(
                TokenCelestialPanelModifier(
                    tokens: IhsanPageChrome.tokens(at: override),
                    cornerRadius: intensity.cornerRadius,
                    isActive: isActive
                )
            )
        } else {
            TimelineView(.periodic(from: .distantPast, by: 60)) { context in
                content.modifier(
                    TokenCelestialPanelModifier(
                        tokens: IhsanPageChrome.tokens(at: NowProvider.active.resolve(context.date)),
                        cornerRadius: intensity.cornerRadius,
                        isActive: isActive
                    )
                )
            }
        }
    }
}

// MARK: - .ihsanManuscriptPage modifier

/// Full-screen page ground for the secondary pages — the QUIET
/// derivative of the current SkyPhase ground: same family and warmth
/// as Today at this hour, lower drama. No celestial scene, no zenith
/// blue, a gentler gradient span. Defined once (`IhsanPageChrome`);
/// every page consumes it — no page may derive its own ground.
///
/// Reduce-Transparency renders the flat mid-tone of the same family.
public struct IhsanManuscriptPageModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.timeOfDayOverride) private var override

    public func body(content: Content) -> some View {
        if let override {
            content.background {
                ground(at: override).ignoresSafeArea()
            }
        } else {
            TimelineView(.periodic(from: .distantPast, by: 60)) { context in
                content.background {
                    ground(at: NowProvider.active.resolve(context.date)).ignoresSafeArea()
                }
            }
        }
    }

    @ViewBuilder
    private func ground(at date: Date) -> some View {
        let tokens = IhsanPageChrome.tokens(at: date)
        if reduceTransparency {
            tokens.pageGroundFlat
        } else {
            tokens.pageGround
        }
    }
}

public extension View {
    /// Apply the quiet page ground. Use once per screen at the root.
    func ihsanManuscriptPage() -> some View {
        modifier(IhsanManuscriptPageModifier())
    }
}

// MARK: - Preview

#Preview("Page chrome — four phases") {
    ScrollView {
        VStack(spacing: IhsanSpacing.lg) {
            ForEach(PaletteState.allCases, id: \.self) { state in
                let tokens = state.tokens
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    Text(state.displayName)
                        .font(IhsanFont.heroPrayerName)
                        .foregroundStyle(tokens.ink)
                    Text("QUIET PAGE PANEL")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(tokens.inkSecondary)
                }
                .padding(IhsanSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .celestialPanel(tokens: tokens, cornerRadius: 18)
                .padding(IhsanSpacing.md)
                .background {
                    tokens.pageGround
                }
            }
        }
        .padding(.vertical)
    }
}
