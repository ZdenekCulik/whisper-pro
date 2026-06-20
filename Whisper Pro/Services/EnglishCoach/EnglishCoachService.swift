import Foundation
import SwiftData
import NaturalLanguage
import LLMkit
import os

/// A single coaching suggestion, as a value type the recorder widget can show
/// without touching SwiftData on the UI thread.
struct CoachSuggestion: Equatable, Identifiable {
    let id: UUID
    let dictationId: UUID
    let said: String
    let corrected: String
    let why: String
}

/// Ambient English coach: after each English dictation it picks ONE useful
/// correction, saves it, and publishes it so the recorder can show a small card.
/// Decoupled from the pipeline — it just listens for `.transcriptionCompleted`.
@MainActor
final class EnglishCoachService: ObservableObject {
    static let shared = EnglishCoachService()

    /// The newest correction, for the recorder widget to morph into a card.
    @Published var latestSuggestion: CoachSuggestion?

    private weak var aiService: AIService?
    private var container: ModelContainer?
    private var observer: NSObjectProtocol?
    private var didShowMissingProviderWarning = false
    private var activeDictationId: UUID?
    #if LOCAL_BUILD
    private var localSmokeTestTimer: Timer?
    #endif

    private let logger = Logger(subsystem: "com.prakashjoshipax.whisperpro", category: "EnglishCoach")
    private let minWordCount = 4

    private init() {}

    /// Wire up the coach once at app start, where the shared AIService + container exist.
    func configure(aiService: AIService, container: ModelContainer) {
        self.aiService = aiService
        self.container = container
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .transcriptionCompleted,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let transcription = note.object as? Transcription else { return }
            // Hop to the main actor to read the @Model and kick off analysis.
            Task { @MainActor in self?.handleCompleted(transcription) }
        }

