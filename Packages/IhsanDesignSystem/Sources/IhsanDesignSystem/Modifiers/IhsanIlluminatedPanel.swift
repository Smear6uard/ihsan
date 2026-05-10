import SwiftUI

/// Intensity tier for the illuminated-panel material.
///
/// Cards in the manuscript aesthetic are solid panels — `panelDay` cream
/// during the day, `panelNight` amber at night — bordered in brass and
/// sitting on the page with a subtle drop shadow. Liquid Glass is reserved
/// for the tab bar; content surfaces are always solid so they read as ink
/// on parchment.
public enum PanelIntensity: Sendable {
    /// Prayer-list rows. Thinner border (0.5pt at 30% brass), tighter
    /// shadow, smaller corner radius.
    case prayerRow
    /// Default content panel — sections, helper cards.
    case regular
    /// Hero countdown and other primary surfaces. Same border as
    /// `regular` but supports corner ornaments via the call site.
    case hero

    var cornerRadius: CGFloat {
        switch self {
        case .prayerRow: return 16
        case .regular: return 18
        case .hero: return 20
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .prayerRow: return 0.5
        case .regular: return 1.0
        case .hero: return 1.0
        }
    }

    var borderOpacity: Double {
        switch self {
        case .prayerRow: return 0.30
        case .regular: return 0.40
        case .hero: return 0.45
        }
    }

    var activeBorderWidth: CGFloat {
        switch self {
        case .prayerRow: return 1.0
        case .regular: return 1.2
        case .hero: return 1.4
        }
    }

    var activeBorderOpacity: Double {
        switch self {
        case .prayerRow: return 0.80
        case .regular: return 0.85
        case .hero: return 0.90
        }
    }

    /// Drop-shadow opacity. Subtle so the panel sits on the page rather
    /// than floating above it.
    var shadowOpacity: Double {
        switch self {
        case .prayerRow: return 0.06
        case .regular: return 0.08
        case .hero: return 0.10
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .prayerRow: return 4
        case .regular: return 6
        case .hero: return 8
        }
    }

    var shadowOffset: CGFloat {
        switch self {
        case .prayerRow: return 1
        case .regular: return 1.5
        case .hero: return 2
        }
    }
}

// MARK: - .ihsanIlluminatedPanel modifier

public extension View {
    /// Apply the illuminated-panel material — a solid `panelDay` /
    /// `panelNight` surface with a brass illumination border and a subtle
    /// drop shadow. The conceptual replacement for the old `.ihsanGlass`
    /// dark glass treatment, used by the Today screen's content cards.
    ///
    /// - Parameters:
    ///   - intensity: Tier that scales border weight, corner radius, and
    ///     shadow depth. Use `.prayerRow` for list rows, `.regular` for
    ///     sections, `.hero` for the countdown card.
    ///   - isActive: Strengthens the brass border to 80–90% opacity and
    ///     adds an inner gold halo. Used for the current/next prayer row.
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let date = override ?? .now
        let surface = panelSurface(at: date)
        let shape = RoundedRectangle(
            cornerRadius: intensity.cornerRadius,
            style: .continuous
        )

        let strokeOpacity = isActive
            ? intensity.activeBorderOpacity
            : intensity.borderOpacity
        let strokeWidth = isActive
            ? intensity.activeBorderWidth
            : intensity.borderWidth

        // The Reduce-Transparency path drops the halo and shadow but keeps
        // the brass border at full strength so the panel boundary still
        // reads unambiguously. The iridescent stroke is preserved — it's
        // a colour treatment, not a motion effect, so it stays under
        // Reduce Motion / Reduce Transparency.
        if reduceTransparency {
            content
                .background {
                    shape.fill(surface)
                }
                .overlay {
                    shape.strokeBorder(
                        IhsanIridescence.brassStroke(opacity: isActive ? 0.90 : 0.65),
                        lineWidth: isActive ? intensity.activeBorderWidth : 1.0
                    )
                }
                .clipShape(shape)
        } else {
            content
                .background {
                    ZStack {
                        // 1. The panel body — solid cream or amber.
                        shape.fill(surface)

                        // 2. Optional inner gold halo for the active panel.
                        //    Pulled tight around the centre so it reads as
                        //    "this is the next prayer" rather than as a
                        //    full surface tint takeover.
                        if isActive {
                            shape.fill(
                                RadialGradient(
                                    colors: [
                                        IhsanColor.gold.opacity(0.22),
                                        IhsanColor.gold.opacity(0.08),
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
                }
                .overlay {
                    // 3. The brass illumination border — an angular
                    //    gradient cycling honey → mid → pale → dark
                    //    around the perimeter so the stroke reads as
                    //    iridescent gold leaf, not flat brass paint.
                    //    This is the single most identity-defining
                    //    detail of the manuscript aesthetic.
                    shape.strokeBorder(
                        IhsanIridescence.brassStroke(opacity: strokeOpacity),
                        lineWidth: strokeWidth
                    )
                }
                .clipShape(shape)
                .shadow(
                    color: .black.opacity(intensity.shadowOpacity),
                    radius: intensity.shadowRadius,
                    x: 0,
                    y: intensity.shadowOffset
                )
        }
    }

    /// Returns the appropriate panel surface for the given moment. The
    /// luminance check matches `cardForegroundPrimary`'s — at every clock
    /// time the panel's surface and its text foreground are computed from
    /// the same threshold so they stay in lockstep across the sunrise /
    /// maghrib flips.
    private func panelSurface(at date: Date) -> Color {
        IhsanColor.cardSurfaceLuminance(at: date) > IhsanColor.cardForegroundLuminanceThreshold
            ? IhsanColor.panelDay
            : IhsanColor.panelNight
    }
}

// MARK: - .ihsanManuscriptPage modifier

/// Full-screen manuscript-page background. The Today-screen replacement
/// for `.ihsanBackground` — renders the time-adaptive `IhsanSkyGradient`
/// (Persian indigo at night, parchment cream by day, vermillion at
/// maghrib) so the entire screen reads as "the page". Content sits on
/// top as illuminated panels.
///
/// Reduce-Transparency users get the flat `nightPage` colour so the
/// screen stays unambiguously legible.
public struct IhsanManuscriptPageModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        content
            .background {
                Group {
                    if reduceTransparency {
                        IhsanColor.nightPage
                    } else {
                        IhsanSkyGradient()
                    }
                }
                .ignoresSafeArea()
            }
    }
}

public extension View {
    /// Apply the manuscript page background — the time-adaptive page
    /// gradient that drifts from Persian indigo through parchment cream
    /// through maghrib vermillion across the day. Use once per screen at
    /// the root.
    func ihsanManuscriptPage() -> some View {
        modifier(IhsanManuscriptPageModifier())
    }
}

// MARK: - Preview

#Preview("Illuminated panel — across the day") {
    ScrollView {
        VStack(spacing: IhsanSpacing.lg) {
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    Text(time.displayName)
                        .font(IhsanFont.heroPrayerName)
                        .foregroundStyle(IhsanColor.cardForegroundPrimary(at: time.representativeDate))

                    OrnamentalDivider()

                    Text("UNTIL ASR")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(IhsanColor.brass.opacity(0.75))
                }
                .padding(IhsanSpacing.lg)
                .frame(maxWidth: .infinity)
                .ihsanIlluminatedPanel(intensity: .hero)
                .environment(\.timeOfDayOverride, time.representativeDate)
                .padding(.horizontal, IhsanSpacing.md)
            }
        }
        .padding(.vertical)
    }
    .ihsanManuscriptPage()
}
