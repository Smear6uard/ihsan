import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI

/// The reading and counting surface for one remembrance set.
///
/// Full-screen on the SkyPhase ground, like the tasbīḥ instrument it
/// grew out of. The item's Arabic is the page; transliteration and
/// translation sit beneath it in the quieter register; the counting
/// ring — the same `RemembranceRing` the instrument uses — sits under
/// that, scaled to this item's transmitted count. A tap anywhere
/// counts.
///
/// Everything that is not counting is chrome and says so by being a
/// button: the close affordance, the source, the sequence band. Buttons
/// consume their own taps, so the counting surface is genuinely
/// everything else.
///
/// VoiceOver: the reading order is Arabic, translation, count. The
/// transliteration is hidden — the line was just spoken in Arabic, and
/// hearing an English voice work through the romanisation immediately
/// afterwards is noise. Per-tap counts are not announced, for the same
/// reason the instrument does not announce them: they are too chatty to
/// count by, and the haptic carries the rhythm.
struct AdhkarSetScreen: View {
    let category: AdhkarCategory
    let onDismiss: () -> Void

    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var state: AdhkarSetState
    @State private var isShowingSource = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var hasRecorded = false

    /// Whether romanised Arabic is shown. Read from Set; the surface
    /// itself never toggles it.
    private let showsTransliteration: Bool

    /// How long a completed item rests gilded before the set moves on —
    /// long enough to see the mark take, short enough not to be a wait.
    private static let advanceDelay: Duration = .milliseconds(450)

