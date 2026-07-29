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
    /// The horizon chord's height as a fraction of the plate. Chosen so
    /// the ground band between the chord and the focused card stays
    /// shorter than the card itself — the plate, ground, and card read
    /// as one page with no void between them. The metrics tests pin
    /// this across device sizes.
    static let horizonFraction: CGFloat = 0.78

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

    /// The horizon chord's y in screen space — the same preferred-value
    /// computation `PlateGeometry` applies before its safety clamps.
    var horizonY: CGFloat {
        plateTopInset + plateHeight * Self.horizonFraction
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
