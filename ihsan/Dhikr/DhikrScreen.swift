import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI

/// The tasbīḥ instrument — full-screen, on the current SkyPhase
/// ground. A ring of 33 fine engraved marks; each tap anywhere on the
/// counting surface gilds the next mark with a soft haptic; at 33 the
/// ring completes with a single distinct haptic and begins the next
/// cycle, the completed cycles resting as small gilded dots beneath
/// (33 → 66 → 99). Tapping is the whole interface — no buttons on the
/// counting surface; the label row above and the close affordance are
/// chrome, not counter.
///
/// VoiceOver: per-tap spoken counts are too chatty to count by — the
/// per-tap SOFT HAPTIC carries the rhythm instead, and the count is
/// spoken only at the 11 / 22 / 33 waypoints (the classic thirds of
/// a cycle). This is a deliberate accessibility choice, mirrored in
/// the a11y value read on demand.
///
/// Reduce Motion: the gilding "materialize" pour collapses to an
/// instant fill.
struct DhikrScreen: View {
    let onDismiss: () -> Void

    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The phrase is remembered across sessions — the instrument
    /// opens where the user left it.
    @AppStorage("IhsanDhikrPhrase") private var storedPhraseRaw: String = DhikrPhrase.subhanallah.rawValue
    @AppStorage("IhsanDhikrCustomPhrase") private var storedCustomPhrase: String = ""

    @State private var totalCount = 0
    @State private var isEditingCustomPhrase = false
    @State private var customDraft = ""

    /// The phrase the sitting opened on. Fixed at the first tap so
    /// swiping mid-sitting cannot retroactively change what the
    /// sequence is.
    @State private var sittingHead: DhikrPhrase?

    private var phrase: DhikrPhrase {
        DhikrPhrase(rawValue: storedPhraseRaw) ?? .subhanallah
    }

    private var sequence: TasbihSequence {
        TasbihSequence(head: sittingHead ?? phrase)
    }

    /// The phrase being recited right now — the sitting's own
    /// sequence position while it walks the three, the stored phrase
    /// otherwise.
    private var activePhrase: DhikrPhrase {
        totalCount == 0 ? phrase : sequence.phrase(atTotalCount: totalCount)
    }

    /// Marks gilded in the current cycle: 1…33, holding at 33 the
    /// moment a cycle completes.
    private var filledMarks: Int {
        sequence.markInCycle(atTotalCount: totalCount)
    }

