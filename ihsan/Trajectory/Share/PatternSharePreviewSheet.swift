import SwiftUI
import IhsanCore
import IhsanDesignSystem

#if canImport(UIKit)
import UIKit

struct PatternSharePreviewSheet: View {
    let payload: PatternSharePayload

    @Environment(\.dismiss) private var dismiss
    @Environment(\.nowProvider) private var nowProvider

    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: 60)) { context in
            let now = nowProvider.resolve(context.date)
            let tokens = IhsanPageChrome.tokens(at: now)

            VStack(spacing: 0) {
                header(tokens: tokens)

                ScrollView {
                    VStack(spacing: IhsanSpacing.md) {
                        Text("This is what will be shared")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(uiImage: payload.image)
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel(payload.accessibilityDescription)

                        ShareLink(
                            item: payload.item,
                            preview: SharePreview(
                                payload.accessibilityDescription,
                                image: Image(uiImage: payload.image)
                            )
                        ) {
                            HStack(spacing: IhsanSpacing.sm) {
                                SettingsGlyphView(.share, color: tokens.metal)
                                    .frame(width: 18, height: 18)
                                Text("SHARE IMAGE")
                                    .font(IhsanFont.inscription)
                                    .tracking(1.6)
                                    .foregroundStyle(tokens.ink)
                            }
                            .padding(.horizontal, IhsanSpacing.lg)
                            .padding(.vertical, IhsanSpacing.md)
                            .contentShape(Rectangle())
                            .celestialPanel(
                                tokens: tokens,
                                cornerRadius: IhsanSpacing.smallCardRadius
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share this pattern image")
                        .accessibilityHint("Opens the system share sheet without a caption")
                    }
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.bottom, IhsanSpacing.md)
                }
            }
            .environment(\.timeOfDayOverride, now)
        }
        .ihsanManuscriptPage()
    }

    private func header(tokens: SkyPaletteTokens) -> some View {
        HStack {
            Text("Share the pattern")
                .font(.system(.title2, design: .serif, weight: .medium))
                .foregroundStyle(tokens.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                Haptics.impact(.light)
                dismiss()
            } label: {
                PatternPreviewCloseMark()
                    .stroke(
                        tokens.metal,
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                    .frame(width: IhsanSpacing.md, height: IhsanSpacing.md)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close share preview")
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.top, IhsanSpacing.md)
    }
}

private struct PatternPreviewCloseMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
#endif
