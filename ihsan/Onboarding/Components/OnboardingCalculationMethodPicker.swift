import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Modal picker for overriding the auto-detected calculation method.
///
/// Reuses the same row treatment that Settings will use — a tappable
/// glass row with the method name, regional hint, and a checkmark
/// affordance. The list is presented in the same order as
/// `CalculationMethodChoice.allCases` so the layout is stable.
struct OnboardingCalculationMethodPicker: View {
    @Binding var selection: CalculationMethodChoice
    @Environment(\.dismiss) private var dismiss

    /// `.other` is excluded — it requires manual angle configuration
    /// the prayer-times provider doesn't support yet, so showing it as
    /// a tappable choice would lead to a runtime error on the Today
    /// screen.
    private var methods: [CalculationMethodChoice] {
        CalculationMethodChoice.allCases.filter { $0 != .other }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: IhsanSpacing.sm) {
                    ForEach(methods, id: \.self) { method in
                        row(for: method)
                    }
                }
                .padding(IhsanSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ihsanBackground()
            .navigationTitle("Calculation method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(IhsanColor.textPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(for method: CalculationMethodChoice) -> some View {
        Button {
            selection = method
            dismiss()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                    Text(method.displayName)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(IhsanColor.textPrimary)
                    Text(method.regionHint)
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: IhsanSpacing.sm)
                if selection == method {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IhsanColor.textPrimary)
                }
            }
            .padding(IhsanSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                ),
                intensity: selection == method ? .regular : .subtle
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                )
                .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(method.displayName)
        .accessibilityHint(method.regionHint)
        .accessibilityValue(selection == method ? "Selected" : "")
    }
}
