import Foundation
import AVFoundation
import os.log

/// iOS counterpart of the macOS CoreAudioRecorder. Emits the same chunk format
/// (16 kHz mono Int16 PCM) so the shared Soniox client can consume it unchanged.
final class IOSAudioRecorder {
    enum RecorderError: Error, LocalizedError {
        case permissionDenied
        case engineFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone access is off. Enable it in Settings."
            case .engineFailed(let detail):
                return "Recording failed to start: \(detail)"
            }
        }
    }

    private static let log = Logger(subsystem: "com.prakashjoshipax.WhisperPro.keyboard", category: "IOSAudioRecorder")

    var onAudioChunk: ((Data) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: PCM16Converter?
    private(set) var isRecording = false

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        guard !isRecording else { return }

        do {
            // `.playAndRecord` (not `.record`) because `.duckOthers` is only a valid
            // option with categories that include playback - combining it with
            // `.record` makes setCategory throw, which is what surfaced as the
            // opaque "RecorderError error 0" in the keyboard extension. `.default`
            // mode (not `.measurement`) is the safer choice inside an extension.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .allowBluetooth])
            try session.setActive(true, options: [])
            Self.log.debug("audio session active: category=\(session.category.rawValue, privacy: .public) sampleRate=\(session.sampleRate) inputChannels=\(session.inputNumberOfChannels)")
        } catch {
            Self.log.error("audio session setup failed: \(error.localizedDescription, privacy: .public)")
            throw RecorderError.engineFailed("audio session: \(error.localizedDescription)")
        }

        // Must be queried after the session is active/configured above, otherwise the
        // hardware format can come back invalid (0 Hz / 0 channels).
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        Self.log.debug("input format: \(inputFormat.description, privacy: .public)")
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            Self.log.error("invalid input format: sampleRate=\(inputFormat.sampleRate) channels=\(inputFormat.channelCount)")
            throw RecorderError.engineFailed("microphone hardware format is unavailable (\(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) ch)")
        }
        guard let converter = PCM16Converter(inputFormat: inputFormat) else {
            throw RecorderError.engineFailed("unsupported input format \(inputFormat)")
        }
        self.converter = converter

        // 1600 frames at the hardware rate is roughly 100 ms, matching the macOS chunk cadence.
        input.installTap(onBus: 0, bufferSize: 1600, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let data = self.converter?.convert(buffer), !data.isEmpty else { return }
            self.onAudioChunk?(data)
        }

        do {
            engine.prepare()
            try engine.start()
            Self.log.debug("engine started")
        } catch {
            Self.log.error("engine.start() failed: \(error.localizedDescription, privacy: .public)")
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailed("engine start: \(error.localizedDescription)")
        }

        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
