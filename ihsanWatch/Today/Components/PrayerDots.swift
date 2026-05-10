import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// 5-dot row showing today's logged status across all prayers.
///
/// The active prayer (driven by Digital Crown) is haloed; tap-and-hold
/// is reserved for the parent so the dot row remains a passive overview
/// from the perspective of gesture handling.
struct PrayerDots: View {
    let snapshot: TodayState.Snapshot
    let selectedPrayer: Prayer

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PrayerListOrder.all, id: \.self) { prayer in
                VStack(spacing: 2) {
                    PrayerStatusGlyph(
                        status: snapshot.status(for: prayer),
                        size: 7,
                        isSelected: prayer == selectedPrayer,
                        isJamaah: snapshot.isJamaah(for: prayer)
                    )

                    Text(prayer.displayNameEnglish.prefix(1))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(
                            prayer == selectedPrayer
                                ? IhsanColor.textPrimary
                                : IhsanColor.textMuted
                        )
                        .accessibilityHidden(true)
                }
                .frame(minWidth: 18)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let logged = PrayerListOrder.all.compactMap { prayer -> String? in
            guard let status = snapshot.status(for: prayer) else { return nil }
            return "\(prayer.displayNameEnglish) \(statusLabel(status))"
        }
        if logged.isEmpty {
            return "No prayers logged yet today."
        }
        return logged.joined(separator: ", ")
    }

    private func statusLabel(_ status: PrayerStatus) -> String {
        switch status {
        case .onTime: "on time"
        case .late: "late"
        case .missed: "missed"
        case .qada: "qada"
        }
    }
}
