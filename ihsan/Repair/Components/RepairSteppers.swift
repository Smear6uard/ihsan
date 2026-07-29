import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// A large, calm number with − / + on either side. Used for ages and
/// per-month day counts in setup.
struct RepairStepperField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unitLabel: String
    let tokens: SkyPaletteTokens

    var body: some View {
        HStack(spacing: IhsanSpacing.lg) {
            stepButton(systemName: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }

            VStack(spacing: IhsanSpacing.xxs) {
                Text("\(value)")
                    .font(.system(size: 44, weight: .light, design: .serif).monospacedDigit())
                    .foregroundStyle(tokens.ink)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .contentTransition(.numericText())
                Text(unitLabel.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary)
                    .shadow(color: tokens.inkHalo, radius: 2)
            }
            .frame(minWidth: 96)

            stepButton(systemName: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(unitLabel)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    private func stepButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.18)) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tokens.ink)
                .frame(width: 44, height: 44)
                .overlay {
                    Circle().stroke(tokens.metal.opacity(enabled ? 0.8 : 0.3), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// One category with an inline count and compact − / + controls, for the
/// "I know my count" path.
struct RepairCategoryCountRow: View {
    let category: QadaCategory
    @Binding var count: Int
    let tokens: SkyPaletteTokens

    var body: some View {
        HStack(spacing: IhsanSpacing.md) {
            Text(category.displayNameEnglish)
                .font(IhsanFont.rowPrayerName)
                .foregroundStyle(tokens.ink)

            Spacer(minLength: IhsanSpacing.sm)

            compactButton(systemName: "minus", enabled: count > 0) {
                count = max(0, count - 1)
            }

            TextField("0", value: $count, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(IhsanFont.tabular)
                .foregroundStyle(tokens.ink)
                .frame(minWidth: 56, maxWidth: 88)
                .padding(.vertical, IhsanSpacing.xs)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tokens.panelFill.opacity(0.6))
                }
                .onChange(of: count) { _, newValue in
                    if newValue < 0 { count = 0 }
                }

            compactButton(systemName: "plus", enabled: true) {
                count += 1
            }
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.displayNameEnglish), \(count) remaining")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: count += 1
            case .decrement: count = max(0, count - 1)
            @unknown default: break
            }
        }
    }

    private func compactButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.18)) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tokens.ink)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle().stroke(tokens.metal.opacity(enabled ? 0.7 : 0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
