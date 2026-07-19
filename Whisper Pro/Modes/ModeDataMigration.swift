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

    /// Safety net for the rare case where no mode configuration exists at all (e.g. a state
    /// before onboarding's StarterModeFactory has run). Real onboarded users already have a
    /// "Dictation" default mode from StarterModeFactory, so this normally never fires.
    func ensureDefaultConfigurationExists() {
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
    /// (see ModeRuntimeResolver), so this only needs to: (1) copy whatever model the current
    /// default/active mode was pinned to into the global "CurrentTranscriptionModel" key, so
    /// existing dictation behavior doesn't change the moment this ships, then (2) clear the
    /// mode's own pin so the global setting drives it from now on. Every other field of the
    /// mode (AI enhancement config, output mode, isRealtimeTranscriptionEnabled, etc.) is left
    /// untouched. Guarded by a UserDefaults flag so it only ever runs once.
    func migrateToGlobalTranscriptionDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "hasMigratedModeToGlobalDefaultsV1"
        guard !defaults.bool(forKey: migrationKey) else { return }
        defaults.set(true, forKey: migrationKey)

        guard var mode = currentEffectiveConfiguration,
              let pinnedModelName = mode.selectedTranscriptionModelName else { return }

        defaults.set(pinnedModelName, forKey: "CurrentTranscriptionModel")
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
