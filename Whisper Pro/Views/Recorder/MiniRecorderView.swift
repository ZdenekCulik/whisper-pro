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
            isCanceling: stateProvider.isCanceling
        )
    }

    var body: some View {
        Group {
            if hasAssistantResponse {
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
            } else if shouldShowCoachSuggestion,
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
                widgetVariantStore.variant.makeView(variantContext)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasAssistantResponse)
        .animation(.easeInOut(duration: 0.22), value: shouldShowCoachSuggestion)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
