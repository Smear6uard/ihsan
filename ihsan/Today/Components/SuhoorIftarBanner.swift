import SwiftUI
import IhsanDesignSystem

struct SuhoorIftarBanner: View {
    let suhoorEnd: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, suhoorEnd.timeIntervalSince(context.date))

            if remaining > 0 {
                HStack(spacing: IhsanSpacing.md) {
                    VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                        Text("Suhoor ends in")
                            .font(IhsanFont.smallCaps)
                            .foregroundStyle(IhsanColor.textSecondary)

                        Text(formatted(seconds: remaining))
                            .font(.system(size: 30, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(IhsanColor.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.25), value: remaining)
                    }

                    Spacer(minLength: IhsanSpacing.md)

                    Text("Fajr")
                        .font(IhsanFont.smallCaps)
                        .foregroundStyle(IhsanColor.textMuted)
                        .padding(.horizontal, IhsanSpacing.sm + 2)
                        .padding(.vertical, IhsanSpacing.xs + 2)
                        .background {
                            Capsule()
                                .fill(IhsanColor.textPrimary.opacity(0.07))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
                                }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, IhsanSpacing.md)
                .padding(.horizontal, IhsanSpacing.md)
                .ihsanGlassHero()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(formatted(seconds: remaining)) until suhoor ends at Fajr")
            }
        }
    }

    private func formatted(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "−%02d:%02d:%02d", h, m, s)
    }
}
