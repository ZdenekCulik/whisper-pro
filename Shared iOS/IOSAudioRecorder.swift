import Foundation
import AVFoundation

/// iOS counterpart of the macOS CoreAudioRecorder. Emits the same chunk format
/// (16 kHz mono Int16 PCM) so the shared Soniox client can consume it unchanged.
final class IOSAudioRecorder {
    enum RecorderError: Error {
        case permissionDenied
        case engineFailed(String)
    }

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
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            throw RecorderError.engineFailed(error.localizedDescription)
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
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
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailed(error.localizedDescription)
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
