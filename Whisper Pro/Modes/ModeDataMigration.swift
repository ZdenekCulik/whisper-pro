import Foundation

extension ModeManager {
    func migratedModeConfigurationData(for configKey: String) -> Data? {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: configKey) {
            return data
        }

        guard let legacyData = defaults.data(forKey: LegacyModeDataKey.configurations) else {
            return nil
        }

        defaults.set(legacyData, forKey: configKey)
        return legacyData
    }

    func migrateLoadedModeConfigurationsIfNeeded() {
        var didChange = false

        for index in configurations.indices {
            var config = configurations[index]
            var changedConfig = false

            if config.selectedAIProvider == nil {
                config.selectedAIProvider = UserDefaults.standard.string(forKey: "selectedAIProvider")
                changedConfig = true
            }

            if config.selectedAIModel == nil,
               let provider = config.selectedAIProvider {
                config.selectedAIModel = UserDefaults.standard.string(forKey: "\(provider)SelectedModel")
                changedConfig = true
            }

            if config.isAIEnhancementEnabled && config.selectedPrompt == nil {
                config.selectedPrompt = UserDefaults.standard.string(forKey: "selectedPromptId")
                changedConfig = true
            }

            if changedConfig {
                configurations[index] = config
                didChange = true
            }
        }

        if didChange {
            saveConfigurations()
        }

        migrateLegacyShortcutStorageIfNeeded()
    }

    /// Safety net for onboarded users who somehow ended up with no mode configuration at all
    /// (e.g. a corrupted defaults write). Gated on onboarding having completed: on a fresh
    /// install this must NOT run, because it fires in ModeManager's init — before onboarding's
    /// StarterModeFactory has created the real starter modes — and would otherwise leave a
    /// synthetic "Dictation" mode with a random UUID installed permanently. Runtime resolvers
    /// already fall back to the global transcription defaults when no mode exists, so a fresh
    /// install is fine without this until onboarding runs.
    func ensureDefaultConfigurationExists() {
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboardingV2") else { return }
        guard configurations.isEmpty else { return }

        let dictationMode = ModeConfig(
            name: "Dictation",
            isAIEnhancementEnabled: false,
            selectedTranscriptionModelName: "stt-async-v5",
            isRealtimeTranscriptionEnabled: true,
            useClipboardContext: false,
            useSelectedTextContext: true,
            useScreenCapture: false,
            outputMode: .paste,
            isEnabled: true,
            isDefault: true
        )

        configurations = [dictationMode]
        saveConfigurations()
    }

    /// One-time migration: with the Modes UI hidden, the global AI Models tab / Settings
    /// language chips must become authoritative. The runtime resolver already falls back to
    /// those globals whenever a mode's selectedTranscriptionModelName/selectedLanguage are nil
    /// (see ModeRuntimeResolver), so this only needs to: (1) copy whatever model/language the
    /// current default/active mode was pinned to into the global "CurrentTranscriptionModel" /
    /// "SelectedLanguage" keys, so existing dictation behavior doesn't change the moment this
    /// ships, then (2) clear the mode's own pins so the global settings drive them from now on.
    /// Every other field of the mode (AI enhancement config, output mode,
    /// isRealtimeTranscriptionEnabled, etc.) is left untouched. Guarded by a UserDefaults flag
    /// so it only ever runs once, and only for users who already completed onboarding — on a
    /// fresh install this fires before onboarding's StarterModeFactory has created any real
    /// modes, so there's nothing meaningful to migrate yet.
    func migrateToGlobalTranscriptionDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "hasCompletedOnboardingV2") else { return }

        let migrationKey = "hasMigratedModeToGlobalDefaultsV1"
        guard !defaults.bool(forKey: migrationKey) else { return }
        defaults.set(true, forKey: migrationKey)

        guard var mode = currentEffectiveConfiguration,
              let pinnedModelName = mode.selectedTranscriptionModelName else { return }

        defaults.set(pinnedModelName, forKey: "CurrentTranscriptionModel")
        if let pinnedLanguage = mode.selectedLanguage {
            defaults.set(pinnedLanguage, forKey: "SelectedLanguage")
        }
        mode.selectedTranscriptionModelName = nil
        mode.selectedLanguage = nil
        updateConfiguration(mode)

        if activeConfiguration?.id == mode.id {
            activeConfiguration = mode
        }
    }

    private func migrateLegacyShortcutStorageIfNeeded() {
        let defaults = UserDefaults.standard

        for config in configurations {
            let oldShortcutKey = "\(LegacyModeDataKey.shortcutPrefix)\(config.id.uuidString)"
            let newShortcutKey = ShortcutAction.mode(config.id).userDefaultsKey

            if defaults.object(forKey: newShortcutKey) == nil,
               let oldShortcutData = defaults.data(forKey: oldShortcutKey) {
                defaults.set(oldShortcutData, forKey: newShortcutKey)
            }

            let oldClearedKey = "\(oldShortcutKey)_cleared"
            let newClearedKey = "\(newShortcutKey)_cleared"
            if defaults.object(forKey: newClearedKey) == nil,
               defaults.object(forKey: oldClearedKey) != nil {
                defaults.set(defaults.bool(forKey: oldClearedKey), forKey: newClearedKey)
            }
        }
    }
}

private enum LegacyModeDataKey {
    static let configurations = "powerModeConfigurationsV2"
    static let shortcutPrefix = "Shortcut_powerMode_"
}
