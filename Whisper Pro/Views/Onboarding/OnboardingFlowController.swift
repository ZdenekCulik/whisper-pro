import SwiftUI

@MainActor
final class OnboardingFlowController {
    private unowned let coordinator: OnboardingCoordinator

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    func goToPermissionsStep() {
        coordinator.storedStage = OnboardingStage.permissions.rawValue
    }

    func goToMicrophoneStep() {
        guard coordinator.requiredPermissionsGranted else { return }
        coordinator.storedStage = OnboardingStage.microphone.rawValue
    }

    func goToModelStep() {
        guard coordinator.requiredPermissionsGranted,
              coordinator.hasSelectedOnboardingMicrophone else { return }
        coordinator.storedStage = OnboardingStage.model.rawValue
    }

    /// Continues out of the Soniox setup (`.model`) stage. This is now the last setup
    /// step before Trust: the old "experience" practice steps demoed dictation on the
    /// local transcription model, which is broken/confusing on a fresh install that has
    /// no local model downloaded yet (onboarding now sets users up with Soniox). So this
    /// installs the single default Dictation starter mode directly and heads to Trust.
    func continueFromModelStep(isTranscriptionModelDownloaded: Bool) {
        guard coordinator.requiredPermissionsGranted,
              coordinator.hasSelectedOnboardingMicrophone else { return }
        coordinator.hasSkippedAPISetup = true
        coordinator.isSelectedAPIProviderVerified = false
        installDictationStarterMode()
        goToTrustStep(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded)
    }

    func skipSonioxSetupAndContinue(isTranscriptionModelDownloaded: Bool) {
        coordinator.hasSkippedSonioxSetup = true
        continueFromModelStep(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded)
    }

    func goBackToModelStep() {
        guard coordinator.requiredPermissionsGranted else {
            goToPermissionsStep()
            return
        }

        coordinator.storedStage = OnboardingStage.model.rawValue
    }

    func goToTrustStep(isTranscriptionModelDownloaded: Bool) {
        guard coordinator.isReadyForExperience(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded) else { return }
        coordinator.storedStage = OnboardingStage.trust.rawValue
    }

    func requestSkipAPISetup() {
        coordinator.isShowingSkipAPISetupWarning = true
    }

    /// `.api` (the old LLM/AI-enhancement provider setup stage) is no longer a navigable
    /// destination — see the safety net in `reconcileStage`. This is kept only so a
    /// leftover/legacy persisted `.api` stage can't strand the user on dead UI; it mirrors
    /// `continueFromModelStep`'s "mark skipped, install Dictation, go to Trust" behavior.
    func skipAPISetupAndContinue(isTranscriptionModelDownloaded: Bool) {
        coordinator.hasSkippedAPISetup = true
        coordinator.isSelectedAPIProviderVerified = false
        installDictationStarterMode()
        goToTrustStep(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded)
    }

    func goToPreviousTrustStep() {
        coordinator.storedStage = OnboardingStage.model.rawValue
    }

    func reconcileStage(isTranscriptionModelDownloaded: Bool) {
        if coordinator.stage == .microphone && !coordinator.requiredPermissionsGranted {
            goToPermissionsStep()
        }

        if coordinator.stage == .model &&
            (!coordinator.requiredPermissionsGranted || !coordinator.hasSelectedOnboardingMicrophone) {
            goToFirstIncompleteSetupStep(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded)
        }

        // `.api` (the old LLM/AI-enhancement provider setup stage) is no longer a navigable
        // destination. This is a safety net for a leftover/legacy persisted `.api` stage from a
        // previous build so it can't strand the user on dead UI.
        if coordinator.stage == .api {
            goToFirstIncompleteSetupStep(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded)
        }

        if coordinator.stage == .trust &&
            !coordinator.isReadyForExperience(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded) {
            goToFirstIncompleteSetupStep(isTranscriptionModelDownloaded: isTranscriptionModelDownloaded)
        }
    }

