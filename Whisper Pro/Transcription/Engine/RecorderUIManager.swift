import Foundation
import SwiftUI
import os

enum RecorderPanelStyle: String, CaseIterable, Identifiable {
    case notch
    case mini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notch:
            return String(localized: "Notch")
        case .mini:
            return String(localized: "Mini")
        }
    }

    static var stored: RecorderPanelStyle {
        let rawValue = UserDefaults.standard.string(forKey: "RecorderType") ?? RecorderPanelStyle.mini.rawValue
        return RecorderPanelStyle(rawValue: rawValue) ?? .mini
    }
}

@MainActor
protocol RecorderPanelPresenting: AnyObject {
    var isRecorderPanelVisible: Bool { get }
    func dismissRecorderPanel() async
    func dismissRecorderPanelWithPasteHint() async
}

@MainActor
class RecorderUIManager: ObservableObject, RecorderPanelPresenting {
    @Published var recorderPanelStyle: RecorderPanelStyle = .stored {
        didSet {
            guard oldValue != recorderPanelStyle else { return }
            rebuildVisiblePanel(previousStyle: oldValue)
            UserDefaults.standard.set(recorderPanelStyle.rawValue, forKey: "RecorderType")
        }
    }

    var recorderType: String {
        get { recorderPanelStyle.rawValue }
        set { recorderPanelStyle = RecorderPanelStyle(rawValue: newValue) ?? .mini }
    }

    @Published var isRecorderPanelVisible = false {
        didSet {
            guard oldValue != isRecorderPanelVisible else { return }

            if isRecorderPanelVisible {
                showRecorderPanel()
            } else {
                hideRecorderPanel()
            }
        }
    }

    private var notchWindowManager: NotchWindowManager?
    private var miniWindowManager: MiniWindowManager?
    private var coachDismissTask: Task<Void, Never>?
    private var pasteHintDismissTask: Task<Void, Never>?

    private weak var engine: WhisperProEngine?
    private var recorder: Recorder?

    /// Current engine recording state, for external commit/cancel decisions.
    var currentRecordingState: RecordingState? { engine?.recordingState }

    /// Commit the active recording and auto-send (Enter) after paste.
    func commitWithAutoSend(modeId: UUID? = nil) async {
        engine?.forceAutoSendOnCommit = true
        await toggleRecorderPanel(modeId: modeId)
    }

    /// First Escape: arm/disarm the in-panel "Esc again to cancel" confirm overlay.
    func setCancelConfirming(_ confirming: Bool) {
        engine?.isCancelConfirming = confirming
    }

    /// Second Escape: play the dismiss effect (see DismissEffectStyle) in the panel,
    /// then tear it down.
    func cancelRecordingAnimated() async {
        guard let engine else { return }
        engine.isCancelConfirming = false
        engine.isCanceling = true
        // Let the widget play its chosen dismiss effect (sparkle / vanish / sequential
        // dissolve / content scatter — see Variant2View) before the window is actually
        // torn down.
        let effectDuration = DismissEffectStyle.stored.duration
        try? await Task.sleep(nanoseconds: UInt64(effectDuration * 1_000_000_000))
        // Keep isCanceling true through teardown so the pill stays collapsed/faded and
        // doesn't animate back up before the window is hidden. Reset only after the
        // panel is gone so the next spawn starts clean.
        await cancelRecordingAfterEffect()
        engine.isCanceling = false
    }

    /// Same teardown as `cancelRecording()`, used only right after the panel has
    /// already played its own dismiss effect above. Most effects already animate the
    /// shell/panel to invisible themselves by this point, so — unlike the plain
    /// `dismissRecorderPanel()` path, which intentionally keeps MiniWindowManager's own
    /// reveal/dismiss fade for a normal successful dismiss — the window must NOT also
    /// re-animate its scale/opacity/offset on top of that: if the effect's timing is
    /// even slightly off, the window's own fade would visibly stack on top of it,
    /// which is exactly the live-vs-preview mismatch this exists to close. The one
    /// exception is `.textScatterOnly` (V6), which deliberately never touches the
    /// shell — see `DismissEffectStyle.skipsWindowFadeOnCancel` — so it needs the
    /// window's own fade left on to make the shell disappear at all.
    private func cancelRecordingAfterEffect() async {
        guard let engine = engine else { return }
        await engine.cancelRecording()

        pasteHintDismissTask?.cancel()
        pasteHintDismissTask = nil
        engine.pasteHintText = nil
        cancelCoachSuggestionDisplay()

        switch recorderPanelStyle {
        case .notch:
            // Notch never uses DismissEffectStyle, so its own hide animation is still
            // the only exit it plays — nothing to skip.
            notchWindowManager?.hide()
        case .mini:
            miniWindowManager?.hide(skipAnimation: DismissEffectStyle.stored.skipsWindowFadeOnCancel)
        }
        isRecorderPanelVisible = false
        engine.assistantSession.reset()
    }

