import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Modal sheet presented after the user taps a prayer dot.
///
/// All four `PrayerStatus` cases plus a jama'ah toggle. Status taps
/// fire `LogPrayerWithStatusIntent`; jama'ah fires `ToggleJamaahIntent`.
/// Both calls go through the parent `TodayViewModel` so the snapshot
/// refreshes and CloudKit propagation is centralized.
struct PrayerActionSheet: View {
    let prayer: Prayer
    let currentStatus: PrayerStatus?
    let isJamaah: Bool
    let onSelectStatus: (PrayerStatus) -> Void
    let onToggleJamaah: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header

                ForEach(PrayerStatus.allCases, id: \.self) { status in
                    statusRow(status)
                }

                jamaahRow
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .background(IhsanColor.ground)
    }

    private var header: some View {
        VStack(spacing: 0) {
            Text(prayer.displayNameEnglish)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(IhsanColor.textPrimary)
            Text(prayer.displayNameArabic)
                .font(.system(size: 14))
                .foregroundStyle(IhsanColor.textSecondary)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private func statusRow(_ status: PrayerStatus) -> some View {
        Button {
            onSelectStatus(status)
            onDismiss()
        } label: {
            HStack(spacing: 10) {
                PrayerStatusGlyph(status: status, size: 10)
                Text(label(status))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(IhsanColor.textPrimary)
                Spacer(minLength: 0)
                if currentStatus == status {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(IhsanColor.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(IhsanColor.atmospheric)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark \(prayer.displayNameEnglish) \(label(status))")
    }

    private var jamaahRow: some View {
        Button(action: {
            onToggleJamaah()
            onDismiss()
        }) {
            HStack(spacing: 10) {
                Image(systemName: isJamaah ? "person.3.fill" : "person.3")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        isJamaah ? IhsanColor.statusQada : IhsanColor.textSecondary
                    )
                Text(isJamaah ? "\(IhsanVocabulary.jamaahTitle) on" : "\(IhsanVocabulary.jamaahTitle) off")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(IhsanColor.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isJamaah ? IhsanColor.statusQada.opacity(0.6) : IhsanColor.atmospheric,
                        lineWidth: 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(IhsanColor.atmospheric.opacity(0.4))
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isJamaah ? "Turn \(IhsanVocabulary.jamaah) off" : "Mark as \(IhsanVocabulary.jamaah)")
    }

    private func label(_ status: PrayerStatus) -> String {
        switch status {
        case .onTime: "On time"
        case .late: "Late"
        case .missed: "Missed"
        case .qada: "Qada"
        }
    }
}
