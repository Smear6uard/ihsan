import SwiftUI
import IhsanCore

/// A single representative scene rendered five times — once per prayer time
/// of day — using `\.timeOfDayOverride` to drive the adaptive tint.
///
/// This is the visual proof that the iridescent quality is working: the
/// same screen at Fajr should look different from the same screen at Asr,
/// but the difference comes from the glass surfaces shimmering differently,
/// not from the background changing. The ground stays the same #0E1428 in
/// every panel.
private struct TimeOfDaySweepScene: View {
    let label: String
    @State private var status: PrayerStatus? = .onTime
    @State private var jamaah = true

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            Text(label.uppercased())
                .font(IhsanFont.smallCaps)
                .tracking(1.2)
                .foregroundStyle(IhsanColor.textMuted)

            CountdownDisplay(
                targetPrayer: .maghrib,
                targetTime: .now.addingTimeInterval(7_200)
            )

            PrayerRow(
                prayer: .fajr,
                scheduledTime: TimeOfDay.fajr.representativeDate,
                status: $status,
                isJamaah: $jamaah
            )

            ReflectionPromptCard(
                prompt: "What helped you turn, and what pulled you away?",
                citation: "— al-Ghazali"
            )
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ihsanBackground()
    }
}

struct TimeOfDaySweep: View {
    private static let scenes: [(time: TimeOfDay, label: String)] = [
        (.fajr, "Fajr — cool violet"),
        (.dhuhr, "Dhuhr — neutral cream"),
        (.asr, "Asr — warm honey"),
        (.maghrib, "Maghrib — rose gold"),
        (.isha, "Isha — deep magenta")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<Self.scenes.count, id: \.self) { i in
                    let scene = Self.scenes[i]
                    TimeOfDaySweepScene(label: scene.label)
                        .frame(width: 360)
                        .environment(
                            \.timeOfDayOverride,
                            scene.time.representativeDate
                        )
                }
            }
        }
    }
}

#Preview("Time-of-day sweep — five panels") {
    TimeOfDaySweep()
}

#Preview("Time-of-day sweep — Fajr alone") {
    TimeOfDaySweepScene(label: "Fajr — cool violet")
        .environment(\.timeOfDayOverride, TimeOfDay.fajr.representativeDate)
}

#Preview("Time-of-day sweep — Asr alone") {
    TimeOfDaySweepScene(label: "Asr — warm honey")
        .environment(\.timeOfDayOverride, TimeOfDay.asr.representativeDate)
}

#Preview("Time-of-day sweep — Isha alone") {
    TimeOfDaySweepScene(label: "Isha — deep magenta")
        .environment(\.timeOfDayOverride, TimeOfDay.isha.representativeDate)
}