    private let logger = Logger(subsystem: "com.prakashjoshipax.whisperpro", category: "RecorderUIManager")

    init() {}

    /// Call after WhisperProEngine is created to break the circular init dependency.
    func configure(engine: WhisperProEngine, recorder: Recorder) {
        self.engine = engine
        self.recorder = recorder
        setupNotifications()
    }

    // MARK: - Recorder Panel Management

    private func showRecorderPanel() {
        guard let engine = engine, let recorder = recorder else { return }

        switch recorderPanelStyle {
        case .notch:
            if notchWindowManager == nil {
                notchWindowManager = NotchWindowManager(
                    engine: engine,
                    recorder: recorder,
                    assistantSession: engine.assistantSession,
                    onRecordButtonTapped: { [weak self] in
                        Task { @MainActor in
                            await self?.toggleRecorderPanel()
                        }
                    },
                    onCloseTapped: { [weak self] in
                        Task { @MainActor in
                            await self?.dismissRecorderPanel()
                        }
                    },
                    onAssistantFollowUp: { [weak engine] text in
                        Task { @MainActor in
                            await engine?.sendAssistantFollowUp(text)
                        }
                    }
                )
            }
            notchWindowManager?.show()
        case .mini:
            if miniWindowManager == nil {
                miniWindowManager = MiniWindowManager(
                    engine: engine,
                    recorder: recorder,
                    assistantSession: engine.assistantSession,
                    onRecordButtonTapped: { [weak self] in
                        Task { @MainActor in
                            await self?.toggleRecorderPanel()
                        }
                    },
                    onCloseTapped: { [weak self] in
                        Task { @MainActor in
                            await self?.dismissRecorderPanel()
                        }
                    },
                    onAssistantFollowUp: { [weak engine] text in
                        Task { @MainActor in
                            await engine?.sendAssistantFollowUp(text)
                        }
                    },
                    onCoachDismiss: { [weak self] in
                        Task { @MainActor in
                            self?.dismissCoachSuggestionPanel()
                        }
                    },
                    onCoachHover: { [weak self] hovering in
                        Task { @MainActor in
                            self?.setCoachSuggestionHovered(hovering)
                        }
                    }
                )
            }
            miniWindowManager?.show()
        }
    }

    private func hideRecorderPanel() {
        switch recorderPanelStyle {
        case .notch:
            notchWindowManager?.hide()
        case .mini:
            miniWindowManager?.hide()
        }
    }

    private func rebuildVisiblePanel(previousStyle: RecorderPanelStyle) {
        guard isRecorderPanelVisible else { return }

        switch previousStyle {
        case .notch:
            notchWindowManager?.destroyWindow()
            notchWindowManager = nil
        case .mini:
            miniWindowManager?.destroyWindow()
            miniWindowManager = nil
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            showRecorderPanel()
        }
    }

    // MARK: - Recorder Panel Management

    func toggleRecorderPanel(modeId: UUID? = nil) async {
        guard let engine = engine else { return }
        cancelCoachSuggestionDisplay()

        if isRecorderPanelVisible {
            switch engine.recordingState {
            case .recording:
                await engine.toggleRecord(modeId: modeId)
            case .starting, .transcribing, .enhancing:
                await cancelRecording()
            case .idle:
                if engine.assistantSession.canSendFollowUp {
                    SoundManager.shared.playStartSound()
                    await engine.toggleRecord(
                        modeId: modeId,
                        isAssistantFollowUp: true
                    )
                } else {
                    await dismissRecorderPanel()
                }
            case .busy:
                await dismissRecorderPanel()
            }
        } else {
            SoundManager.shared.playStartSound()
            isRecorderPanelVisible = true
            await engine.toggleRecord(modeId: modeId)
        }
    }

