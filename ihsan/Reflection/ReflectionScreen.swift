import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanFiqhConfig
import IhsanIntents

/// The Reflection tab. Three vertical layers:
///
/// 1. A hero composer that shows today's curated prompt + citation and the
///    text/voice writing surface in a single glass card.
/// 2. The past-reflections feed, grouped by week ("THIS WEEK", "LAST WEEK",
///    "<MONTH YEAR>"), with text + voice + mixed shapes.
/// 3. An empty state on first run with framing copy from FiqhConfig.
///
/// Two integration points worth flagging when reading this file:
///
/// - **Writes go through the view-model, not an App Intent.** Reflections
///   are heavier writes than the atomic intents — see `ReflectionWriter`.
/// - **Deeplink consumption.** When `OpenReflectionIntent` fires, the App
///   Group UserDefaults key `ihsan.deeplink.reflection.open` carries a
///   timestamp. The screen reads it on `.task` and on scene-phase active,
///   sets `@FocusState` to focus the editor, and clears the flag.
struct ReflectionScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Reflection.createdAt, order: .reverse)
    private var reflections: [Reflection]

    @State private var viewModel: ReflectionViewModel?
    @State private var presentedReflection: Reflection?
    @State private var recordingTick: TimeInterval = 0
    @State private var recorderTimerTask: Task<Void, Never>?

    @FocusState private var isInputFocused: Bool

    var body: some View {
        content
        .ihsanManuscriptPage()
        .task {
            if viewModel == nil {
                viewModel = ReflectionViewModel(modelContext: modelContext)
                ReflectionHaptics.prepareAll()
            }
            await viewModel?.bootstrap(reflections: reflections)
            viewModel?.consumeDeeplinkIfNeeded()
            applyFocusRequestIfNeeded()
        }
        .onChange(of: reflections.count) {
            viewModel?.refresh(reflections: reflections)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel?.consumeDeeplinkIfNeeded()
                applyFocusRequestIfNeeded()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: OpenReflectionIntent.inAppNotificationName
            )
        ) { _ in
            // Handles the warm in-app path even when the Reflection
            // tab is already the active tab — `.task` only runs on
            // first appearance, so without this listener a second tap
            // on "Begin" wouldn't re-focus the editor.
            viewModel?.consumeDeeplinkIfNeeded()
            applyFocusRequestIfNeeded()
        }
        .onChange(of: isRecordingActive) { _, isActive in
            if isActive {
                ReflectionHaptics.recordStart()
                startRecorderTimer()
            } else {
                stopRecorderTimer()
                // Catch implicit finalizations the user didn't initiate —
                // AVAudioSession interruption, app backgrounding finishing
                // the recording on its own, etc. The view-model is
                // idempotent, so this is a no-op when an explicit stop
                // already triggered the attach + transcribe flow.
                if let viewModel {
                    Task { await viewModel.endRecording() }
                }
            }
        }
        .sheet(item: $presentedReflection) { reflection in
            if let viewModel {
                ReflectionDetailSheet(
                    reflection: reflection,
                    isPlaybackActive: viewModel.playback.activeMemoID == reflection.voiceMemoID,
                    isPlaybackPlaying: isPlaybackPlayingForCurrentSheet(viewModel: viewModel, reflection: reflection),
                    playbackCurrentTime: viewModel.playback.currentTime,
                    onTogglePlayback: { viewModel.togglePlayback(for: reflection) }
                )
            }
        }
    }

    // MARK: - Top-level content branching

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                loadingView
            case .ready(let snapshot):
                readyView(snapshot: snapshot, viewModel: viewModel)
            case .error(let message):
                errorView(message: message)
            }
        } else {
            loadingView
        }
    }

    private var loadingView: some View {
        VStack(spacing: IhsanSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(IhsanColor.brass)
            Text("LOADING REFLECTIONS…")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(IhsanColor.skyForegroundSecondary())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: IhsanSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(IhsanColor.brassDark)
            Text(message)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.skyForegroundPrimary())
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Ready

    @ViewBuilder
    private func readyView(
        snapshot: ReflectionState.Snapshot,
        viewModel: ReflectionViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                header(promptDate: snapshot.promptDate)
                    .padding(.horizontal, IhsanSpacing.md)

                ReflectionHeroComposer(
                    prompt: snapshot.prompt,
                    draftText: bindingDraftText(viewModel),
                    isRecording: isRecordingActive,
                    recordingElapsed: recordingTick,
                    isTranscribing: viewModel.isTranscribing,
                    attachedAudio: viewModel.draft.attachedAudio,
                    canSave: viewModel.draft.canSave && !viewModel.isTranscribing && !isRecordingActive,
                    isPlayingAttached: isPlaybackPlayingForDraft(viewModel: viewModel),
                    attachedCurrentTime: isPlayingAttachedActive(viewModel: viewModel) ? viewModel.playback.currentTime : 0,
                    inlineErrorMessage: viewModel.inputErrorMessage,
                    onStartRecording: { Task { await viewModel.beginRecording() } },
                    onStopRecording: {
                        ReflectionHaptics.recordStop()
                        Task { await viewModel.endRecording() }
                    },
                    onCancelRecording: {
                        ReflectionHaptics.recordStop()
                        viewModel.cancelRecording()
                    },
                    onDiscardAudio: {
                        Haptics.impact(.light)
                        viewModel.discardAttachedAudio()
                    },
                    onTogglePlayback: { viewModel.togglePlaybackForDraft() },
                    onSave: { handleSave(viewModel: viewModel) },
                    isFocused: $isInputFocused
                )
                .padding(.horizontal, IhsanSpacing.md)

                feedSection(snapshot: snapshot, viewModel: viewModel)

                Color.clear.frame(height: IhsanSpacing.xl)
            }
            .padding(.top, IhsanSpacing.md)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(promptDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The day's quiet account")
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(IhsanColor.skyForegroundPrimary())

            Text("REFLECTION · \(HijriDateFormatter.string(from: promptDate).uppercased())")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(IhsanColor.brass)

            OrnamentalDivider()
                .padding(.top, IhsanSpacing.xs)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Feed

    @ViewBuilder
    private func feedSection(
        snapshot: ReflectionState.Snapshot,
        viewModel: ReflectionViewModel
    ) -> some View {
        if snapshot.isEmpty {
            ReflectionEmptyState(
                title: snapshot.framing.reflectionEmptyTitle,
                subtitle: snapshot.framing.reflectionEmptySubtitle
            )
            .padding(.top, IhsanSpacing.lg)
            .padding(.horizontal, IhsanSpacing.md)
        } else {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Text("EARLIER ENTRIES")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(IhsanColor.brass)
                    .padding(.horizontal, IhsanSpacing.md)

                ForEach(snapshot.sections) { section in
                    VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                        Text(section.title.uppercased())
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                            .foregroundStyle(IhsanColor.brassDark)
                            .padding(.horizontal, IhsanSpacing.md)

                        VStack(spacing: IhsanSpacing.sm) {
                            ForEach(section.entries) { entry in
                                ReflectionFeedCard(
                                    reflection: entry,
                                    isPlaybackActive: viewModel.playback.activeMemoID == entry.voiceMemoID,
                                    isPlaybackPlaying: isPlaybackPlayingFor(
                                        viewModel: viewModel,
                                        reflection: entry
                                    ),
                                    playbackCurrentTime: playbackCurrentTimeFor(
                                        viewModel: viewModel,
                                        reflection: entry
                                    ),
                                    onTogglePlayback: { viewModel.togglePlayback(for: entry) },
                                    onTap: {
                                        Haptics.impact(.light)
                                        presentedReflection = entry
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, IhsanSpacing.md)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var isRecordingActive: Bool {
        guard let viewModel else { return false }
        if case .recording = viewModel.recorder.state { return true }
        return false
    }

    private func bindingDraftText(_ viewModel: ReflectionViewModel) -> Binding<String> {
        Binding(
            get: { viewModel.draft.typedText },
            set: { viewModel.draft.typedText = $0 }
        )
    }

    private func handleSave(viewModel: ReflectionViewModel) {
        Haptics.impact(.medium)
        let saved = viewModel.save()
        if saved {
            ReflectionHaptics.saveSuccess()
            isInputFocused = false
        }
    }

    /// Drives the elapsed-time counter while recording. Stops itself when
    /// the recording ends. Cancellation also fires from `.onDisappear`
    /// implicitly via the task storage.
    private func startRecorderTimer() {
        recorderTimerTask?.cancel()
        recordingTick = 0
        recorderTimerTask = Task { [weak vm = viewModel] in
            while !Task.isCancelled {
                guard let vm else { return }
                guard case .recording = vm.recorder.state else { return }
                recordingTick = vm.recorder.currentDuration
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopRecorderTimer() {
        recorderTimerTask?.cancel()
        recorderTimerTask = nil
    }

    private func isPlaybackPlayingFor(
        viewModel: ReflectionViewModel,
        reflection: Reflection
    ) -> Bool {
        guard viewModel.playback.activeMemoID == reflection.voiceMemoID else {
            return false
        }
        return viewModel.playback.isPlaying
    }

    private func playbackCurrentTimeFor(
        viewModel: ReflectionViewModel,
        reflection: Reflection
    ) -> TimeInterval {
        guard viewModel.playback.activeMemoID == reflection.voiceMemoID else {
            return 0
        }
        return viewModel.playback.currentTime
    }

    private func isPlaybackPlayingForCurrentSheet(
        viewModel: ReflectionViewModel,
        reflection: Reflection
    ) -> Bool {
        guard viewModel.playback.activeMemoID == reflection.voiceMemoID else {
            return false
        }
        return viewModel.playback.isPlaying
    }

    private func isPlaybackPlayingForDraft(viewModel: ReflectionViewModel) -> Bool {
        guard let memoID = viewModel.draft.attachedAudio?.memoID,
              viewModel.playback.activeMemoID == memoID
        else { return false }
        return viewModel.playback.isPlaying
    }

    private func isPlayingAttachedActive(viewModel: ReflectionViewModel) -> Bool {
        guard let memoID = viewModel.draft.attachedAudio?.memoID else {
            return false
        }
        return viewModel.playback.activeMemoID == memoID
    }

    /// Applies a deeplink-driven focus request once the view is mounted.
    /// Done in a Task to give SwiftUI time to wire up the FocusState.
    private func applyFocusRequestIfNeeded() {
        guard let viewModel, viewModel.requestsInputFocus else { return }
        viewModel.requestsInputFocus = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            isInputFocused = true
        }
    }
}

// `Reflection.id` is `UUID` — `Identifiable` already satisfied by
// SwiftData's `@Model` macro, no extension needed.
