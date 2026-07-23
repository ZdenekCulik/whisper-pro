import Foundation
import LLMkit

/// Owns one dictation run: microphone -> Soniox -> published transcript.
/// The iOS counterpart of the macOS StreamingTranscriptionService, without
/// SwiftData, history or local models.
@MainActor
final class DictationSession: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case listening
        case failed(String)
    }

    static let missingKeyMessage = "Add your Soniox API key in the Whisper Pro app."

    @Published private(set) var partialText = ""
    @Published private(set) var committedText = ""
    @Published private(set) var state: State = .idle

    private let recorder = IOSAudioRecorder()
    private let client = SonioxRealtimeClient()
    private let apiKeyProvider: () -> String?
    private var eventsTask: Task<Void, Never>?

    init(apiKeyProvider: @escaping () -> String? = { SharedKeychain.get(forKey: SharedKeychain.sonioxKey) }) {
        self.apiKeyProvider = apiKeyProvider
    }

    func start() async {
        guard state == .idle || isFailed else { return }

        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            state = .failed(Self.missingKeyMessage)
            return
        }

        guard await IOSAudioRecorder.requestPermission() else {
            state = .failed("Microphone access is off. Enable it in Settings.")
            return
        }

        state = .connecting
        partialText = ""
        committedText = ""

        listenForEvents()

        do {
            try await client.connect(apiKey: apiKey, model: "stt-rt-v5", language: nil)
            recorder.onAudioChunk = { [weak self] data in
                Task { try? await self?.client.sendAudioChunk(data) }
            }
            try recorder.start()
            state = .listening
        } catch {
            state = .failed(error.localizedDescription)
            await stop()
        }
    }

    func stop() async {
        recorder.onAudioChunk = nil
        recorder.stop()
        try? await client.commit()
        await client.disconnect()
        eventsTask?.cancel()
        eventsTask = nil
        if state == .listening || state == .connecting {
            state = .idle
        }
    }

    /// Applies one Soniox event. Internal so tests can drive it directly.
    func apply(_ event: StreamingTranscriptionEvent) {
        switch event {
        case .sessionStarted:
            state = .listening
        case .partial(let text):
            partialText = text
        case .committed(let text):
            committedText = text
            partialText = ""
        case .error(let message):
            state = .failed(message)
        }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private func listenForEvents() {
        eventsTask?.cancel()
        let stream = client.transcriptionEvents
        eventsTask = Task { [weak self] in
            for await event in stream {
                await MainActor.run { self?.apply(event) }
            }
        }
    }
}
