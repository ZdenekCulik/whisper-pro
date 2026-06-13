import SwiftUI

struct MiniRecorderView<S: RecorderStateProvider & ObservableObject>: View {
    @ObservedObject var stateProvider: S
    @ObservedObject var recorder: Recorder
    @ObservedObject var assistantSession: AssistantSession
    @ObservedObject private var variantStore = WidgetVariantStore.shared
    let onRecordButtonTapped: () -> Void
    let onCloseTapped: () -> Void
    let onAssistantFollowUp: (String) -> Void

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
            recordingState: stateProvider.recordingState
        )
    }

    // Temporary corner badge so the user can flip through V1–V15 live. Remove once a variant is chosen.
    private var variantBadge: some View {
        Button(action: { variantStore.next() }) {
            Text(variantStore.variant.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(4)
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
            } else {
                variantStore.variant.makeView(variantContext)
                    .overlay(alignment: .topTrailing) { variantBadge }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasAssistantResponse)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
