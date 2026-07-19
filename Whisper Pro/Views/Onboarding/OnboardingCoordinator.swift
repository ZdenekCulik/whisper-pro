import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published var storedStage: String {
        didSet {
            defaults.set(storedStage, forKey: OnboardingStorageKeys.stage)
        }
    }

    @Published var storedActivePermission: String {
        didSet {
            defaults.set(storedActivePermission, forKey: OnboardingStorageKeys.activePermission)
        }
    }

    @Published var hasRequestedScreenRecording: Bool {
        didSet {
            defaults.set(hasRequestedScreenRecording, forKey: OnboardingStorageKeys.requestedScreenRecording)
        }
    }

    @Published var storedOnboardingAIProvider: String {
        didSet {
            defaults.set(storedOnboardingAIProvider, forKey: OnboardingStorageKeys.aiProvider)
        }
    }

    @Published var hasSkippedAPISetup: Bool {
        didSet {
            defaults.set(hasSkippedAPISetup, forKey: OnboardingStorageKeys.skippedAPISetup)
        }
    }

    @Published var hasSkippedSonioxSetup: Bool {
        didSet {
            defaults.set(hasSkippedSonioxSetup, forKey: OnboardingStorageKeys.skippedSonioxSetup)
        }
    }

    @Published var permissionStatuses: [OnboardingPermissionKind: OnboardingPermissionStatus] = [:]
    @Published var isSelectedAPIProviderVerified = false
    @Published var isShowingSkipAPISetupWarning = false

    let defaults: UserDefaults
    var refreshTask: Task<Void, Never>?
    lazy var flow = OnboardingFlowController(coordinator: self)
    lazy var permissions = OnboardingPermissionController(coordinator: self)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storedStage = defaults.string(forKey: OnboardingStorageKeys.stage) ?? OnboardingStage.permissions.rawValue
        self.storedActivePermission = defaults.string(forKey: OnboardingStorageKeys.activePermission) ?? OnboardingPermissionKind.microphone.rawValue
        self.hasRequestedScreenRecording = defaults.bool(forKey: OnboardingStorageKeys.requestedScreenRecording)
        self.storedOnboardingAIProvider = defaults.string(forKey: OnboardingStorageKeys.aiProvider) ?? AIProvider.groq.rawValue
        self.hasSkippedAPISetup = defaults.bool(forKey: OnboardingStorageKeys.skippedAPISetup)
        self.hasSkippedSonioxSetup = defaults.bool(forKey: OnboardingStorageKeys.skippedSonioxSetup)
    }

    deinit {
        refreshTask?.cancel()
    }

    var stage: OnboardingStage {
        if let stage = OnboardingStage(rawValue: storedStage) {
            return stage
        }

        // Legacy/removed stage raw values from older builds: route them to the closest
        // stage that still exists in the current sequence so a mid-flight upgrade can't
        // strand the user on dead UI or skip mode installation.
        switch storedStage {
        case "starterMode", "shortcut", "experience", "contextAwareness", "parakeet":
            return .model
        case "license":
            return .trust
        default:
            return .permissions
        }
    }

    var activePermission: OnboardingPermissionKind {
        OnboardingPermissionKind(rawValue: storedActivePermission) ?? .microphone
    }

    var requiredPermissionsGranted: Bool {
        OnboardingPermissionKind.required.allSatisfy { permissions.status(for: $0).isGranted }
    }

    var hasSelectedOnboardingMicrophone: Bool {
        defaults.audioInputModeRawValue == AudioInputMode.custom.rawValue &&
            defaults.selectedAudioDeviceUID != nil
    }

    var hasSonioxAPIKey: Bool {
        APIKeyManager.shared.hasAPIKey(forProvider: CloudProviderRegistry.provider(for: .soniox)?.providerKey ?? "Soniox")
    }

    var currentStepNumber: Int {
        if stage == .trust {
            return OnboardingStage.baseStepCount + 1
        }

        return stage.stepNumber
    }

    var totalStepCount: Int {
        OnboardingStage.baseStepCount + 1
    }

    var onboardingProviderOptions: [AIProvider] {
        let preferredOrder: [AIProvider] = [
            .groq,
            .cerebras,
            .gemini,
            .openAI,
            .openRouter,
            .anthropic,
            .mistral
        ]

        let supportedProviders = AIProvider.allCases.filter { provider in
            provider.supportsEnhancement &&
                provider.requiresAPIKey &&
                provider != .custom
        }

        return supportedProviders.sorted { first, second in
            let firstIndex = preferredOrder.firstIndex(of: first) ?? Int.max
            let secondIndex = preferredOrder.firstIndex(of: second) ?? Int.max

            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }

            return first.rawValue < second.rawValue
        }
    }

    var selectedOnboardingProvider: AIProvider {
        if let storedProvider = AIProvider(rawValue: storedOnboardingAIProvider),
           onboardingProviderOptions.contains(storedProvider) {
            return storedProvider
        }

        if onboardingProviderOptions.contains(.groq) {
            return .groq
        }

        return onboardingProviderOptions.first ?? .groq
    }

    var requiredTranscriptionModel: FluidAudioModel? {
        TranscriptionModelRegistry.models
            .compactMap { $0 as? FluidAudioModel }
            .first { $0.name == "parakeet-tdt-0.6b-v3" }
    }

    func selectedOnboardingProviderBinding(aiService: AIService) -> Binding<AIProvider> {
        Binding(
            get: { [weak self] in
                self?.selectedOnboardingProvider ?? .groq
            },
            set: { [weak self] provider in
                self?.flow.selectOnboardingProvider(provider, aiService: aiService)
            }
        )
    }

    func isTranscriptionModelDownloaded(using modelManager: FluidAudioModelManager) -> Bool {
        guard let requiredTranscriptionModel else { return false }
        return modelManager.isFluidAudioModelDownloaded(requiredTranscriptionModel)
    }

    func isReadyForExperience(isTranscriptionModelDownloaded: Bool) -> Bool {
        requiredPermissionsGranted &&
            hasSelectedOnboardingMicrophone &&
            (hasSonioxAPIKey || hasSkippedSonioxSetup)
    }
}

enum OnboardingStorageKeys {
    static let stage = "onboardingStage"
    static let activePermission = "onboardingActivePermission"
    static let requestedScreenRecording = "onboardingRequestedScreenRecording"
    static let experienceIndex = "onboardingExperienceIndex"
    static let aiProvider = "onboardingAIProvider"
    static let skippedAPISetup = "onboardingSkippedAPISetup"
    static let skippedSonioxSetup = "onboardingSkippedSonioxSetup"

    static let onboardingKeys = [
        stage,
        activePermission,
        requestedScreenRecording,
        aiProvider,
        skippedAPISetup,
        skippedSonioxSetup,
        experienceIndex,
        "onboardingStarterModeIndex"
    ]
}
