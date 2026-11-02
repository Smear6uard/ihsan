import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers
import IhsanCore
import IhsanDesignSystem

#if canImport(UIKit)
import UIKit
#endif

/// The portrait composition rendered offscreen. This is purpose-built
/// from the same pattern and key as Path; it is never a
/// screenshot of the live interface.
struct PatternShareCard: View {
    static let pointSize = CGSize(width: 390, height: 650)
    static let renderScale: CGFloat = 3

    let content: PatternExportContent
    let period: TrajectoryPeriod
    let tokens: SkyPaletteTokens
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                heading

                VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                    GestaltGrid(
                        days: content.days,
                        period: period,
                        tokens: tokens,
                        naflDays: content.naflDays,
                        dhikrDays: content.dhikrDays,
                        recordBegan: content.recordBegan
                    )
                    PathKey(tally: content.tally, period: period, tokens: tokens)
                }
                .padding(IhsanSpacing.md)
                .frame(maxWidth: .infinity)
                .celestialPanel(tokens: tokens, cornerRadius: 18)

                Spacer(minLength: 0)

                wordmark
            }
            .padding(IhsanSpacing.lg)
        }
        .frame(width: Self.pointSize.width, height: Self.pointSize.height)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            tokens.pageGroundFlat
        } else {
            // The same phase-resolved page ground used by Path, with
            // its static design-system vellum layer. Keeping this to
            // the quiet ground avoids paying for a live celestial
            // scene in an offscreen export.
            tokens.pageGround
                .overlay {
                    PlateGrainOverlay(
                        tint: tokens.ink,
                        seed: 0x1A5F_0426,
                        intensity: tokens.pageGroundFlatValue.relativeLuminance > 0.5
                            ? PlateGrainOverlay.dayIntensity
                            : 0.03
                    )
                }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            Text("Path")
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundStyle(tokens.ink)
                .inkKeyline(tokens)

            Text(period.phrase)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tokens.ink)
                .inkKeyline(tokens)

            Text(gregorianRange)
                .font(.footnote)
                .foregroundStyle(tokens.inkSecondary)
                .inkKeyline(tokens)

            Text(hijriRange)
                .font(.footnote)
                .foregroundStyle(tokens.inkSecondary)
                .inkKeyline(tokens)
        }
    }

    private var wordmark: some View {
        HStack(spacing: IhsanSpacing.sm) {
            EightPointedStar()
                .stroke(tokens.metal.opacity(0.8), lineWidth: 0.9)
                .frame(width: 14, height: 14)
            Text("IHSAN")
                .font(IhsanFont.inscriptionLarge)
                .tracking(2.2)
                .foregroundStyle(tokens.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    private var gregorianRange: String {
        guard let end = content.days.last?.date else { return period.phrase }
        return period.formattedRange(cycleDate: end)
    }

    private var hijriRange: String {
        guard let start = content.days.first?.date,
              let end = content.days.last?.date else { return "" }
        return "\(HijriDateFormatter.string(from: start)) – \(HijriDateFormatter.string(from: end))"
    }

    var accessibilityDescription: String {
        "Ihsan prayer pattern for the \(period.phrase.lowercased()), "
            + "with five prayer rows and a key with counts."
    }
}

/// PNG-only share payload. No subject or message accompanies it; the
/// recipient gets exactly the image the preview showed.
struct PatternShareItem: Transferable, Sendable {
    let pngData: Data
    let fileName: String

    nonisolated static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
        .suggestedFileName { item in item.fileName }
    }
}

#if canImport(UIKit)
struct PatternSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let item: PatternShareItem
    let accessibilityDescription: String
}

@MainActor
enum PatternShareRenderer {
    static func render(
        content: PatternExportContent,
        period: TrajectoryPeriod,
        tokens: SkyPaletteTokens,
        reduceTransparency: Bool
    ) -> PatternSharePayload? {
        let card = PatternShareCard(
            content: content,
            period: period,
            tokens: tokens,
            reduceTransparency: reduceTransparency
        )
        let renderedCard = card.frame(
            width: PatternShareCard.pointSize.width,
            height: PatternShareCard.pointSize.height
        )

        let renderer = ImageRenderer(content: renderedCard)
        renderer.proposedSize = ProposedViewSize(
            width: PatternShareCard.pointSize.width,
            height: PatternShareCard.pointSize.height
        )
        renderer.scale = PatternShareCard.renderScale
        renderer.isOpaque = true

        guard let image = renderer.uiImage,
              let pngData = image.pngData() else { return nil }

        return PatternSharePayload(
            image: image,
            item: PatternShareItem(
                pngData: pngData,
                fileName: "Ihsan-pattern-\(period.label.uppercased()).png"
            ),
            accessibilityDescription: card.accessibilityDescription
        )
    }
}
#endif
