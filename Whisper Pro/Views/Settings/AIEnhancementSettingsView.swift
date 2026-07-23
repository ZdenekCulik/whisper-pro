import SwiftUI

/// Settings rows for AI Enhancement (toggle + prompt picker) for the current mode.
struct AIEnhancementSettingsView: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @ObservedObject private var modeManager = ModeManager.shared

    private var currentMode: ModeConfig? {
        modeManager.currentEffectiveConfiguration
    }

    private var isEnabled: Bool {
        currentMode?.isAIEnhancementEnabled == true
    }

    private var runtimeConfiguration: EnhancementRuntimeConfiguration {
        ModeRuntimeResolver.currentEnhancementConfiguration(
            mode: currentMode,
            enhancementService: enhancementService,
            aiService: aiService
        )
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { newValue in
                modeManager.updateCurrentEffectiveConfiguration { config in
                    config.isAIEnhancementEnabled = newValue
                }
                if newValue {
                    enhancementService.repairModePromptSelections()
                }
            }
        )) {
            Text("AI Enhancement")
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .disabled(enhancementService.allPrompts.isEmpty)

        if isEnabled {
            if runtimeConfiguration.prompt == nil {
                Text("No prompt available. Add one below to use AI Enhancement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Prompt", selection: Binding(
                get: { currentMode?.selectedPrompt.flatMap(UUID.init) },
                set: { newValue in
                    modeManager.updateCurrentEffectiveConfiguration { config in
                        config.selectedPrompt = newValue?.uuidString
                    }
                }
            )) {
                ForEach(enhancementService.allPrompts) { prompt in
                    Text(prompt.title).tag(Optional(prompt.id))
                }
            }
            .pickerStyle(.menu)

            if let provider = runtimeConfiguration.provider, !modelOptions.isEmpty {
                Picker("Model", selection: Binding(
                    get: { runtimeConfiguration.modelName ?? modelOptions.first ?? "" },
                    set: { newValue in
                        modeManager.updateCurrentEffectiveConfiguration { config in
                            config.selectedAIModel = newValue
                        }
                    }
                )) {
                    ForEach(modelOptions, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            } else {
                LabeledContent("Using") {
                    Text(providerModelText)
                        .foregroundStyle(.secondary)
                }
            }

            if let provider = runtimeConfiguration.provider, !hasAPIKey(for: provider) {
                Text("This provider has no API key yet. Add one in AI Models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var providerModelText: String {
        guard let provider = runtimeConfiguration.provider else { return "Not configured" }
        return "\(provider.rawValue) / \(runtimeConfiguration.modelName ?? "-")"
    }

    private var modelOptions: [String] {
        guard let provider = runtimeConfiguration.provider, provider != .localCLI else { return [] }
        return aiService.availableModels(for: provider)
    }

    private func hasAPIKey(for provider: AIProvider) -> Bool {
        if provider == .localCLI || provider == .ollama || provider == .custom { return true }
        return APIKeyManager.shared.hasAPIKey(forProvider: provider.rawValue)
    }
}