    private var completedCycles: Int {
        sequence.completedCycles(atTotalCount: totalCount)
    }

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: nowProvider.now())

        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            VStack(spacing: IhsanSpacing.lg) {
                chrome(tokens: tokens)
                phraseRow(tokens: tokens)
                Spacer(minLength: 0)
                ring(tokens: tokens)
                cycleDots(tokens: tokens)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.top, IhsanSpacing.md)
            .padding(.bottom, IhsanSpacing.xl)
        }
        // The counting surface: everything below the chrome counts.
        .contentShape(Rectangle())
        .onTapGesture { count() }
        .accessibilityElement(children: .contain)
        .alert("Custom phrase", isPresented: $isEditingCustomPhrase) {
            TextField("Phrase", text: $customDraft)
            Button("Keep") {
                storedCustomPhrase = customDraft
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Counted quietly, stored on this device and your own iCloud.")
        }
    }

    // MARK: - Counting

    private func count() {
        if sittingHead == nil { sittingHead = phrase }
        let before = activePhrase
        totalCount += 1
        let position = filledMarks
        let after = activePhrase
        if position == TasbihSequence.cycleLength {
            // The boundary is a worship commit, and wears the same
            // settle every other commit wears.
            Haptics.settle()
        } else {
            // Each bead in between is lighter than the boundary, so
            // the boundary is felt as an arrival rather than as one
            // more of the same.
            Haptics.impact(.light)
        }
        // Spoken waypoints only — the per-tap haptic carries the
        // rhythm (see the type comment). A phrase HANDOVER is the one
        // thing a haptic cannot carry, so it is spoken by name. It
        // fires on the tap that lands ON 34/67 — the first mark of the
        // new third, by which point the 33rd has been recited.
        if before != after {
            announce(after.displayTransliteration)
        } else if position == 11 || position == 22 || position == TasbihSequence.cycleLength {
            announce("\(position)")
        }
    }

    private func announce(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func finish() {
        let total = totalCount
        let sitting = sequence
        let custom = storedCustomPhrase
        if total > 0 {
            let day = Calendar.current.startOfDay(for: nowProvider.now())
            // A walked sitting recorded as one row would name only the
            // phrase it ended on. One row per third says what was
            // actually recited; a single-phrase sitting is one row, as
            // before.
            var records: [(DhikrPhrase, Int)] = []
            if sitting.walksTheSequence {
                var remaining = total
                for phrase in TasbihSequence.phrases where remaining > 0 {
                    let count = min(remaining, TasbihSequence.cycleLength)
                    records.append((phrase, count))
                    remaining -= count
                }
                if remaining > 0, let last = TasbihSequence.phrases.last {
                    records.append((last, remaining))
                }
            } else {
                records.append((sitting.head, total))
            }
            Task {
                for (phrase, count) in records {
                    _ = try? await SaveDhikrSessionIntent(
                        count: count,
                        phrase: phrase,
                        customPhrase: phrase == .custom && !custom.isEmpty ? custom : nil,
                        sessionDate: day
                    ).perform()
                }
            }
        }
        onDismiss()
    }

    // MARK: - Chrome

    private func chrome(tokens: SkyPaletteTokens) -> some View {
        HStack {
            Text("TASBĪḤ")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(tokens.inkSecondary)
            Spacer()
            Button {
                Haptics.impact(.light)
                finish()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityHint(totalCount > 0 ? "Records the session and closes." : "Closes the counter.")
        }
    }

    // MARK: - The label row

    private func phraseRow(tokens: SkyPaletteTokens) -> some View {
        TabView(selection: Binding(
            get: { activePhrase },
            set: { candidate in
                // Swiping mid-sitting pins a phrase: the sequence
                // stops walking and the counter carries on where the
                // person put it. Swiping back to Subḥānallāh resumes
                // the walk from wherever the count already is.
                storedPhraseRaw = candidate.rawValue
                sittingHead = candidate
            }
        )) {
            ForEach(DhikrPhrase.allCases, id: \.self) { candidate in
                VStack(spacing: 4) {
                    Text(labelText(for: candidate))
                        .font(.system(.title3, design: .serif, weight: .medium))
                        .foregroundStyle(tokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let arabic = candidate.displayArabic {
                        Text(arabic)
                            .font(IhsanFont.bodyArabic)
                            .foregroundStyle(tokens.inkSecondary)
                    } else if candidate == .custom {
                        Text("TAP TO SET")
                            .font(.system(.caption2, weight: .semibold).smallCaps())
                            .tracking(1.6)
                            .foregroundStyle(tokens.inkSecondary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    // The label row is chrome, not counter: a tap on
                    // the custom page edits the phrase; other pages
                    // swallow the tap quietly.
                    if candidate == .custom {
                        customDraft = storedCustomPhrase
                        isEditingCustomPhrase = true
                    }
                }
                .tag(candidate)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phrase: \(labelText(for: activePhrase))")
        .accessibilityHint("Swipe up or down to change the phrase.")
        .accessibilityAdjustableAction { direction in
            let all = DhikrPhrase.allCases
            guard let index = all.firstIndex(of: activePhrase) else { return }
            let next: DhikrPhrase
            switch direction {
            case .increment:
                next = all[min(index + 1, all.count - 1)]
            case .decrement:
                next = all[max(index - 1, 0)]
            @unknown default:
                return
            }
            storedPhraseRaw = next.rawValue
            sittingHead = next
        }
    }

    private func labelText(for candidate: DhikrPhrase) -> String {
        if candidate == .custom, !storedCustomPhrase.isEmpty {
            return storedCustomPhrase
        }
        return candidate.displayTransliteration
    }

    // MARK: - The ring

    private func ring(tokens: SkyPaletteTokens) -> some View {
        // The ring is `RemembranceRing` from the design system — the
        // same component the adhkar sets count on, so the instrument
        // and the guided sets can never drift into two different
        // objects.
        RemembranceRing(
            count: TasbihSequence.cycleLength,
            filled: filledMarks,
            tokens: tokens,
            reduceMotion: reduceMotion
        ) {
            VStack(spacing: 2) {
                Text("\(filledMarks)")
                    .font(.system(size: 64, weight: .thin, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(tokens.ink)
                    .contentTransition(.numericText())
                if sequence.isComplete(atTotalCount: totalCount) {
                    // The three thirds are done. The hundredth that
                    // completes them is a full narrated supplication
                    // whose copy in this repo sits behind the
                    // scholar-review gate, so the instrument marks the
                    // arrival rather than printing unreviewed text.
                    Text("COMPLETE")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.metal)
                } else if totalCount > TasbihSequence.cycleLength {
                    Text("TOTAL \(totalCount)")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .monospacedDigit()
                        .foregroundStyle(tokens.inkSecondary)
                        .contentTransition(.numericText())
                }
            }
        }
        .frame(maxWidth: 340)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("dhikr.counter")
        .accessibilityLabel("Tasbīḥ counter")
        .accessibilityValue("\(filledMarks) of \(TasbihSequence.cycleLength)\(completedCycles > 0 ? ", \(completedCycles) cycles complete, total \(totalCount)" : "")")
        .accessibilityHint("Double-tap anywhere to count.")
        .accessibilityAction {
            count()
        }
    }

    // MARK: - Cycle dots

    /// Completed cycles rest beneath the ring — up to the classic
    /// three (99); the total above carries anything beyond.
    @ViewBuilder
    private func cycleDots(tokens: SkyPaletteTokens) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < min(completedCycles, 3) ? AnyShapeStyle(tokens.leafGold) : AnyShapeStyle(.clear))
                    .overlay {
                        Circle().strokeBorder(
                            index < min(completedCycles, 3)
                                ? tokens.keyline.opacity(0.55)
                                : tokens.metal.opacity(0.35),
                            lineWidth: 0.8
                        )
                    }
                    .frame(width: 7, height: 7)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

