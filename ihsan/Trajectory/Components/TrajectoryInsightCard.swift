import IhsanDesignSystem
import SwiftUI

/// A single factual observation generated entirely on device. The card
/// has no score, recommendation, exhortation, or religious text.
struct TrajectoryInsightCard: View {
    let text: String?
    let isLoading: Bool
    let tokens: SkyPaletteTokens

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loadingPulse = false

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

            insightFilament

            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                header

                if isLoading {
                    loadingState
                } else if let text {
                    Text(text)
                        .font(IhsanFont.bodyEnglish)
                        .lineSpacing(3)
                        .foregroundStyle(tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isLoading ? "Generating on-device insight" : "On-device insight, \(text ?? "")"
        )
    }

    private var header: some View {
        HStack(spacing: IhsanSpacing.md) {
            ZStack {
                Circle()
                    .fill(tokens.metal.opacity(0.09))
                Circle()
                    .strokeBorder(tokens.metal.opacity(0.28), lineWidth: 0.75)
                PrayerPatternGlyph(tokens: tokens)
                    .padding(9)
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isLoading && loadingPulse ? 1.045 : 1)
            .opacity(isLoading && !loadingPulse ? 0.62 : 1)

            Text("PATTERN INSIGHT")
                .font(IhsanFont.inscription)
                .tracking(1.7)
                .foregroundStyle(tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Spacer(minLength: IhsanSpacing.xs)

            Text("ON DEVICE")
                .font(IhsanFont.inscription)
                .tracking(1.2)
                .foregroundStyle(tokens.metal)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tokens.metal.opacity(0.075), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(tokens.metal.opacity(0.22), lineWidth: 0.65)
                }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("Reading this period’s pattern")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)

            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 7) {
                    Capsule()
                        .fill(tokens.metal.opacity(loadingPulse ? 0.22 : 0.10))
                        .frame(width: proxy.size.width * 0.88, height: 7)
                    Capsule()
                        .fill(tokens.metal.opacity(loadingPulse ? 0.14 : 0.07))
                        .frame(width: proxy.size.width * 0.56, height: 7)
                }
            }
            .frame(height: 21)
            .accessibilityHidden(true)
        }
    }

    /// A single rising trace through five points: the five daily
    /// prayers rendered as a pattern, not a generic AI sparkle.
    private var insightFilament: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: proxy.size.width * 0.60, y: 0))
                path.addCurve(
                    to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.62),
                    control1: CGPoint(x: proxy.size.width * 0.82, y: proxy.size.height * 0.08),
                    control2: CGPoint(x: proxy.size.width * 0.88, y: proxy.size.height * 0.46)
                )
            }
            .stroke(tokens.metal.opacity(0.14), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Five exact points joined into one observation trace. Its last point
/// is leaf-gold, so the glyph reads as a live pattern rather than a
/// static chart or an "AI" magic symbol.
private struct PrayerPatternGlyph: View {
    let tokens: SkyPaletteTokens

    private let points: [CGPoint] = [
        CGPoint(x: 0.08, y: 0.74),
        CGPoint(x: 0.29, y: 0.48),
        CGPoint(x: 0.50, y: 0.60),
        CGPoint(x: 0.71, y: 0.25),
        CGPoint(x: 0.92, y: 0.38),
    ]

    var body: some View {
        GeometryReader { proxy in
            let resolved = points.map {
                CGPoint(x: $0.x * proxy.size.width, y: $0.y * proxy.size.height)
            }

            ZStack {
                Path { path in
                    guard let first = resolved.first else { return }
                    path.move(to: first)
                    for point in resolved.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    tokens.metal.opacity(0.58),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )

                ForEach(resolved.indices, id: \.self) { index in
                    Circle()
                        .fill(index == resolved.indices.last ? tokens.leafGold : tokens.lapis)
                        .overlay {
                            Circle().strokeBorder(tokens.metal.opacity(0.65), lineWidth: 0.55)
                        }
                        .frame(width: index == resolved.indices.last ? 5.5 : 4.5)
                        .position(resolved[index])
                }
            }
        }
        .accessibilityHidden(true)
    }
}
