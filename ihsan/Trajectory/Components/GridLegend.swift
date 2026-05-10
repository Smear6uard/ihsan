import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Legend strip placed beneath the daily-practice grid. Decodes the
/// six cell types into small-caps inscriptions so users learn the
/// visual language without a separate help screen.
struct GridLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            row(.onTime, jamaah: true, label: "JAMAʿAH")
            row(.onTime, jamaah: false, label: "ON TIME")
            row(.late, jamaah: false, label: "LATE")
            row(.qada, jamaah: false, label: "QADĀ — MADE UP")
            row(.missed, jamaah: false, label: "MISSED")
            row(nil, jamaah: false, label: "NOT YET LOGGED")
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: jamaʿah, on time, late, qadā made up, missed, not yet logged.")
    }

    private func row(_ status: PrayerStatus?, jamaah: Bool, label: String) -> some View {
        HStack(spacing: IhsanSpacing.sm) {
            DayPrayerCell(
                completion: PrayerCompletion(
                    prayer: .fajr,
                    status: status,
                    withJamaah: jamaah
                ),
                size: 18
            )
            Text(label)
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(IhsanColor.brassDark.opacity(0.85))
        }
    }
}

#Preview("Legend") {
    GridLegend()
        .padding()
        .ihsanIlluminatedPanel(intensity: .regular)
        .padding()
        .ihsanManuscriptPage()
}
