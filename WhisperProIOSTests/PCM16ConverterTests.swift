import XCTest
import AVFoundation
@testable import Whisper_Pro_iOS

final class PCM16ConverterTests: XCTestCase {
    private func makeSineBuffer(sampleRate: Double, seconds: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frames) {
            samples[frame] = Float(sin(2.0 * .pi * 440.0 * Double(frame) / sampleRate))
        }
        return buffer
    }

    func testConvertsFortyEightKilohertzToSixteenKilohertzByteCount() throws {
        let converter = try XCTUnwrap(PCM16Converter(
            inputFormat: AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        ))
        let data = try XCTUnwrap(converter.convert(makeSineBuffer(sampleRate: 48000, seconds: 1.0)))
        // 1 second at 16 kHz mono Int16 is 32000 bytes; resampling has a small edge tolerance.
        XCTAssertEqual(Double(data.count), 32000, accuracy: 2000)
    }

    func testOutputByteCountIsEven() throws {
        let converter = try XCTUnwrap(PCM16Converter(
            inputFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        ))
        let data = try XCTUnwrap(converter.convert(makeSineBuffer(sampleRate: 44100, seconds: 0.5)))
        XCTAssertEqual(data.count % 2, 0, "Int16 samples must not be split")
    }

    func testSilenceConvertsToZeroSamples() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
        buffer.frameLength = 4800
        let converter = try XCTUnwrap(PCM16Converter(inputFormat: format))
        let data = try XCTUnwrap(converter.convert(buffer))
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(data.allSatisfy { $0 == 0 })
    }
}
