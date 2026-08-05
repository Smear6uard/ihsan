import Foundation
import IhsanDesignSystem
import Testing
@testable import ihsan

/// Corrective G, phase 3 — the sheet's contrast audit, computed from
/// the exact recipes the tiles render (`PrayerLogSheet`'s static
/// treatment functions), across all six canonical SkyPhases.
///
/// The standard: every timing tile's PRIMARY boundary — the strongest
/// of its body and its edge — holds WCAG's 3:1 non-text minimum
/// against the tile it sits on, in every palette. Quiet must never
/// mean invisible: the qadā roundel was a dark shape on a dark tile;
/// its lifted-lapis body plus metal edge now reads in every phase.
@Suite("PrayerLogSheet contrast")
struct PrayerLogSheetContrastTests {

    private let states = PaletteState.allCases

    /// The strongest boundary an ornament presents against its tile.
    private func silhouette(_ candidates: [SRGBValue], against panel: SRGBValue) -> Double {
        candidates.map { $0.contrastRatio(against: panel) }.max() ?? 0
    }

    @Test
    func everyTimingTileOrnamentReadsOnItsTileInEveryPhase() {
        for state in states {
            let tokens = state.tokens
            let panel = tokens.panelFillValue

            // On Time — gilded: leaf body bounded by the keyline. On
            // jewel grounds the leaf carries; on the near-white days
            // the keyline does.
            let onTime = silhouette(
                [tokens.leafGoldValue, tokens.keylineValue], against: panel
            )
            #expect(onTime >= 3.0, "\(state) onTime silhouette \(onTime)")

            // Late — the warm outline, deepened on light grounds.
            let late = PrayerLogSheet.lateOutlineValue(for: tokens)
                .contrastRatio(against: panel)
            #expect(late >= 3.0, "\(state) late outline \(late)")

            // Qadā — lifted lapis body + metal edge.
            let qada = silhouette(
                [
                    PrayerLogSheet.qadaBodyValue(for: tokens),
                    PrayerLogSheet.qadaEdgeValue(for: tokens)
                ],
                against: panel
            )
            #expect(qada >= 3.0, "\(state) qadā silhouette \(qada)")

            // Missed — quiet secondary ink.
            let missed = PrayerLogSheet.missedOutlineValue(for: tokens)
                .contrastRatio(against: panel)
            #expect(missed >= 3.0, "\(state) missed outline \(missed)")
        }
    }

    /// The qadā body itself must also be present on the tile — not
    /// carried solely by its edge. 1.9:1 is the perceptibility floor
    /// for a filled 30 pt shape; the edge supplies the 3:1 boundary.
    @Test
    func qadaBodyIsNeverInvisibleOnItsTile() {
        for state in states {
            let tokens = state.tokens
            let body = PrayerLogSheet.qadaBodyValue(for: tokens)
                .contrastRatio(against: tokens.panelFillValue)
            #expect(body >= 1.9, "\(state) qadā body \(body)")
        }
    }

    /// The truth pass quiets unavailable tiles to
    /// `unavailableTileOpacity` — quiet must still never mean
    /// invisible. Compositing each ornament's strongest boundary at
    /// that opacity over its tile must keep a ≥1.9:1 presence in
    /// every phase, and the qadā roundel specifically must survive
    /// the dimming on day and night grounds.
    @Test
    func unavailableTilesStayPerceptibleInEveryPhase() {
        let alpha = PrayerLogSheet.unavailableTileOpacity
        for state in states {
            let tokens = state.tokens
            let panel = tokens.panelFillValue

            let boundaries: [(String, [SRGBValue])] = [
                ("onTime", [tokens.leafGoldValue, tokens.keylineValue]),
                ("late", [PrayerLogSheet.lateOutlineValue(for: tokens)]),
                ("qada", [
                    PrayerLogSheet.qadaBodyValue(for: tokens),
                    PrayerLogSheet.qadaEdgeValue(for: tokens)
                ]),
                ("missed", [PrayerLogSheet.missedOutlineValue(for: tokens)]),
            ]

            for (name, candidates) in boundaries {
                let dimmed = candidates
                    .map { SRGBValue.mix(panel, $0, amount: alpha) }
                let strongest = silhouette(dimmed, against: panel)
                #expect(strongest >= 1.9, "\(state) dimmed \(name) \(strongest)")
            }
        }
    }

    /// Title and inscriptions on the sheet's glass: ink ≥7:1 and
    /// secondary ink ≥4.5:1 against the sheet backing composited over
    /// the darkest thing the glass can sample (the ground plane), in
    /// all six phases.
    @Test
    func sheetTitleAndInscriptionsHoldAAOnTheBackedGlass() {
        for state in states {
            let tokens = state.tokens
            let composite = SRGBValue.mix(
                tokens.sheetBackingValue,
                tokens.groundPlaneValue,
                amount: 1.0 - tokens.sheetBackingOpacity
            )
            let ink = tokens.inkValue.contrastRatio(against: composite)
            let secondary = tokens.inkSecondaryValue.contrastRatio(against: composite)
            #expect(ink >= 7.0, "\(state) ink on sheet \(ink)")
            #expect(secondary >= 4.5, "\(state) inkSecondary on sheet \(secondary)")
        }
    }

    /// The sheet backing is never clear — the glass carries the
    /// ground family in every phase instead of falling back to a
    /// charcoal slab at night.
    @Test
    func sheetBackingCarriesTheGroundFamilyInEveryPhase() {
        for state in states {
            #expect(state.tokens.sheetBackingOpacity > 0.5)
        }
    }
}
