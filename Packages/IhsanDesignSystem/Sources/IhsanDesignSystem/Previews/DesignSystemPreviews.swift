import SwiftUI
import IhsanCore

/// Catalog view exhibiting every component once. Open this in the Xcode
/// canvas when building a new screen — it's the index-of-the-design-system
/// the team references to compose new views from primitives.
struct DesignSystemCatalog: View {
    @State private var fajrStatus: PrayerStatus? = .onTime
    @State private var fajrJamaah = true
    @State private var dhuhrStatus: PrayerStatus? = .late
    @State private var dhuhrJamaah = false
    @State private var asrStatus: PrayerStatus? = nil
    @State private var asrJamaah = false
    @State private var notifications = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.xl) {

                Group {
                    SectionHeader("Hero countdown")
                    CountdownDisplay(
                        targetPrayer: .maghrib,
                        targetTime: .now.addingTimeInterval(7_200)
                    )
                }

                Group {
                    SectionHeader("Prayer rows")
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
                    }
                }

                Group {
                    SectionHeader("Status pills")
                    HStack(spacing: IhsanSpacing.sm) {
                        ForEach(PrayerStatus.allCases, id: \.self) { status in
                            StatusPill(status)
                        }
                    }
                }

                Group {
                    SectionHeader("Reflection prompt")
                    ReflectionPromptCard(
                        prompt: "Looking back at your day — what helped you turn toward Allah, and what pulled you away?",
                        citation: "— al-Ghazali, Ihya 'Ulum al-Din, Book 38",
                        onBegin: {}
                    )
                }

                Group {
                    SectionHeader("Heatmap — last 30 days")
                    GlassCard {
                        HeatmapGrid(
                            values: (0..<30).map { Double(($0 * 17) % 100) / 100.0 },
                            columns: 7
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                Group {
                    SectionHeader("Heatmap dot ramp")
                    GlassCard {
                        HStack(spacing: IhsanSpacing.heatmapDotSpacing) {
                            ForEach(0..<11, id: \.self) { i in
                                HeatmapDot(completion: Double(i) / 10.0)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Group {
                    SectionHeader("Settings rows")
                    VStack(spacing: IhsanSpacing.sm) {
                        SettingsRow(
                            title: "Mecca",
                            subtitle: "Auto-detected",
                            icon: "location.fill",
                            action: {}
                        )
                        SettingsRow(
                            title: "Method",
                            subtitle: "Umm al-Qura",
                            icon: "function",
                            action: {}
                        )
                        SettingsRow(
                            title: "Adhan reminders",
                            icon: "bell.fill"
                        ) {
                            Toggle("", isOn: $notifications)
                                .labelsHidden()
                                .tint(IhsanColor.textPrimary)
                        }
                    }
                }

                Group {
                    SectionHeader("Prayer symbols")
                    GlassCard {
                        HStack(spacing: IhsanSpacing.lg) {
                            ForEach(Prayer.allCases, id: \.self) { prayer in
                                VStack(spacing: IhsanSpacing.xs) {
                                    PrayerSymbol(prayer, size: 28)
                                    Text(prayer.displayNameEnglish)
                                        .font(IhsanFont.smallCaps)
                                        .foregroundStyle(IhsanColor.textMuted)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Group {
                    SectionHeader("Hairline divider")
                    GlassCard {
                        VStack(spacing: IhsanSpacing.md) {
                            Text("Above")
                                .font(IhsanFont.bodyEnglish)
                                .foregroundStyle(IhsanColor.textPrimary)
                            HairlineDivider()
                            Text("Below")
                                .font(IhsanFont.bodyEnglish)
                                .foregroundStyle(IhsanColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Group {
                    SectionHeader("Typography scale")
                    GlassCard {
                        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                            Text("Hero countdown")
                                .font(IhsanFont.heroCountdown)
                                .foregroundStyle(IhsanColor.textPrimary)
                            Text("Title")
                                .font(IhsanFont.title)
                                .foregroundStyle(IhsanColor.textPrimary)
                            Text("Subtitle")
                                .font(IhsanFont.subtitle)
                                .foregroundStyle(IhsanColor.textPrimary)
                            Text("Body English regular")
                                .font(IhsanFont.bodyEnglish)
                                .foregroundStyle(IhsanColor.textPrimary)
                            Text("Body English bold")
                                .font(IhsanFont.bodyEnglishBold)
                                .foregroundStyle(IhsanColor.textPrimary)
                            Text("نص عربي")
                                .font(IhsanFont.bodyArabic)
                                .foregroundStyle(IhsanColor.textPrimary)
                            Text("12:34")
                                .font(IhsanFont.tabular)
                                .foregroundStyle(IhsanColor.textSecondary)
                            Text("SMALL CAPS LABEL")
                                .font(IhsanFont.smallCaps)
                                .tracking(1.2)
                                .foregroundStyle(IhsanColor.textMuted)
                            Text("— citation")
                                .font(IhsanFont.citation)
                                .foregroundStyle(IhsanColor.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .ihsanBackground()
    }
}

#Preview("Design System Catalog") {
    DesignSystemCatalog()
}
