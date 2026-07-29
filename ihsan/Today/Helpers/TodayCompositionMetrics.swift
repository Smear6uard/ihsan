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
    let size: CGSize
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat
    let cardHeight: CGFloat
    let hasDuhaCard: Bool

    /// Vertical room the header occupies below the safe area. The plate
    /// keeps its arc, markers, and labels clear of this band; the
    /// atmosphere still fills the frame behind it.
    static let headerZoneHeight: CGFloat = 92
    /// Bottom padding under the focused card (IhsanSpacing.md).
    static let cardBottomPadding: CGFloat = IhsanSpacing.md
    /// Optical gap between the plate's marker zone and the card.
    static let sceneToCardGap: CGFloat = 8
    /// Height reserved for the Duha quiet card when present.
    static let duhaCardHeight: CGFloat = 54
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
        safeAreaTop + Self.headerZoneHeight
    }

    var plateBottomInset: CGFloat {
        safeAreaBottom
            + Self.cardBottomPadding
            + cardHeight
            + Self.sceneToCardGap
            + (hasDuhaCard ? Self.duhaCardHeight : 0)
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
        return min(max(fraction, 0.10), 0.95)
    }

    /// Top edge of the focused card in screen space. When the Duha
    /// card is present it sits below the focused card, pushing the
    /// focused card up by its height plus the stack spacing.
    var cardTop: CGFloat {
        size.height - safeAreaBottom - Self.cardBottomPadding - cardHeight
            - (hasDuhaCard ? Self.duhaCardHeight + Self.cardStackSpacing : 0)
    }

    /// The ground band between the chord and the card — the page's
    /// largest candidate dead zone. Must never exceed the card height.
    var chordToCardGap: CGFloat {
        cardTop - horizonY
    }
}
