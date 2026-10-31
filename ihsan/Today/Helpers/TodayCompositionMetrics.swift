import CoreGraphics
import Foundation
import IhsanDesignSystem

/// The Today page's vertical composition, as one testable value.
///
/// Header zone, plate insets, horizon height, and the focused card's
/// position are all derived here so the page reads as one composition
/// — and so the "no dead zone taller than the focused card" rule is a
/// unit test instead of a hope.
struct TodayCompositionMetrics: Equatable {
    /// The FULL screen size — the plate scene renders edge to edge
    /// (`.ignoresSafeArea()`), so every metric here lives in screen
    /// coordinates. Callers reading a safe-area-bounded GeometryReader
    /// must add the insets back before constructing metrics.
    let size: CGSize
    let safeAreaTop: CGFloat
    /// Bottom safe area as the Today content sees it — includes the
    /// tab bar's `safeAreaInset` zone, not just the home indicator.
    let safeAreaBottom: CGFloat
    let cardHeight: CGFloat
    let hasDuhaCard: Bool
    /// The header's laid-out height below the safe area, top padding
    /// included — measured, because the header grows: a long Hijri
    /// month wraps the date line, and the weather, yesterday, and
    /// significant-day notes each add a line. Zero until measured.
    var measuredHeaderHeight: CGFloat = 0

    /// Vertical room the header occupies below the safe area. The plate
    /// keeps its arc, markers, and labels clear of this band; the
    /// atmosphere still fills the frame behind it. This is the floor;
    /// a taller header pushes the plate down (see `headerZone`).
    static let headerZoneHeight: CGFloat = 92
    /// How far the header may reach past the plate's top edge. The
    /// apex marker sits a little below that edge — closest at
    /// midsummer, when Dhuhr's sun is highest — so the header gets
    /// only a hairline of it. Two notes stacked under a wrapped date
    /// used to run straight into the Dhuhr ornament.
    static let headerOverreach: CGFloat = 8

    /// The band the plate leaves to the header: the designed zone, or
    /// the header's real height when it has grown past it.
    var headerZone: CGFloat {
        max(Self.headerZoneHeight, measuredHeaderHeight - Self.headerOverreach)
    }
    /// Bottom padding under the focused card (IhsanSpacing.md).
    static let cardBottomPadding: CGFloat = IhsanSpacing.md
    /// Optical gap between the plate's marker zone and the card.
    static let sceneToCardGap: CGFloat = 8
    /// Height reserved for the optional Duha card beneath the focused card.
    /// Remembrance keeps one stable band whether or not a set is offered.
    static let duhaCardHeight: CGFloat = 54

    /// Room the quiet cards below the focused card take together,
    /// including the spacing each adds above itself.
    var quietCardsHeight: CGFloat {
        let count = hasDuhaCard ? 1 : 0
        guard count > 0 else { return 0 }
        return CGFloat(count) * Self.duhaCardHeight
            + CGFloat(count - 1) * Self.cardStackSpacing
    }
    /// Spacing between the focused card and the Duha card in the
    /// bottom stack (IhsanSpacing.sm).
    static let cardStackSpacing: CGFloat = IhsanSpacing.sm
    /// The horizon chord's placement measured on the FULL SCREEN:
    /// sky : ground ≈ 65 : 35 (corrective E item 4). The chord's
    /// plate-level fraction is derived from this, so the proportion
    /// holds regardless of header or card height; PlateGeometry's own
    /// marker/label safety clamps still apply on compact layouts. The
    /// metrics tests pin the proportion and the dead-zone rule across
    /// device sizes.
    static let horizonScreenFraction: CGFloat = 0.65

    var plateTopInset: CGFloat {
        safeAreaTop + headerZone
    }

    var plateBottomInset: CGFloat {
        safeAreaBottom
            + Self.cardBottomPadding
            + cardHeight
            + Self.sceneToCardGap
            + quietCardsHeight
    }

    var plateHeight: CGFloat {
        max(160, size.height - plateTopInset - plateBottomInset)
    }

    /// The horizon chord's y in screen space — the preferred value
    /// before `PlateGeometry`'s safety clamps.
    var horizonY: CGFloat {
        size.height * Self.horizonScreenFraction
    }

    /// The screen-level target re-expressed as the plate fraction
    /// `PlateGeometry` consumes.
    var plateHorizonFraction: CGFloat {
        let fraction = (horizonY - plateTopInset) / max(plateHeight, 1)
        return min(max(fraction, 0.10), 0.98)
    }

    /// Top edge of the focused card in screen space. When the Duha
    /// card is present it sits below the focused card, pushing the
    /// focused card up by its height plus the stack spacing.
    var cardTop: CGFloat {
        size.height - safeAreaBottom - Self.cardBottomPadding - cardHeight
            - (quietCardsHeight > 0 ? quietCardsHeight + Self.cardStackSpacing : 0)
    }

    /// The ground band between the chord and the card — the page's
    /// largest candidate dead zone. Must never exceed the card height.
    var chordToCardGap: CGFloat {
        cardTop - horizonY
    }
}
