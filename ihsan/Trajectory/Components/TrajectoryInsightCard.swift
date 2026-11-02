import IhsanDesignSystem
import IhsanFiqhConfig
import SwiftUI

/// One reading of the period, one thing to do about it, and the cited
/// context behind it.
///
/// Three registers, kept visibly apart. The finding counts what the
/// user did and never rules on it. The action changes something. The
/// cited context explains the category the count belongs to and never
/// judges the person's record. The supporting line is the only part
/// the on-device model may touch, and it is barred from religious
/// language entirely.
struct TrajectoryInsightCard: View {
    let finding: PathFinding?
    let text: String?
    let isLoading: Bool
    let grounding: TrajectoryFindingFraming
    let ledger: TrajectoryInsightFraming
    /// A receipt for an action that changed a setting in place, shown
    /// briefly because the button beneath it is about to say something
    /// different and would otherwise be the only evidence.
    let confirmation: String?
    let tokens: SkyPaletteTokens
    let onAct: (PathFindingAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loadingPulse = false
    @State private var isFiqhExpanded = false

    private let cardShape = RoundedRectangle(
        cornerRadius: IhsanSpacing.cardRadius,
        style: .continuous
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // A restrained metal light field gives the clear material
            // depth without turning the observation into another card
            // nested inside a card.
            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            tokens.metal.opacity(0.12),
                            tokens.lapis.opacity(0.035),
                            .clear,
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )

            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                header

                if let finding {
                    Text(finding.headline)
                        .font(IhsanFont.bodyEnglishBold)
                        .lineSpacing(3)
                        .foregroundStyle(tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let text {
                    Text(text)
                        .font(IhsanFont.bodyEnglish)
                        .lineSpacing(3)
                        .foregroundStyle(tokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isLoading {
                    Text("Looking closer, on this iPhone…")
                        .font(.footnote)
                        .foregroundStyle(tokens.inkSecondary)
                }

                if let confirmation {
                    Text(confirmation)
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                if let finding, let action = finding.action, let title = finding.actionTitle {
                    actionButton(title: title, action: action)
                }

                fiqhDisclosure

                if isFiqhExpanded {
                    fiqhBody
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(IhsanSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(cardShape)
        .ihsanGlass(
            in: cardShape,
            intensity: .regular,
            isClear: true
        )
        .task(id: isLoading) {
            withAnimation(nil) { loadingPulse = false }
            guard isLoading, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                loadingPulse = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The capsule's carrying edge, as a value so
    /// `PathInsightContrastTests` audits exactly what renders.
    ///
    /// Neither metal nor keyline survives the whole day. Metal reads on
    /// the dark phases and dissolves to 2.8:1 against the panel by
    /// afternoon; keyline is the precise inverse, invisible at night
    /// and near-black at midday. The palette flips polarity, so the
    /// edge has to flip with it — the same choice the dot language
    /// already makes for its marks.
    static func actionEdgeValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        prefersMetalEdge(tokens) ? tokens.metalValue : tokens.keylineValue
    }

    static func prefersMetalEdge(_ tokens: SkyPaletteTokens) -> Bool {
        let panel = tokens.panelFillValue
        return tokens.metalValue.contrastRatio(against: panel)
            >= tokens.keylineValue.contrastRatio(against: panel)
    }

    private var actionEdge: Color {
        Self.prefersMetalEdge(tokens) ? tokens.metal : tokens.keyline
    }

    /// The card's one action. Ink on `panelFill` is the app's
    /// contrast-certified pair, held to by `PathInsightContrastTests`.
    private func actionButton(title: String, action: PathFindingAction) -> some View {
        Button {
            Haptics.impact(.light)
            onAct(action)
        } label: {
            HStack(spacing: IhsanSpacing.sm) {
                Text(title)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: IhsanSpacing.xs)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tokens.ink)
            }
            .padding(.horizontal, IhsanSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background {
                Capsule().fill(tokens.panelFill)
            }
            .overlay {
                Capsule().stroke(actionEdge, lineWidth: 1.2)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var fiqhBody: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                Text(grounding.title)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.ink)

                Text(grounding.body)
                    .font(IhsanFont.bodyEnglish)
                    .lineSpacing(3)
                    .foregroundStyle(tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(grounding.citation)
                    .font(IhsanFont.inscription)
                    .tracking(0.7)
                    .foregroundStyle(tokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The glossary stays attached to the grounding. It is what
            // stops a blunt count from being read as a ruling, so it
            // travels with every reading rather than only some.
            Rectangle()
                .fill(tokens.metal.opacity(0.22))
                .frame(height: 0.75)

            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                Text(ledger.title)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.ink)

                Text(ledger.body)
                    .font(IhsanFont.bodyEnglish)
                    .lineSpacing(3)
                    .foregroundStyle(tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ledger.citation)
                    .font(IhsanFont.inscription)
                    .tracking(0.7)
                    .foregroundStyle(tokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fiqhDisclosure: some View {
        Button {
            Haptics.impact(.light)
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                isFiqhExpanded.toggle()
            }
        } label: {
            HStack(spacing: IhsanSpacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))

                Text("Context and sources")
                    .font(.footnote)

                Spacer(minLength: IhsanSpacing.xs)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isFiqhExpanded ? 180 : 0))
            }
            .foregroundStyle(tokens.inkSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Context and sources")
        .accessibilityValue(isFiqhExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isFiqhExpanded ? "Hides the context and source." : "Shows the context and source.")
    }

    private var header: some View {
        Text("What stands out")
            .font(.system(.title3, design: .serif, weight: .medium))
            .foregroundStyle(tokens.ink)
            .accessibilityAddTraits(.isHeader)
            .opacity(isLoading && !loadingPulse ? 0.62 : 1)
    }
}
