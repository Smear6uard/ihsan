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

public struct IhsanStatusBarEdgeModifier: ViewModifier {
    @Environment(\.timeOfDayOverride) private var override
    /// The page's top edge in screen space — the height of the band
    /// above it. Measured, because a scroll view hands its overlays no
    /// top safe-area inset to grow into.
    @State private var band: CGFloat = 0

    /// How far below the status bar the ground fades to nothing.
    static let fade: CGFloat = 18

    public func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: {
                band = max(0, $0)
            }
            .overlay(alignment: .top) {
                TimelineView(.periodic(from: .distantPast, by: 60)) { context in
                    let ground = IhsanPageChrome
                        .tokens(at: override ?? NowProvider.active.resolve(context.date))
                        .pageGroundTopValue.color
                    LinearGradient(
                        stops: [
                            .init(color: ground, location: 0),
                            .init(color: ground, location: band / (band + Self.fade)),
                            .init(color: ground.opacity(0), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: band + Self.fade)
                    .offset(y: -band)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

public extension View {
    /// Keep what scrolls clear of the status bar. A top-level page has
    /// no navigation bar, so the system draws no scroll edge effect
    /// there and rows slid straight under the clock — "Current method"
    /// printed through "9:41". (An empty `safeAreaBar` does not earn
    /// one.) The page's own ground covers the status bar band and
    /// fades out just below it. Apply to the page's root `ScrollView`,
    /// on a page that starts at the top safe-area edge.
    func ihsanStatusBarEdge() -> some View {
        modifier(IhsanStatusBarEdgeModifier())
    }

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