        // Toggling the recorder clears the shared "latest" value so embedded recorder
        // UIs can reset, while the floating card keeps its own auto-dismiss timer.
        NotificationCenter.default.addObserver(
            forName: .toggleRecorderPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.activeDictationId = nil
                self?.latestSuggestion = nil
            }
        }

        #if LOCAL_BUILD
        startLocalSmokeTestWatcher()
        #endif
    }

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "englishCoachEnabled")
    }

    private var nativeLanguage: String {
        UserDefaults.standard.string(forKey: "englishCoachNativeLanguage") ?? "cs"
    }

    private func handleCompleted(_ transcription: Transcription) {
        let status = transcription.transcriptionStatus ?? "nil"
        let text = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        let lang = detectedLanguage(text)
        activeDictationId = transcription.id

        guard isEnabled else { return }
        guard status == TranscriptionStatus.completed.rawValue else { return }

        // Coach on what the user actually SAID (raw transcript), not the AI-polished rewrite.
        guard text != Transcription.canceledTranscriptionText else { return }
        guard words >= minWordCount else { return }
        guard lang == "en" else { return }
        // Don't gate on the AIService.isAPIKeyValid flag (it tracks the enhancement
        // UI state and can be false even when a usable key exists). Just attempt the
        // call — completeChat throws cleanly if no key is configured, and we log it.
        guard let aiService else { return }
        guard let provider = resolvedProvider(using: aiService) else {
            showMissingProviderWarningIfNeeded()
            return
        }

        let dictationId = transcription.id
        activeDictationId = dictationId
        Task { [weak self] in
            await self?.analyze(text: text, dictationId: dictationId, aiService: aiService, provider: provider)
        }
    }

    private func detectedLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "unknown"
    }

    private func analyze(text: String, dictationId: UUID, aiService: AIService, provider: AIProvider) async {
        let system = Self.systemPrompt(nativeLanguage: languageName(for: nativeLanguage))
        do {
            let raw = try await aiService.completeChat(
                provider: provider,
                modelName: nil,
                messages: [ChatMessage.user(text)],
                systemPrompt: system,
                timeout: 10
            )
            guard let parsed = Self.parse(raw) else {
                logger.info("English Coach returned no suggestion using \(provider.rawValue, privacy: .public)")
                return
            }
            logger.info("English Coach prepared suggestion using \(provider.rawValue, privacy: .public)")
            await MainActor.run {
                // The user may have turned the coach off while the AI was thinking —
                // honor that and don't save/show a correction they opted out of.
                guard self.isEnabled else { return }
                guard self.activeDictationId == dictationId else { return }
                self.persistAndPublish(parsed, dictationId: dictationId)
            }
        } catch EnhancementError.notConfigured {
            logger.error("English Coach AI provider is not configured")
            showMissingProviderWarningIfNeeded()
        } catch {
            logger.error("English Coach AI failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resolvedProvider(using aiService: AIService) -> AIProvider? {
        let connectedProviders = aiService.connectedProviders
        if connectedProviders.contains(aiService.selectedProvider) {
            return aiService.selectedProvider
        }

        return Self.fallbackProviderPriority.first { connectedProviders.contains($0) }
    }

    private static let fallbackProviderPriority: [AIProvider] = [
        .openAI,
        .anthropic,
        .gemini,
        .groq,
        .openRouter,
        .mistral,
        .cerebras,
        .custom,
        .ollama,
        .localCLI
    ]

    private func showMissingProviderWarningIfNeeded() {
        guard !didShowMissingProviderWarning else { return }
        didShowMissingProviderWarning = true

        NotificationManager.shared.showNotification(
            title: String(localized: "English Coach needs an AI provider. Add a key in AI Models."),
            type: .warning,
            duration: 7.0,
            actionButton: (String(localized: "AI Models"), Self.openAIModels)
        )
    }

    private static func openAIModels() {
        _ = WindowManager.shared.showMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .navigateToDestination,
                object: nil,
                userInfo: ["destination": "AI Models"]
            )
        }
    }

    private func persistAndPublish(_ parsed: (said: String, corrected: String, why: String), dictationId: UUID) {
        let note = CoachNote(
            dictationId: dictationId,
            said: parsed.said,
            corrected: parsed.corrected,
            why: parsed.why,
            language: "en"
        )
        if let context = container?.mainContext {
            context.insert(note)
            try? context.save()
        }

        let suggestion = CoachSuggestion(
            id: note.id,
            dictationId: dictationId,
            said: parsed.said,
            corrected: parsed.corrected,
            why: parsed.why
        )
        latestSuggestion = suggestion
        NotificationCenter.default.post(name: .englishCoachCorrectionReady, object: suggestion)
        logger.info("English Coach published suggestion card")
    }

    /// Clear the card (called when the user dismisses it or starts a new dictation).
    func clearSuggestion() {
        latestSuggestion = nil
    }

    #if LOCAL_BUILD
    private func startLocalSmokeTestWatcher() {
        guard localSmokeTestTimer == nil else { return }
        localSmokeTestTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.runLocalSmokeTestIfRequested()
            }
        }
    }

    /// Local-build smoke test hook. Set `englishCoachLocalSmokeTestText` before launch
    /// or while the app is running to run one synthetic completed dictation through the real coach path.
    func runLocalSmokeTestIfRequested() {
        let key = "englishCoachLocalSmokeTestText"
        let text = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }

        UserDefaults.standard.removeObject(forKey: key)
        logger.info("English Coach local smoke test requested")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let transcription = Transcription(
                text: text,
                duration: 1,
                transcriptionStatus: .completed
            )
            self.handleCompleted(transcription)
        }
    }
    #endif

    // MARK: - Prompt & parsing

    private static func systemPrompt(nativeLanguage: String) -> String {
        """
        You are a friendly English coach for a native \(nativeLanguage) speaker who dictates in English all day.
        Given their dictated text, find the SINGLE most useful thing they can learn from — a word, phrase, \
        idiom, collocation, false friend, phrasal verb, or register choice that sounds wrong or unnatural to a native English ear. \
        Pick the one fix with the highest learning value. Ignore punctuation, capitalization, and filler words.
        Preserve the speaker's intended meaning. For example, if they ask someone to "borrow me" something, correct it to "lend me" something.
        Do not suggest spelling, tense, plural, or other inflection-only fixes.
        If the English already sounds natural, answer NO.

        Reply in EXACTLY this format and nothing else:
        SUGGESTION: YES or NO
        SAID: <the minimal phrase they said, a few words>
        CORRECTED: <the natural version of that same phrase>
        WHY: <max 12 words, simple, why the corrected version is more natural>

        Keep SAID and CORRECTED to the minimal differing phrase, never the whole sentence.
        """
    }

    /// Parse the line-based reply leniently (survives the output filter).
    static func parse(_ raw: String) -> (said: String, corrected: String, why: String)? {
        var suggestion = false
        var said = ""
        var corrected = ""
        var why = ""
        for line in raw.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let v = value(trimmed, "SUGGESTION") { suggestion = v.uppercased().hasPrefix("Y") }
            else if let v = value(trimmed, "SAID") { said = v }
            else if let v = value(trimmed, "CORRECTED") { corrected = v }
            else if let v = value(trimmed, "WHY") { why = v }
        }
        guard suggestion else { return nil }
        said = said.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        corrected = corrected.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        why = why.trimmingCharacters(in: .whitespaces)
        guard !said.isEmpty, !corrected.isEmpty,
              said.lowercased() != corrected.lowercased() else { return nil }
        return (said, corrected, why)
    }

    private static func value(_ line: String, _ key: String) -> String? {
        guard line.uppercased().hasPrefix(key + ":") else { return nil }
        return String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
    }

    private func languageName(for code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "Czech"
    }
}
