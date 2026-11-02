import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The prayer's own ornament in the state a timing would leave on the
/// plate — gilded for On Time, the warm outline for Delayed, lapis for
/// Qadā, the quiet passed state for Missed.
///
/// The ornament states ARE the iconography: the seals, on the Today card
/// and on Path's day card, draw the same mark the plate will draw afterwards,
/// so choosing teaches the plate's language. The colour recipes are
/// static so `TimingSealContrastTests` audits exactly what renders —
/// every state's primary boundary holds ≥3:1 in every palette. Quiet
/// must never mean invisible.
struct TimingSealGlyph: View {
    let prayer: Prayer
    let timing: PrayerStatus
    let tokens: SkyPaletteTokens
    var size: CGFloat = 30

    /// The qadā body: lapis pigment, lifted a step on the jewel
    /// grounds so the roundel never sinks into a dark tile.
    static func qadaBodyValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.groundBottomValue.relativeLuminance < 0.5
            ? tokens.lapisValue.scalingLightness(by: 1.4)
            : tokens.lapisValue
    }

    /// The qadā edge: the metal keyline that pairs gold with the
    /// pigment — the classical lapis-and-gold voice, and the boundary
    /// that carries the ornament on dark tiles.
    static func qadaEdgeValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.metalValue
    }

    /// The delayed outline: warm metal on jewel grounds; on the
    /// near-white days plain metal falls under 3:1, so it deepens
    /// toward the keyline — still bronze, never gray. (Named for the
    /// `.late` case it draws, whose stored name predates the rename.)
    static func lateOutlineValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.groundBottomValue.relativeLuminance < 0.5
            ? tokens.metalValue
            : SRGBValue.mix(tokens.metalValue, tokens.keylineValue, amount: 0.30)
    }

    /// The missed outline: quiet secondary ink, already ≥7:1 on every
    /// panel.
    static func missedOutlineValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.inkSecondaryValue
    }

    var body: some View {
        switch timing {
        case .onTime:
            GildedOrnamentGlyph(prayer: prayer, size: size, tokens: tokens)
        case .late:
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(
                    Self.lateOutlineValue(for: tokens).color.opacity(0.95),
                    lineWidth: size > 20 ? 1.3 : 1.0
                )
        case .qada:
            ZStack {
                PrayerOrnamentShape(prayer: prayer, mode: .filled)
                    .fill(
                        Self.qadaBodyValue(for: tokens).color,
                        style: FillStyle(eoFill: true)
                    )
                PrayerOrnamentShape(prayer: prayer, mode: .filled)
                    .stroke(
                        Self.qadaEdgeValue(for: tokens).color.opacity(0.95),
                        lineWidth: size > 20 ? 1.0 : 0.8
                    )
            }
        case .missed:
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(
                    Self.missedOutlineValue(for: tokens).color.opacity(0.85),
                    lineWidth: size > 20 ? 1.0 : 0.8
                )
        }
    }
}

/// The card's commit row: one seal per timing the moment allows, each a
/// single tap that records.
///
/// Two seals (an open window) lie side by side as capsules, On Time
/// gilded as the default. Four (a closed window, or changing a record)
/// stand as tiles, glyph over name, with no default — memory decides
/// what happened there. A selected seal — the record being changed —
/// carries the keyline and a wash of leaf.
struct TimingSealRow: View {
    let prayer: Prayer
    let seals: [PrayerStatus]
    let tokens: SkyPaletteTokens
    /// Gilded before anything is chosen.
    var prominent: PrayerStatus? = nil
    /// The record being changed, when there is one.
    var selected: PrayerStatus? = nil
    let onChoose: (PrayerStatus) -> Void

    /// The row's height in either arrangement — the card frames itself
    /// against this, so it is one number, not two.
    static func height(for count: Int) -> CGFloat {
        count <= 2 ? 40 : 50
    }

    var body: some View {
        HStack(spacing: IhsanSpacing.sm - 2) {
            ForEach(seals, id: \.self) { timing in
                TimingSealButton(
                    prayer: prayer,
                    timing: timing,
                    tokens: tokens,
                    isProminent: timing == prominent,
                    isSelected: timing == selected,
                    isTile: seals.count > 2,
                    isChange: selected != nil
                ) {
                    onChoose(timing)
                }
            }
        }
        .frame(height: Self.height(for: seals.count))
    }
}

private struct TimingSealButton: View {
    let prayer: Prayer
    let timing: PrayerStatus
    let tokens: SkyPaletteTokens
    let isProminent: Bool
    let isSelected: Bool
    let isTile: Bool
    let isChange: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressing = false

    var body: some View {
        Button {
            // One press, one record: a second tap inside the press beat
            // would commit again once the first had landed.
            guard !isPressing else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.15)) {
                isPressing = true
            }
            // A beat for the press to be seen before the card turns to
            // its logged state and the ornament takes the gold.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                action()
                isPressing = false
            }
        } label: {
            label
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { background }
                .overlay { edge }
                .contentShape(shape)
                .scaleEffect(isPressing && !reduceMotion ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isChange ? "Change to \(timing.displayName)" : "Log as \(timing.displayName)")
        .accessibilityValue(isSelected ? "current" : "")
        .accessibilityHint(timing.caption.capitalized)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: isTile ? 14 : 20, style: .continuous)
    }

    @ViewBuilder
    private var label: some View {
        if isTile {
            VStack(spacing: 4) {
                glyph(size: 16)
                name
            }
        } else {
            HStack(spacing: 7) {
                glyph(size: 15)
                name
            }
        }
    }

    private func glyph(size: CGFloat) -> some View {
        TimingSealGlyph(prayer: prayer, timing: timing, tokens: tokens, size: size)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var name: some View {
        Text(timing.inscription)
            .font(.system(size: isTile ? 11 : 12, weight: .semibold).smallCaps())
            .tracking(isTile ? 1.0 : 1.6)
            .foregroundStyle(isGilded ? tokens.keyline : tokens.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// Gold means committed in this app, and it demands the keyline.
    /// Before anything is chosen, On Time rests filled, so the default
    /// is visible before the finger arrives. While a record is being
    /// changed, the gold sits on the timing that IS recorded.
    private var isGilded: Bool { isProminent || isSelected }

    @ViewBuilder
    private var background: some View {
        if isGilded {
            shape.fill(tokens.leafGold)
        } else if isPressing {
            shape.fill(tokens.metal.opacity(0.18))
        }
    }

    private var edge: some View {
        shape.strokeBorder(
            isGilded ? tokens.keyline.opacity(0.55) : tokens.metal.opacity(0.55),
            lineWidth: isGilded ? 1.1 : 0.9
        )
    }
}