    func dismissRecorderPanel() async {
        guard let engine = engine else { return }

        pasteHintDismissTask?.cancel()
        pasteHintDismissTask = nil
        engine.pasteHintText = nil

        cancelCoachSuggestionDisplay()
        hideRecorderPanel()
        isRecorderPanelVisible = false
        engine.assistantSession.reset()
    }

    /// Called instead of `dismissRecorderPanel()` when the transcript couldn't be
    /// auto-pasted (no editable field focused). Shows a brief "⌘V to paste" hint
    /// in the panel instead of a toast that would overlap it, then dismisses as
    /// normal. Falls back to the toast if the panel isn't on screen at all.
    func dismissRecorderPanelWithPasteHint() async {
        guard isRecorderPanelVisible, let engine = engine else {
            NotificationManager.shared.showNotification(
                title: String(localized: "Copied to clipboard — paste anywhere with ⌘V"),
                type: .success
            )
            return
        }

        cancelCoachSuggestionDisplay()
        engine.pasteHintText = String(localized: "⌘V to paste")

        pasteHintDismissTask?.cancel()
        pasteHintDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self, !Task.isCancelled else { return }
            self.pasteHintDismissTask = nil
            await self.dismissRecorderPanel()
        }
    }

    func resetOnLaunch() async {
        guard let engine = engine else { return }
        logger.notice("Resetting recording state on launch")
        pasteHintDismissTask?.cancel()
        pasteHintDismissTask = nil
        engine.pasteHintText = nil
        cancelCoachSuggestionDisplay()
        await engine.resetRecordingSession()
        hideRecorderPanel()
        isRecorderPanelVisible = false
        engine.assistantSession.reset()
    }

    func cancelRecording() async {
        guard let engine = engine else { return }
        await engine.cancelRecording()
        await dismissRecorderPanel()
    }

    // MARK: - Notification Handling

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleRecorderPanelNotification),
            name: .toggleRecorderPanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissRecorderPanelNotification),
            name: .dismissRecorderPanel,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnglishCoachCorrectionReady(_:)),
            name: .englishCoachCorrectionReady,
            object: nil
        )
    }

    @objc public func handleToggleRecorderPanelNotification() {
        Task {
            await toggleRecorderPanel()
        }
    }

    @objc public func handleDismissRecorderPanelNotification() {
        Task {
            switch engine?.recordingState {
            case .starting, .recording, .transcribing, .enhancing:
                await cancelRecording()
            case .idle, .busy, nil:
                await dismissRecorderPanel()
            }
        }
    }

    @objc public func handleEnglishCoachCorrectionReady(_ notification: Notification) {
        guard let suggestion = notification.object as? CoachSuggestion else { return }
        showCoachSuggestionPanel(suggestion)
    }

    private func showCoachSuggestionPanel(_ suggestion: CoachSuggestion) {
        guard recorderPanelStyle == .mini else { return }
        guard engine?.recordingState == .idle else { return }
        guard engine?.assistantSession.isVisible != true else { return }

        showRecorderPanel()
        scheduleCoachSuggestionDismissal(for: suggestion)
    }

    /// While the mouse is over the coach card, pause the auto-dismiss so the user
    /// can read it; restart the timer once the mouse leaves.
    func setCoachSuggestionHovered(_ hovering: Bool) {
        if hovering {
            coachDismissTask?.cancel()
            coachDismissTask = nil
        } else if let suggestion = EnglishCoachService.shared.latestSuggestion {
            scheduleCoachSuggestionDismissal(for: suggestion)
        }
    }

    private func scheduleCoachSuggestionDismissal(for suggestion: CoachSuggestion) {
        coachDismissTask?.cancel()
        coachDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard EnglishCoachService.shared.latestSuggestion?.id == suggestion.id else { return }
            guard self.engine?.recordingState == .idle,
                  self.engine?.assistantSession.isVisible != true else { return }
            self.dismissCoachSuggestionPanel()
        }
    }

    private func dismissCoachSuggestionPanel() {
        cancelCoachSuggestionDisplay()
        hideRecorderPanel()
        isRecorderPanelVisible = false
    }

    private func cancelCoachSuggestionDisplay() {
        coachDismissTask?.cancel()
        coachDismissTask = nil
        EnglishCoachService.shared.clearSuggestion()
    }
}