    func goToFirstIncompleteSetupStep(isTranscriptionModelDownloaded: Bool) {
        if !coordinator.requiredPermissionsGranted {
            coordinator.storedStage = OnboardingStage.permissions.rawValue
        } else if !coordinator.hasSelectedOnboardingMicrophone {
            coordinator.storedStage = OnboardingStage.microphone.rawValue
        } else {
            coordinator.storedStage = OnboardingStage.model.rawValue
        }
    }

    func downloadTranscriptionModel(
        _ model: FluidAudioModel,
        modelManager: FluidAudioModelManager
    ) {
        guard coordinator.requiredPermissionsGranted,
              coordinator.hasSelectedOnboardingMicrophone,
              !modelManager.isFluidAudioModelDownloaded(model),
              !modelManager.isFluidAudioModelDownloading(model) else {
            return
        }

        Task {
            await modelManager.downloadFluidAudioModel(model)
        }
    }

    func completeOnboarding(onComplete: () -> Void) {
        guard coordinator.stage == .trust else { return }

        OnboardingStorageKeys.onboardingKeys.forEach {
            coordinator.defaults.removeObject(forKey: $0)
        }
        activateCleanTranscriptionMode()
        onComplete()
    }

    func skipOnboarding(onComplete: () -> Void) {
        OnboardingStorageKeys.onboardingKeys.forEach {
            coordinator.defaults.removeObject(forKey: $0)
        }
        onComplete()
    }

    func refreshAPIVerification() {
        coordinator.isSelectedAPIProviderVerified = APIKeyManager.shared.hasAPIKey(
            forProvider: coordinator.selectedOnboardingProvider.rawValue
        )

        if coordinator.isSelectedAPIProviderVerified {
            coordinator.hasSkippedAPISetup = false
        }
    }

    func ensureDefaultOnboardingProvider() {
        if let storedProvider = AIProvider(rawValue: coordinator.storedOnboardingAIProvider),
           coordinator.onboardingProviderOptions.contains(storedProvider) {
            return
        }

        let defaultProvider: AIProvider = coordinator.onboardingProviderOptions.contains(.groq)
            ? .groq
            : coordinator.onboardingProviderOptions.first ?? .groq
        coordinator.storedOnboardingAIProvider = defaultProvider.rawValue
    }

    func selectOnboardingProvider(_ provider: AIProvider, aiService: AIService) {
        guard coordinator.onboardingProviderOptions.contains(provider) else { return }

        coordinator.storedOnboardingAIProvider = provider.rawValue

        if APIKeyManager.shared.hasAPIKey(forProvider: provider.rawValue) {
            aiService.selectedProvider = provider
            aiService.selectModel(provider.defaultModel, for: provider)
        }

        refreshAPIVerification()
    }

    /// Installs the single default "Dictation" starter mode (local transcription, no AI
    /// enhancement) so a fresh install always ends onboarding with exactly one configured
    /// mode. This used to happen incrementally as the user worked through the removed
    /// "experience" practice steps; now it happens once, right after Soniox setup. Dictation
    /// has no associated prompt template, so there's nothing to seed via
    /// `StarterModePromptSeeder` the way the AI-enabled starter modes needed.
    private func installDictationStarterMode() {
        StarterModeFactory.install(
            kinds: [.clean],
            provider: coordinator.selectedOnboardingProvider,
            modelName: coordinator.selectedOnboardingProvider.defaultModel
        )
    }

    func activateCleanTranscriptionMode() {
        guard let cleanTemplate = StarterModeCatalog.templates.first(where: { $0.kind == .clean }),
              let cleanConfig = ModeManager.shared.getConfiguration(with: cleanTemplate.id) else {
            return
        }

        ModeManager.shared.setAsDefault(configId: cleanConfig.id)
        ModeManager.shared.setActiveConfiguration(cleanConfig)
    }
}