    init(
        category: AdhkarCategory,
        showsTransliteration: Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.category = category
        self.showsTransliteration = showsTransliteration
        self.onDismiss = onDismiss
        _state = State(initialValue: AdhkarSetState(items: BundledAdhkar.items(in: category)))
    }

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: nowProvider.now())

        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            VStack(spacing: IhsanSpacing.md) {
                chrome(tokens: tokens)

                if state.isEmpty {
                    Spacer()
                } else {
                    AdhkarSequenceBand(
                        states: state.markStates,
                        labels: bandLabels,
                        tokens: tokens,
                        reduceMotion: reduceMotion,
                        onSelect: { position in
                            advanceTask?.cancel()
                            state.move(to: position)
                            isShowingSource = false
                        }
                    )

                    if state.isSetComplete {
                        completion(tokens: tokens)
                    } else {
                        reading(tokens: tokens)
                    }
                }
            }
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.top, IhsanSpacing.md)
            .padding(.bottom, IhsanSpacing.lg)
        }
        // The counting surface: everything the chrome does not claim.
        .contentShape(Rectangle())
        .onTapGesture { count() }
        .gesture(swipe)
        .accessibilityElement(children: .contain)
        .onDisappear { record() }
    }

    // MARK: - Chrome

    private func chrome(tokens: SkyPaletteTokens) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(category.inscription)
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(tokens.inkSecondary)

            Spacer(minLength: IhsanSpacing.sm)

            if !state.isEmpty {
                Text("\(state.completedItemCount) OF \(state.items.count)")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .monospacedDigit()
                    .foregroundStyle(tokens.inkSecondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(state.completedItemCount) of \(state.items.count) counted")
            }

            Button {
                Haptics.impact(.light)
                record()
                onDismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityHint(
                state.completedItemCount > 0
                    ? "Records the sitting and closes."
                    : "Closes the set."
            )
        }
    }

    // MARK: - The reading

    @ViewBuilder
    private func reading(tokens: SkyPaletteTokens) -> some View {
        if let item = state.currentItem {
            // The reading sits centred in whatever room the ring leaves
            // it, and scrolls only when the text is genuinely taller
            // than that — a short duʿāʾ stranded at the top of a screen
            // of empty page is the dead zone this app does not allow.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: IhsanSpacing.sm) {
                        // The reading itself counts. Scroll content
                        // takes its own taps, so the outer counting
                        // surface never sees them — without this, the
                        // middle of the screen is dead.
                        VStack(spacing: IhsanSpacing.sm) {
                            ArabicScriptText(reading: item.arabic, color: tokens.ink)

                            if showsTransliteration {
                                TransliterationText(item.transliteration, color: tokens.inkSecondary)
                            }

                            TranslationText(item.translation, color: tokens.ink)

                            if let note = item.note {
                                Text(note)
                                    .font(IhsanFont.citation)
                                    .foregroundStyle(tokens.inkSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { count() }

                        // The source is chrome and keeps its own tap.
                        source(item: item, tokens: tokens)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            ring(item: item, tokens: tokens)
        }
    }

    /// Provenance, one tap away and never decorative: the label is a
    /// button, and what it reveals is the citation exactly as the
    /// content file carries it.
    private func source(item: AdhkarItem, tokens: SkyPaletteTokens) -> some View {
        Button {
            Haptics.impact(.light)
            isShowingSource.toggle()
        } label: {
            VStack(spacing: 2) {
                Text(isShowingSource ? item.source.citation : "SOURCE")
                    .font(isShowingSource ? IhsanFont.citation : IhsanFont.inscription)
                    .tracking(isShowingSource ? 0 : 1.6)
                    .foregroundStyle(tokens.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, IhsanSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Source")
        .accessibilityValue(isShowingSource ? item.source.citation : "hidden")
        .accessibilityHint("Double-tap to \(isShowingSource ? "hide" : "show") where this comes from.")
    }

    private func ring(item: AdhkarItem, tokens: SkyPaletteTokens) -> some View {
        RemembranceRing(
            count: item.repetitions,
            filled: state.currentCount,
            tokens: tokens,
            reduceMotion: reduceMotion
        ) {
            // A count of one has nothing to tally — the whole ring is
            // the one, and a numeral in the middle of it would be
            // counting to a number the reader can see.
            if item.repetitions > 1 {
                Text("\(state.currentCount)")
                    .font(.system(size: 44, weight: .thin, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(tokens.ink)
                    .contentTransition(.numericText())
            }
        }
        // Sized to what it has to hold. A ring of a hundred marks needs
        // the diameter; a ring of one is a single round mark, and drawn
        // at a hundred's size it reads as a hole in the page rather
        // than as a thing to be gilded.
        .frame(maxWidth: ringSide(for: item), maxHeight: ringSide(for: item))
        .contentShape(Rectangle())
        .onTapGesture { count() }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("adhkar.counter")
        .accessibilityLabel("Count")
        .accessibilityValue("\(state.currentCount) of \(item.repetitions)")
        .accessibilityHint("Double-tap anywhere to count.")
        .accessibilityAction { count() }
    }

    private func ringSide(for item: AdhkarItem) -> CGFloat {
        switch item.repetitions {
        case 1: 96
        case ...RemembranceRingGeometry.arcThreshold: 148
        default: 186
        }
    }

    // MARK: - Completion

    /// The set closes the way everything else in this app closes: one
    /// quiet line, and nothing else. No figure, no praise, no total
    /// carried anywhere.
    private func completion(tokens: SkyPaletteTokens) -> some View {
        VStack(spacing: IhsanSpacing.md) {
            Spacer(minLength: 0)

            OrnamentalFlourish(size: 22, tint: tokens.leafGold, opacity: 1.0)

            Text(category.completionLine)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.md)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Counting

    private func count() {
        guard !state.isEmpty, !state.isSetComplete else { return }

        // A completed item rests gilded for a beat before the set moves
        // on. A tap arriving inside that beat must not vanish: someone
        // counting at a steady rhythm would lose one count at every
        // item boundary, which for a counting instrument is the worst
        // thing it can do. The tap moves the set on and counts.
        if state.isCurrentComplete {
            advanceTask?.cancel()
            state.advanceToNextOutstanding()
            isShowingSource = false
            guard !state.isCurrentComplete else { return }
        }

        switch state.count() {
        case .counted:
            // Lighter than the boundary, so the boundary is felt as an
            // arrival rather than as one more of the same.
            Haptics.impact(.light)
        case .itemCompleted:
            // An item's transmitted count is kept: the same settle
            // every other commit in this app wears.
            Haptics.settle()
            scheduleAdvance()
        case .setCompleted:
            Haptics.settle()
        case .nothingToCount:
            break
        }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        guard !reduceMotion else {
            state.advanceToNextOutstanding()
            isShowingSource = false
            return
        }
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: Self.advanceDelay)
            guard !Task.isCancelled else { return }
            state.advanceToNextOutstanding()
            isShowingSource = false
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 60
                else { return }
                advanceTask?.cancel()
                isShowingSource = false
                if value.translation.width < 0 {
                    state.moveToNext()
                } else {
                    state.moveToPrevious()
                }
            }
    }

    private var bandLabels: [String] {
        state.items.enumerated().map { index, item in
            "\(index + 1) of \(state.items.count), \(item.transliteration)"
        }
    }

    // MARK: - Recording

    /// One sitting, written once. Called both from the close button and
    /// from `onDisappear`, so a swipe-down dismissal records the same
    /// as a tap — and the flag makes the second call a no-op.
    private func record() {
        guard !hasRecorded else { return }
        let completed = state.completedItemCount
        guard completed > 0 else {
            hasRecorded = true
            return
        }
        hasRecorded = true
        let day = PrayerCycleClock.sharedCycleDate(at: nowProvider.now())
        let category = category
        Task {
            _ = try? await SaveAdhkarSessionIntent(
                category: category,
                completedItemCount: completed,
                sessionDate: day
            ).perform()
        }
    }
}
