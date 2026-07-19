import SwiftUI

struct MiniRecorderView<S: RecorderStateProvider & ObservableObject>: View {
    @ObservedObject var stateProvider: S
    @ObservedObject var recorder: Recorder
    @ObservedObject var assistantSession: AssistantSession
    @ObservedObject private var widgetVariantStore = WidgetVariantStore.shared
    @ObservedObject private var englishCoach = EnglishCoachService.shared
    let onRecordButtonTapped: () -> Void
    let onCloseTapped: () -> Void
    let onAssistantFollowUp: (String) -> Void
    let onCoachDismiss: () -> Void
    let onCoachHover: (Bool) -> Void

    // MARK: - Layout Constants

    private let controlBarHeight: CGFloat = 40
    private let assistantWidth: CGFloat = 520
    private let expandedCornerRadius: CGFloat = 14

    private var hasAssistantResponse: Bool {
        assistantSession.isVisible
    }

    private var shouldShowCloseButton: Bool {
        hasAssistantResponse &&
            stateProvider.recordingState == .idle &&
            !assistantSession.isBusy
    }

    private var shouldShowCoachSuggestion: Bool {
        englishCoach.latestSuggestion != nil &&
            !hasAssistantResponse &&
            stateProvider.recordingState == .idle
    }

    private var liveAssistantFollowUpText: String {
        guard stateProvider.recordingState == .recording else { return "" }
        return stateProvider.partialTranscript
    }

    private var controlBar: some View {
        HStack(spacing: 0) {
            if shouldShowCloseButton {
                RecorderCloseButton(action: onCloseTapped)
                    .padding(.leading, 10)
            }

            Spacer(minLength: 0)

            RecorderStatusDisplay(
                currentState: stateProvider.recordingState,
                audioMeter: recorder.audioMeter
            )

            Spacer(minLength: 0)
        }
        .frame(height: controlBarHeight)
    }

    private var variantContext: WidgetVariantContext {
        WidgetVariantContext(
            committed: stateProvider.committedTranscript,
            partial: stateProvider.partialTail,
            audioMeter: recorder.audioMeter,
            recordingState: stateProvider.recordingState,
            isCancelConfirming: stateProvider.isCancelConfirming,
            isCanceling: stateProvider.isCanceling,
            pasteHintText: stateProvider.pasteHintText
        )
    }

    /// V2 morphs its own black container into the pill (true shrink, no separate view
    /// swap) — see Variant2View's `isPasteHint`. Other variants fall back to the plain
    /// PasteHintPillView below.
    private var variantHandlesPasteHintItself: Bool {
        widgetVariantStore.variant == .v2
    }

    // Root cause of the old ⌘V morph bug: `widgetVariantStore.variant.makeView(...)` used
    // to appear at TWO different positions in this if/else-if chain (a dedicated
    // "V2 paste hint" branch, and the default branch). SwiftUI's ViewBuilder assigns view
    // identity by branch *position* in a `_ConditionalContent` tree, not by the content the
    // branch produces — so even though both branches called the exact same function, moving
    // between them still tore down the old view and inserted a brand-new instance. The new
    // instance rendered instantly at its target (collapsed pill) size with no interpolation,
    // while the old instance was still cross-fading out at its (expanded) size — that's
    // exactly the "full panel and pill both visible, then the panel pops away" bug. Fix:
    // `makeView` is now called from exactly one place, so it is always the same persistent
    // view whose *own* width/height/content morphs (see Variant2View.isPasteHint) instead of
    // SwiftUI swapping instances.
    var body: some View {
        Group {
            if let pasteHintText = stateProvider.pasteHintText, !variantHandlesPasteHintItself {
                // Waveform/transcript fade out and the panel shrinks to a small pill
                // instead of a toast overlapping it — see RecorderUIManager.
                PasteHintPillView(text: pasteHintText)
            } else if hasAssistantResponse && stateProvider.pasteHintText == nil {
                VStack(spacing: 0) {
                    AssistantPanelView(
                        session: assistantSession,
                        liveFollowUpText: liveAssistantFollowUpText,
                        onSend: onAssistantFollowUp
                    )
                    Divider().background(Color.white.opacity(0.15))
                    controlBar
                }
                .frame(width: assistantWidth)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: expandedCornerRadius, style: .continuous))
            } else if shouldShowCoachSuggestion, stateProvider.pasteHintText == nil,
                      let suggestion = englishCoach.latestSuggestion {
                CoachCardView(suggestion: suggestion) {
                    englishCoach.clearSuggestion()
                    onCoachDismiss()
                }
                .frame(width: 420)
                .onHover { onCoachHover($0) }
                // Lift off the window's bottom edge so the card's drop shadow
                // (radius 18 + y:7) isn't clipped when the panel is dragged.
                .padding(.bottom, 20)
            } else {
                // Selected floating-panel look (default V2). Pick in Settings → Interface.
                // Also covers V2's self-handled "⌘V to paste" morph (pasteHintText != nil
                // && variantHandlesPasteHintItself) — variantContext already carries
                // pasteHintText, so Variant2View morphs its own container in place.
                widgetVariantStore.variant.makeView(variantContext)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasAssistantResponse)
        .animation(.easeInOut(duration: 0.22), value: shouldShowCoachSuggestion)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: stateProvider.pasteHintText)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Paste Hint Pill

private struct PasteHintPillView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black)
            .clipShape(Capsule())
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
