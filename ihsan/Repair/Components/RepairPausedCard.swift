import IhsanDesignSystem
import SwiftUI

/// The Today card during an excused pause. Prayer times stay visible on the
/// plate above; this card simply rests — no countdown, no commit buttons.
/// The droplet that began the pause ends it, and nothing ends without the
/// user.
struct RepairPausedCard: View {
    let expectedEndDate: Date?
    let tokens: SkyPaletteTokens
    let onEndPause: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                Text("PAUSED")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.metal)

                Text("Paused.")
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)

                if let expectedEndDate {
                    Text("EXPECTED · \(expectedEndDate.formatted(.dateTime.month(.abbreviated).day()).uppercased())")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(tokens.inkSecondary)
                }
            }

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                onEndPause()
            } label: {
                Image(systemName: "drop")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(tokens.metal)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle().stroke(tokens.metal.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End the pause")
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background {
            RoundedRectangle(cornerRadius: IhsanSpacing.smallCardRadius, style: .continuous)
                .fill(tokens.panelFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: IhsanSpacing.smallCardRadius, style: .continuous)
                .stroke(tokens.panelStroke, lineWidth: 1)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .accessibilityElement(children: .contain)
    }
}
