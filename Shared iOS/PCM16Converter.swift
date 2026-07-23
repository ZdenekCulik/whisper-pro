import Foundation
import AVFoundation

/// Converts microphone buffers to the exact format Soniox expects:
/// 16 kHz, mono, signed 16-bit little-endian PCM (pcm_s16le).
final class PCM16Converter {
    static let targetSampleRate: Double = 16000

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init?(inputFormat: AVAudioFormat) {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: true
        ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }
        self.outputFormat = outputFormat
        self.converter = converter
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> Data? {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        guard error == nil, output.frameLength > 0,
              let channelData = output.int16ChannelData else { return nil }

        return Data(bytes: channelData[0], count: Int(output.frameLength) * MemoryLayout<Int16>.size)
    }
}
