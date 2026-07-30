import SwiftUI
import IhsanCore

/// The most-used composite. Combines the prayer symbol, English + Arabic
/// names, scheduled time, status pill, and jama'ah toggle into one row.
///
/// The status pill and jama'ah toggle are visually distinct and orthogonal:
/// they record two independent facts about the prayer (when it was offered
/// vs. whether in congregation).
public struct PrayerRow: View {
    public let prayer: Prayer
    public let scheduledTime: Date
    @Binding public var status: PrayerStatus?
    @Binding public var isJamaah: Bool

    public init(
        prayer: Prayer,
        scheduledTime: Date,
        status: Binding<PrayerStatus?>,
        isJamaah: Binding<Bool>
    ) {
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self._status = status
        self._isJamaah = isJamaah
    }

    public var body: some View {
        HStack(spacing: IhsanSpacing.md) {
            PrayerSymbol(prayer, size: 22)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text(prayer.displayNameEnglish)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(IhsanColor.textPrimary)
                    Text(prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(IhsanColor.textSecondary)
                }
                Text(scheduledTime, format: .dateTime.hour().minute())
                    .font(IhsanFont.tabular)
                    .foregroundStyle(IhsanColor.textMuted)
            }

            Spacer(minLength: IhsanSpacing.sm)

            if let status {
                StatusPill(status)
            }

            JamaahToggle(isJamaah: $isJamaah)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .frame(height: IhsanSpacing.prayerRowHeight)
        .ihsanGlass(intensity: .regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [prayer.displayNameEnglish]
        let timeStr = scheduledTime.formatted(date: .omitted, time: .shortened)
        parts.append("scheduled for \(timeStr)")
        if let status {
            parts.append("status \(status.rawValue)")
        }
        parts.append(isJamaah ? "in \(IhsanVocabulary.jamaah)" : "individual")
        return parts.joined(separator: ", ")
    }
}

private struct PrayerRowPreviewWrapper: View {
    @State private var fajrStatus: PrayerStatus? = .onTime
    @State private var fajrJamaah = true
    @State private var dhuhrStatus: PrayerStatus? = .late
    @State private var dhuhrJamaah = false
    @State private var asrStatus: PrayerStatus? = nil
    @State private var asrJamaah = false
    @State private var maghribStatus: PrayerStatus? = .qada
    @State private var maghribJamaah = false
    @State private var ishaStatus: PrayerStatus? = .missed
    @State private var ishaJamaah = false

    var body: some View {
        ScrollView {
            VStack(spacing: IhsanSpacing.sm) {
                PrayerRow(
                    prayer: .fajr,
                    scheduledTime: TimeOfDay.fajr.representativeDate,
                    status: $fajrStatus,
                    isJamaah: $fajrJamaah
                )
                PrayerRow(
                    prayer: .dhuhr,
                    scheduledTime: TimeOfDay.dhuhr.representativeDate,
                    status: $dhuhrStatus,
                    isJamaah: $dhuhrJamaah
                )
                PrayerRow(
                    prayer: .asr,
                    scheduledTime: TimeOfDay.asr.representativeDate,
                    status: $asrStatus,
                    isJamaah: $asrJamaah
                )
                PrayerRow(
                    prayer: .maghrib,
                    scheduledTime: TimeOfDay.maghrib.representativeDate,
                    status: $maghribStatus,
                    isJamaah: $maghribJamaah
                )
                PrayerRow(
                    prayer: .isha,
                    scheduledTime: TimeOfDay.isha.representativeDate,
                    status: $ishaStatus,
                    isJamaah: $ishaJamaah
                )
            }
            .padding()
        }
        .ihsanBackground()
    }
}

#Preview("Prayer row — all five") {
    PrayerRowPreviewWrapper()
}
