import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboardingV2: Bool
    @EnvironmentObject var fluidAudioModelManager: FluidAudioModelManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var transcriptionModelManager: TranscriptionModelManager
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var isShowingSkipOnboardingConfirmation = false

    let contentMaxWidth: CGFloat = 560

    var body: some View {
        let isTranscriptionModelDownloaded = coordinator.isTranscriptionModelDownloaded(
            using: fluidAudioModelManager
        )

        ZStack(alignment: .bottomLeading) {
            OnboardingBackground()

            Group {
                switch coordinator.stage {
                case .permissions:
                    OnboardingPermissionsScreen(
                        contentMaxWidth: contentMaxWidth,
                        isComplete: coordinator.requiredPermissionsGranted,
                        activePermission: coordinator.activePermission,
                        hasRequestedScreenRecording: coordinator.hasRequestedScreenRecording,
                        showAccessibilityRepairHint: coordinator.permissions.shouldShowAccessibilityRepairHint,
                        stepNumber: { coordinator.permissions.stepNumber(for: $0) },
                        status: { coordinator.permissions.status(for: $0) },
                        isLocked: { coordinator.permissions.isLocked($0) },
                        actionTitle: { coordinator.permissions.actionTitle(for: $0) },
                        onSelect: coordinator.permissions.setActivePermission,
                        onAction: coordinator.permissions.performAction,
                        onQuit: {
                            NSApplication.shared.terminate(nil)
                        },
                        onRepairAccessibility: coordinator.permissions.repairAccessibility,
                        onRecheck: coordinator.permissions.refreshPermissionStatuses,
                        onContinue: coordinator.flow.goToMicrophoneStep
                    )
                        .transition(.opacity)
                case .microphone:
                    OnboardingMicrophoneScreen(
                        contentMaxWidth: contentMaxWidth,
                        onBack: coordinator.flow.goToPermissionsStep,
                        onContinue: coordinator.flow.goToModelStep
                    )
                        .transition(.opacity)
                case .model:
                    OnboardingSonioxSetupScreen(
                        contentMaxWidth: contentMaxWidth,
                        onBack: coordinator.flow.goToMicrophoneStep,
                        onContinue: {
                            coordinator.flow.continueFromModelStep(
                                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
                            )
                        },
                        onSkipConfirmed: {
                            coordinator.flow.skipSonioxSetupAndContinue(
                                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
                            )
                        },
                        onAppear: {
                            if let model = coordinator.requiredTranscriptionModel {
                                coordinator.flow.downloadTranscriptionModel(
                                    model,
                                    modelManager: fluidAudioModelManager
                                )
                            }
                        }
                    )
                        .transition(.opacity)
                case .api:
                    OnboardingAPIScreen(
                        aiService: aiService,
                        contentMaxWidth: contentMaxWidth,
                        providerOptions: coordinator.onboardingProviderOptions,
                        selectedProvider: coordinator.selectedOnboardingProviderBinding(aiService: aiService),
                        isSelectedProviderVerified: coordinator.isSelectedAPIProviderVerified,
                        canContinue: coordinator.isReadyForExperience(
                            isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
                        ),
                        isShowingSkipWarning: $coordinator.isShowingSkipAPISetupWarning,
                        onVerificationChanged: coordinator.flow.refreshAPIVerification,
                        onBack: coordinator.flow.goBackToModelStep,
                        onContinue: {
                            coordinator.flow.goToTrustStep(
                                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
                            )
                        },
                        onRequestSkip: coordinator.flow.requestSkipAPISetup,
                        onConfirmSkip: {
                            coordinator.flow.skipAPISetupAndContinue(
                                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
                            )
                        }
                    )
                        .transition(.opacity)
                case .trust:
                    OnboardingTrustScreen(
                        contentMaxWidth: contentMaxWidth,
                        onBack: coordinator.flow.goToPreviousTrustStep,
                        onContinue: {
                            coordinator.flow.completeOnboarding(
                                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
                            ) {
                                hasCompletedOnboardingV2 = true
                            }
                        }
                    )
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OnboardingProgressBadge(
                currentStep: coordinator.currentStepNumber,
                totalSteps: coordinator.totalStepCount
            )
            .padding(.leading, 28)
            .padding(.bottom, 26)
            .allowsHitTesting(false)

            if shouldShowSkipOnboardingButton {
                skipOnboardingButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 22)
                    .padding(.trailing, 28)
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 820, minHeight: 680)
        .animation(.easeInOut(duration: 0.22), value: coordinator.stage)
        .animation(.easeInOut(duration: 0.18), value: shouldShowSkipOnboardingButton)
        .alert("Skip onboarding?", isPresented: $isShowingSkipOnboardingConfirmation) {
            Button("Continue", role: .cancel) { }
            Button("Skip Onboarding", role: .destructive) {
                coordinator.flow.skipOnboarding {
                    hasCompletedOnboardingV2 = true
                }
            }
        } message: {
            Text("It is recommended that you complete the onboarding.")
        }
        .onAppear {
            coordinator.flow.ensureDefaultOnboardingProvider()
            coordinator.permissions.refreshPermissionStatuses()
            coordinator.flow.refreshAPIVerification()
            coordinator.flow.reconcileStage(
                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
            )
        }
        .onDisappear {
            coordinator.permissions.cancelRefreshTask()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.permissions.refreshPermissionStatuses()
            coordinator.flow.reconcileStage(
                isTranscriptionModelDownloaded: isTranscriptionModelDownloaded
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiProviderKeyChanged)) { _ in
            coordinator.flow.refreshAPIVerification()
        }
    }

    private var shouldShowSkipOnboardingButton: Bool {
        coordinator.requiredPermissionsGranted && coordinator.stage != .permissions
    }

    private var skipOnboardingButton: some View {
        Button {
            isShowingSkipOnboardingConfirmation = true
        } label: {
            Text("Skip")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(AppTheme.Surface.control.opacity(0.55))
                )
        }
        .buttonStyle(.plain)
        .help("Skip onboarding")
    }
}

#Preview {
    OnboardingView(hasCompletedOnboardingV2: .constant(false))
}
