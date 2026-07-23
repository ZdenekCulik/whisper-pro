# iOS Keyboard Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an iOS dictation keyboard to Whisper Pro that streams microphone audio to Soniox and inserts the live transcript into whatever text field the user is typing in.

**Architecture:** Two new targets inside the existing `Whisper Pro.xcodeproj`: a minimal iOS container app (API key entry + setup instructions) and a keyboard extension containing only a dictation panel (no QWERTY). Both share an App Group and a Keychain access group. The existing `SonioxRealtimeClient.swift` is added to the iOS targets by target membership (shared, never copied); audio capture and text insertion are new iOS-only code.

**Tech Stack:** Swift, SwiftUI, AVFoundation (AVAudioEngine + AVAudioConverter), UIKit (UIInputViewController, UITextDocumentProxy), Security (Keychain), LLMkit SPM package (already supports iOS 17), XCTest.

## Global Constraints

- Xcode project is edited directly (no XcodeGen/Tuist). `Whisper Pro.xcodeproj`, configurations Debug/Release, CODE_SIGN_STYLE = Automatic.
- DEVELOPMENT_TEAM: `A6D3VFTJYT`.
- Existing macOS target `Whisper Pro`, bundle ID `com.prakashjoshipax.WhisperPro`, MACOSX_DEPLOYMENT_TARGET 14.4. It MUST keep building unchanged.
- New iOS targets: IPHONEOS_DEPLOYMENT_TARGET = `17.0` (LLMkit declares `.iOS(.v17)`).
- App Group: `group.com.prakashjoshipax.WhisperPro`.
- Keychain access group: `$(AppIdentifierPrefix)com.prakashjoshipax.WhisperPro.shared`.
- New iOS source files live in new top-level folders `Whisper Pro iOS/`, `Whisper Pro Keyboard/`, `Shared iOS/` next to the existing `Whisper Pro/` folder. Never move or rename existing macOS files.
- macOS-only SPM packages (`AXSwift`, `KeySender`, `Sparkle`, `MediaRemoteAdapter`, `SelectedTextKit`, `LaunchAtLogin-Modern`) must NOT be linked into the iOS targets.
- UI copy: English, sentence case, no emoji, and never the U+2014 em dash character.
- After every task: the macOS build must still pass (`make build`).

---

### Task 0: Spike - prove the microphone works inside a keyboard extension

This is a throwaway proof. It is the single biggest risk in the project: if a keyboard extension cannot record on Zdenek's device, the rest of the plan is void. Nothing here is kept.

**Files:**
- Create (throwaway, deleted at end of task): a brand new Xcode project outside the repo at `/private/tmp/MicSpike/`

**Interfaces:**
- Consumes: nothing
- Produces: a yes/no answer recorded in this plan file, and the confirmed set of Info.plist keys / entitlements needed for extension microphone access

- [ ] **Step 1: Create a throwaway iOS app with a keyboard extension**

In Xcode: File > New > Project > iOS App, product name `MicSpike`, bundle ID `com.prakashjoshipax.micspike`, team `A6D3VFTJYT`, save to `/private/tmp/MicSpike/`. Then File > New > Target > Custom Keyboard Extension, product name `MicSpikeKeyboard`.

- [ ] **Step 2: Enable Full Access and microphone usage**

In `MicSpikeKeyboard/Info.plist`, under `NSExtension` > `NSExtensionAttributes`, set:

```xml
<key>RequestsOpenAccess</key>
<true/>
```

In the containing app's `Info.plist` add:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Whisper Pro records your voice to transcribe it.</string>
```

Add the same `NSMicrophoneUsageDescription` key to `MicSpikeKeyboard/Info.plist`.

- [ ] **Step 3: Record audio from the keyboard extension**

Replace `MicSpikeKeyboard/KeyboardViewController.swift` with:

```swift
import UIKit
import AVFoundation

class KeyboardViewController: UIInputViewController {
    private let engine = AVAudioEngine()
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "tap to record"
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(start)))
        view.addSubview(label)
    }

    @objc private func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async { self?.begin(granted: granted) }
        }
    }

    private func begin(granted: Bool) {
        guard granted else { label.text = "permission denied"; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            var frames = 0
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                frames += Int(buffer.frameLength)
                DispatchQueue.main.async { self?.label.text = "frames: \(frames)" }
            }
            try engine.start()
        } catch {
            label.text = "error: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 4: Run on the physical iPhone and verify**

Run the `MicSpike` scheme on Zdenek's connected iPhone. On the device: Settings > General > Keyboard > Keyboards > Add New Keyboard > MicSpike, then tap MicSpike and enable Allow Full Access. Open Notes, switch to the MicSpike keyboard with the globe key, tap the label.

Expected: the label counts frames upward while you speak.
If it shows `permission denied` or `error: ...`, STOP the project here and report the exact message to Zdenek before writing any production code.

- [ ] **Step 5: Record the result and clean up**

Append the verdict (works / does not work, plus the exact Info.plist keys and permission flow that were required) to the bottom of this plan file under a new heading `## Task 0 result`. Then delete the spike:

```bash
rm -rf /private/tmp/MicSpike
```

- [ ] **Step 6: Commit the recorded verdict**

```bash
git add docs/superpowers/plans/2026-07-23-ios-keyboard-extension.md
git commit -m "docs: record keyboard microphone spike result"
```

---

### Task 1: iOS app target, keyboard extension target, and shared Keychain

**Files:**
- Modify: `Whisper Pro.xcodeproj/project.pbxproj` (via Xcode UI, not by hand-editing)
- Create: `Whisper Pro iOS/WhisperProIOSApp.swift`
- Create: `Whisper Pro iOS/Info.plist`, `Whisper Pro iOS/WhisperProIOS.entitlements`
- Create: `Whisper Pro Keyboard/KeyboardViewController.swift`, `Whisper Pro Keyboard/Info.plist`, `Whisper Pro Keyboard/WhisperProKeyboard.entitlements`
- Create: `Shared iOS/SharedKeychain.swift`
- Test: `WhisperProIOSTests/SharedKeychainTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum SharedKeychain` with `static func save(_ value: String, forKey key: String) -> Bool`, `static func get(forKey key: String) -> String?`, `static let sonioxKey = "sonioxAPIKey"`
  - Target names `Whisper Pro iOS`, `Whisper Pro Keyboard`, test target `WhisperProIOSTests`

- [ ] **Step 1: Add the iOS app target**

In Xcode: File > New > Target > iOS > App. Product name `Whisper Pro iOS`, interface SwiftUI, language Swift, bundle ID `com.prakashjoshipax.WhisperPro`, team `A6D3VFTJYT`. Uncheck "Include Tests".

If Xcode or App Store Connect refuses `com.prakashjoshipax.WhisperPro` because the identifier is already registered for macOS only, use `com.prakashjoshipax.WhisperPro.ios` instead and use `com.prakashjoshipax.WhisperPro.ios.keyboard` in Step 2. Record which one was used in a comment at the top of `Whisper Pro iOS/WhisperProIOSApp.swift`.

Set IPHONEOS_DEPLOYMENT_TARGET to `17.0` in the new target's build settings. Move the generated files into a folder named `Whisper Pro iOS/` on disk and re-add them so the folder structure matches this plan.

- [ ] **Step 2: Add the keyboard extension target**

File > New > Target > iOS > Custom Keyboard Extension. Product name `Whisper Pro Keyboard`, embed in `Whisper Pro iOS`, bundle ID `com.prakashjoshipax.WhisperPro.keyboard`, deployment target `17.0`.

In `Whisper Pro Keyboard/Info.plist` set:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>IsASCIICapable</key>
        <false/>
        <key>PrefersRightToLeft</key>
        <false/>
        <key>PrimaryLanguage</key>
        <string>cs-CZ</string>
        <key>RequestsOpenAccess</key>
        <true/>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
</dict>
<key>NSMicrophoneUsageDescription</key>
<string>Whisper Pro records your voice to transcribe it.</string>
```

Add the same `NSMicrophoneUsageDescription` string to `Whisper Pro iOS/Info.plist`.

- [ ] **Step 3: Add App Group and Keychain sharing to both iOS targets**

For target `Whisper Pro iOS` and target `Whisper Pro Keyboard`, in Signing & Capabilities add:
- App Groups: `group.com.prakashjoshipax.WhisperPro`
- Keychain Sharing: group `com.prakashjoshipax.WhisperPro.shared`

Verify each entitlements file contains:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.prakashjoshipax.WhisperPro</string>
</array>
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.prakashjoshipax.WhisperPro.shared</string>
</array>
```

Do NOT touch `Whisper Pro/WhisperPro.entitlements`, `WhisperPro.local.entitlements` or `WhisperPro.dist.entitlements`.

- [ ] **Step 4: Add the iOS unit test target**

File > New > Target > iOS > Unit Testing Bundle, product name `WhisperProIOSTests`, target to be tested `Whisper Pro iOS`, deployment target `17.0`.

- [ ] **Step 5: Write the failing Keychain test**

Create `WhisperProIOSTests/SharedKeychainTests.swift`:

```swift
import XCTest
@testable import Whisper_Pro_iOS

final class SharedKeychainTests: XCTestCase {
    private let key = "unitTestKey"

    override func tearDown() {
        _ = SharedKeychain.save("", forKey: key)
        super.tearDown()
    }

    func testSaveThenGetReturnsSameValue() {
        XCTAssertTrue(SharedKeychain.save("abc123", forKey: key))
        XCTAssertEqual(SharedKeychain.get(forKey: key), "abc123")
    }

    func testOverwriteReplacesValue() {
        XCTAssertTrue(SharedKeychain.save("first", forKey: key))
        XCTAssertTrue(SharedKeychain.save("second", forKey: key))
        XCTAssertEqual(SharedKeychain.get(forKey: key), "second")
    }

    func testMissingKeyReturnsNil() {
        XCTAssertNil(SharedKeychain.get(forKey: "keyThatWasNeverSaved"))
    }
}
```

If Xcode generated a different module name than `Whisper_Pro_iOS`, use the value of PRODUCT_MODULE_NAME from the iOS app target's build settings in the `@testable import` line.

- [ ] **Step 6: Run the test to verify it fails**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/SharedKeychainTests`
Expected: FAIL, `cannot find 'SharedKeychain' in scope`.

- [ ] **Step 7: Implement SharedKeychain**

Create `Shared iOS/SharedKeychain.swift` and add it to BOTH the `Whisper Pro iOS` and `Whisper Pro Keyboard` targets (File inspector > Target Membership):

```swift
import Foundation
import Security

/// Keychain storage shared between the iOS app and the keyboard extension.
/// Deliberately separate from the macOS KeychainService so the Mac app is untouched.
enum SharedKeychain {
    static let sonioxKey = "sonioxAPIKey"

    private static let service = "com.prakashjoshipax.WhisperPro"
    private static let accessGroup = "A6D3VFTJYT.com.prakashjoshipax.WhisperPro.shared"

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        let query = baseQuery(forKey: key)
        SecItemDelete(query as CFDictionary)
        guard let data = value.data(using: .utf8) else { return false }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    static func get(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }
}
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/SharedKeychainTests`
Expected: PASS, 3 tests.

- [ ] **Step 9: Verify the macOS build still passes**

Run: `make build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 10: Commit**

```bash
git add "Whisper Pro.xcodeproj/project.pbxproj" "Whisper Pro iOS" "Whisper Pro Keyboard" "Shared iOS" WhisperProIOSTests
git commit -m "feat: add iOS app and keyboard extension targets with shared keychain"
```

---

### Task 2: Text diff helper for live partial insertion

The keyboard rewrites the partial transcript as it changes. Deleting and reinserting the whole partial on every update flickers and is slow, so compute the minimal edit. This is pure logic and fully unit-testable without a device.

**Files:**
- Create: `Shared iOS/TranscriptEdit.swift`
- Test: `WhisperProIOSTests/TranscriptEditTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `enum TranscriptEdit` with `static func edit(from current: String, to target: String) -> (deleteCount: Int, insert: String)` where `deleteCount` is the number of `deleteBackward()` calls to make and `insert` is the string to pass to `insertText`.

- [ ] **Step 1: Write the failing tests**

Create `WhisperProIOSTests/TranscriptEditTests.swift`:

```swift
import XCTest
@testable import Whisper_Pro_iOS

final class TranscriptEditTests: XCTestCase {
    func testAppendOnlyInsertsSuffix() {
        let edit = TranscriptEdit.edit(from: "ahoj", to: "ahoj sve")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, " sve")
    }

    func testRewrittenTailDeletesOnlyDivergentPart() {
        let edit = TranscriptEdit.edit(from: "ahoj sve", to: "ahoj svete")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, "te")
    }

    func testChangedWordDeletesBackToCommonPrefix() {
        let edit = TranscriptEdit.edit(from: "ahoj svete", to: "ahoj lidi")
        XCTAssertEqual(edit.deleteCount, 5)
        XCTAssertEqual(edit.insert, "lidi")
    }

    func testIdenticalTextProducesNoEdit() {
        let edit = TranscriptEdit.edit(from: "ahoj", to: "ahoj")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, "")
    }

    func testEmptyTargetDeletesEverything() {
        let edit = TranscriptEdit.edit(from: "ahoj", to: "")
        XCTAssertEqual(edit.deleteCount, 4)
        XCTAssertEqual(edit.insert, "")
    }

    func testAccentedCharactersCountAsSingleCharacters() {
        let edit = TranscriptEdit.edit(from: "prislo", to: "prislozitost")
        XCTAssertEqual(edit.deleteCount, 0)
        XCTAssertEqual(edit.insert, "zitost")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/TranscriptEditTests`
Expected: FAIL, `cannot find 'TranscriptEdit' in scope`.

- [ ] **Step 3: Implement TranscriptEdit**

Create `Shared iOS/TranscriptEdit.swift`, target membership: `Whisper Pro iOS` AND `Whisper Pro Keyboard`:

```swift
import Foundation

/// Computes the minimal edit needed to turn the text already inserted in the
/// text field into the newest transcript, so live updates do not flicker.
enum TranscriptEdit {
    static func edit(from current: String, to target: String) -> (deleteCount: Int, insert: String) {
        let currentChars = Array(current)
        let targetChars = Array(target)

        var shared = 0
        while shared < currentChars.count,
              shared < targetChars.count,
              currentChars[shared] == targetChars[shared] {
            shared += 1
        }

        return (
            deleteCount: currentChars.count - shared,
            insert: String(targetChars[shared...])
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/TranscriptEditTests`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add "Shared iOS/TranscriptEdit.swift" WhisperProIOSTests/TranscriptEditTests.swift
git commit -m "feat: add minimal transcript edit calculation for live insertion"
```

---

### Task 3: iOS audio capture producing Soniox-compatible PCM

The macOS `CoreAudioRecorder` is AUHAL based and cannot run on iOS. This task produces the same byte format it emits (16 kHz, mono, signed 16-bit little-endian PCM) using AVAudioEngine, so `SonioxRealtimeClient.sendAudioChunk(_:)` accepts the data unchanged.

**Files:**
- Create: `Shared iOS/IOSAudioRecorder.swift`
- Create: `Shared iOS/PCM16Converter.swift`
- Test: `WhisperProIOSTests/PCM16ConverterTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `final class PCM16Converter` with `init?(inputFormat: AVAudioFormat)` and `func convert(_ buffer: AVAudioPCMBuffer) -> Data?` returning 16 kHz mono Int16 little-endian bytes
  - `final class IOSAudioRecorder` with `var onAudioChunk: ((Data) -> Void)?`, `func start() throws`, `func stop()`, `static func requestPermission() async -> Bool`, and `enum RecorderError: Error { case permissionDenied, engineFailed(String) }`

- [ ] **Step 1: Write the failing converter tests**

Create `WhisperProIOSTests/PCM16ConverterTests.swift`:

```swift
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
            samples[frame] = sin(2.0 * .pi * 440.0 * Double(frame) / sampleRate).magnitude > 0 ?
                Float(sin(2.0 * .pi * 440.0 * Double(frame) / sampleRate)) : 0
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/PCM16ConverterTests`
Expected: FAIL, `cannot find 'PCM16Converter' in scope`.

- [ ] **Step 3: Implement PCM16Converter**

Create `Shared iOS/PCM16Converter.swift`, target membership: `Whisper Pro iOS` AND `Whisper Pro Keyboard`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/PCM16ConverterTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Implement IOSAudioRecorder**

Create `Shared iOS/IOSAudioRecorder.swift`, target membership: `Whisper Pro iOS` AND `Whisper Pro Keyboard`:

```swift
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
```

- [ ] **Step 6: Verify both builds**

Run: `xcodebuild build -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: `BUILD SUCCEEDED`.

Run: `make build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add "Shared iOS/PCM16Converter.swift" "Shared iOS/IOSAudioRecorder.swift" WhisperProIOSTests/PCM16ConverterTests.swift "Whisper Pro.xcodeproj/project.pbxproj"
git commit -m "feat: add iOS audio capture producing 16 kHz PCM chunks"
```

---

### Task 4: Dictation session wiring the recorder to the shared Soniox client

**Files:**
- Modify: `Whisper Pro.xcodeproj/project.pbxproj` (add target membership only, no source edits)
- Create: `Shared iOS/DictationSession.swift`
- Test: `WhisperProIOSTests/DictationSessionTests.swift`

**Interfaces:**
- Consumes:
  - `IOSAudioRecorder` (Task 3): `var onAudioChunk: ((Data) -> Void)?`, `func start() throws`, `func stop()`, `static func requestPermission() async -> Bool`
  - Existing shared file `Whisper Pro/Transcription/Streaming/SonioxRealtimeClient.swift`:
    - `init()`
    - `private(set) var transcriptionEvents: AsyncStream<LLMkit.StreamingTranscriptionEvent>`
    - `func connect(apiKey: String, model: String, language: String?, customVocabulary: [String] = []) async throws`
    - `func sendAudioChunk(_ data: Data) async throws`
    - `func commit() async throws`
    - `func disconnect() async`
    - events used: `.sessionStarted`, `.partial(text: String)`, `.committed(text: String)`, `.error(String)`
  - `SharedKeychain.get(forKey:)` and `SharedKeychain.sonioxKey` (Task 1)
- Produces: `@MainActor final class DictationSession: ObservableObject` with `@Published private(set) var partialText: String`, `@Published private(set) var committedText: String`, `@Published private(set) var state: State`, `enum State: Equatable { case idle, connecting, listening, failed(String) }`, `func start() async`, `func stop() async`

- [ ] **Step 1: Add the shared Soniox files to the iOS targets**

In Xcode, select `Whisper Pro/Transcription/Streaming/SonioxRealtimeClient.swift` and in the File inspector tick Target Membership for `Whisper Pro iOS` and `Whisper Pro Keyboard` (leave `Whisper Pro` ticked).

Do the same for `Whisper Pro/Services/UserDefaultsManager.swift`, which `SonioxRealtimeClient` needs for `UserDefaults.preferredLanguageHints`.

Link the LLMkit package product to both iOS targets: target > General > Frameworks and Libraries > + > LLMkit. Do NOT add `AXSwift`, `KeySender`, `Sparkle`, `MediaRemoteAdapter`, `SelectedTextKit` or `LaunchAtLogin-Modern`.

- [ ] **Step 2: Build the iOS target to surface any macOS-only code pulled in**

Run: `xcodebuild build -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: `BUILD SUCCEEDED`.

If `UserDefaultsManager.swift` fails to compile on iOS because it references AppKit or other macOS-only types, do NOT restructure the macOS file. Instead untick its iOS target membership and create `Shared iOS/SharedLanguageHints.swift` containing only the pieces `SonioxRealtimeClient` needs, copied verbatim:

```swift
import Foundation

extension UserDefaults {
    static let defaultPreferredLanguageHints = ["cs", "en"]

    var preferredLanguageHints: [String] {
        get {
            let raw = string(forKey: "PreferredLanguageHints") ?? ""
            let codes = raw.split(separator: ",").map(String.init)
            return codes.isEmpty ? Self.defaultPreferredLanguageHints : codes
        }
        set {
            let codes = newValue.isEmpty ? Self.defaultPreferredLanguageHints : newValue
            setValue(codes.joined(separator: ","), forKey: "PreferredLanguageHints")
        }
    }
}
```

Note: inside the extension, `UserDefaults.standard` is the extension's own container, so this returns the default `["cs", "en"]`. That is exactly the wanted behaviour (Czech first, multilingual allowed), so no extra wiring is needed for v1.

- [ ] **Step 3: Write the failing session tests**

Create `WhisperProIOSTests/DictationSessionTests.swift`:

```swift
import XCTest
@testable import Whisper_Pro_iOS

@MainActor
final class DictationSessionTests: XCTestCase {
    func testStartsIdle() {
        let session = DictationSession()
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(session.partialText, "")
        XCTAssertEqual(session.committedText, "")
    }

    func testMissingAPIKeyFailsWithMessage() async {
        let session = DictationSession(apiKeyProvider: { nil })
        await session.start()
        XCTAssertEqual(session.state, .failed("Add your Soniox API key in the Whisper Pro app."))
    }

    func testPartialEventUpdatesPartialText() {
        let session = DictationSession()
        session.apply(.partial(text: "ahoj sve"))
        XCTAssertEqual(session.partialText, "ahoj sve")
        XCTAssertEqual(session.committedText, "")
    }

    func testCommittedEventMovesTextToCommittedAndClearsPartial() {
        let session = DictationSession()
        session.apply(.partial(text: "ahoj svete"))
        session.apply(.committed(text: "ahoj svete"))
        XCTAssertEqual(session.committedText, "ahoj svete")
        XCTAssertEqual(session.partialText, "")
    }

    func testErrorEventSetsFailedState() {
        let session = DictationSession()
        session.apply(.error("socket closed"))
        XCTAssertEqual(session.state, .failed("socket closed"))
    }
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/DictationSessionTests`
Expected: FAIL, `cannot find 'DictationSession' in scope`.

- [ ] **Step 5: Implement DictationSession**

Create `Shared iOS/DictationSession.swift`, target membership: `Whisper Pro iOS` AND `Whisper Pro Keyboard`:

```swift
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
        default:
            break
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
```

If the compiler reports that `StreamingTranscriptionEvent` has no cases beyond the four handled, delete the `default:` branch. If it reports missing cases, keep it.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WhisperProIOSTests/DictationSessionTests`
Expected: PASS, 5 tests.

- [ ] **Step 7: Verify the macOS build still passes**

Run: `make build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add "Shared iOS/DictationSession.swift" WhisperProIOSTests/DictationSessionTests.swift "Whisper Pro.xcodeproj/project.pbxproj"
git commit -m "feat: add iOS dictation session streaming to Soniox"
```

---

### Task 5: Keyboard panel UI and text insertion

**Files:**
- Modify: `Whisper Pro Keyboard/KeyboardViewController.swift` (replace the Xcode template contents)
- Create: `Whisper Pro Keyboard/DictationPanelView.swift`

**Interfaces:**
- Consumes: `DictationSession` (Task 4), `TranscriptEdit.edit(from:to:)` (Task 2)
- Produces: `final class KeyboardViewController: UIInputViewController` as the extension principal class

- [ ] **Step 1: Implement the panel view**

Create `Whisper Pro Keyboard/DictationPanelView.swift`:

```swift
import SwiftUI

struct DictationPanelView: View {
    @ObservedObject var session: DictationSession
    let onToggle: () -> Void
    let onNextKeyboard: () -> Void

    private var isListening: Bool { session.state == .listening || session.state == .connecting }

    var body: some View {
        VStack(spacing: 12) {
            statusLine

            Button(action: onToggle) {
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(isListening ? Color.red : Color.accentColor, in: Circle())
            }
            .accessibilityLabel(isListening ? "Stop dictation" : "Start dictation")

            Button("Switch keyboard", action: onNextKeyboard)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch session.state {
        case .idle:
            Text("Tap to dictate").font(.footnote).foregroundStyle(.secondary)
        case .connecting:
            Text("Connecting").font(.footnote).foregroundStyle(.secondary)
        case .listening:
            Text("Listening").font(.footnote).foregroundStyle(.secondary)
        case .failed(let message):
            Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
        }
    }
}
```

- [ ] **Step 2: Implement the keyboard controller**

Replace the entire contents of `Whisper Pro Keyboard/KeyboardViewController.swift`:

```swift
import UIKit
import SwiftUI
import Combine

final class KeyboardViewController: UIInputViewController {
    private let session = DictationSession()
    private var cancellables = Set<AnyCancellable>()

    /// What this keyboard has already typed into the document for the current partial.
    private var insertedPartial = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        let panel = DictationPanelView(
            session: session,
            onToggle: { [weak self] in self?.toggle() },
            onNextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )

        let host = UIHostingController(rootView: panel)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(equalToConstant: 260)
        ])
        host.didMove(toParent: self)

        session.$partialText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.render(text) }
            .store(in: &cancellables)

        session.$committedText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.commit(text) }
            .store(in: &cancellables)
    }

    private func toggle() {
        Task { @MainActor in
            if session.state == .listening || session.state == .connecting {
                await session.stop()
            } else {
                await session.start()
            }
        }
    }

    /// Rewrites the in-progress text using the smallest possible edit.
    private func render(_ text: String) {
        let edit = TranscriptEdit.edit(from: insertedPartial, to: text)
        for _ in 0..<edit.deleteCount {
            textDocumentProxy.deleteBackward()
        }
        if !edit.insert.isEmpty {
            textDocumentProxy.insertText(edit.insert)
        }
        insertedPartial = text
    }

    /// A committed segment is final: make sure the document matches it, then
    /// forget it so the next partial starts from an empty baseline.
    private func commit(_ text: String) {
        guard !text.isEmpty else { return }
        render(text)
        textDocumentProxy.insertText(" ")
        insertedPartial = ""
    }
}
```

- [ ] **Step 3: Build the extension**

Run: `xcodebuild build -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: `BUILD SUCCEEDED` for both the app and the embedded extension.

- [ ] **Step 4: Verify the macOS build still passes**

Run: `make build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add "Whisper Pro Keyboard" "Whisper Pro.xcodeproj/project.pbxproj"
git commit -m "feat: add dictation panel keyboard with live text insertion"
```

---

### Task 6: Container app setup screen

**Files:**
- Modify: `Whisper Pro iOS/WhisperProIOSApp.swift`
- Create: `Whisper Pro iOS/SetupView.swift`

**Interfaces:**
- Consumes: `SharedKeychain.save(_:forKey:)`, `SharedKeychain.get(forKey:)`, `SharedKeychain.sonioxKey` (Task 1); `IOSAudioRecorder.requestPermission()` (Task 3)
- Produces: nothing consumed by later tasks

- [ ] **Step 1: Implement the setup screen**

Create `Whisper Pro iOS/SetupView.swift`:

```swift
import SwiftUI

struct SetupView: View {
    @State private var apiKey = ""
    @State private var savedKeyExists = SharedKeychain.get(forKey: SharedKeychain.sonioxKey) != nil
    @State private var microphoneGranted = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Soniox API key") {
                    SecureField("Paste your key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Save key") {
                        if SharedKeychain.save(apiKey, forKey: SharedKeychain.sonioxKey) {
                            savedKeyExists = true
                            apiKey = ""
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    if savedKeyExists {
                        Label("Key saved", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section("Microphone") {
                    Button("Allow microphone") {
                        Task { microphoneGranted = await IOSAudioRecorder.requestPermission() }
                    }
                    if microphoneGranted {
                        Label("Microphone allowed", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }

                Section("Turn on the keyboard") {
                    Text("1. Open Settings, General, Keyboard, Keyboards.")
                    Text("2. Add New Keyboard and pick Whisper Pro.")
                    Text("3. Tap Whisper Pro and turn on Allow Full Access. The keyboard needs it to reach Soniox.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Whisper Pro")
        }
    }
}
```

- [ ] **Step 2: Point the app at the setup screen**

Replace the body of `Whisper Pro iOS/WhisperProIOSApp.swift`:

```swift
import SwiftUI

@main
struct WhisperProIOSApp: App {
    var body: some Scene {
        WindowGroup {
            SetupView()
        }
    }
}
```

Delete the template `ContentView.swift` if Xcode generated one, and remove it from the target.

- [ ] **Step 3: Build and run in the simulator**

Run: `xcodebuild build -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Run the full iOS test suite**

Run: `xcodebuild test -project "Whisper Pro.xcodeproj" -scheme "Whisper Pro iOS" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: PASS, all tests from Tasks 1 to 4.

- [ ] **Step 5: Verify the macOS build still passes**

Run: `make build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add "Whisper Pro iOS" "Whisper Pro.xcodeproj/project.pbxproj"
git commit -m "feat: add iOS setup screen for API key and keyboard onboarding"
```

---

### Task 7: Device verification and TestFlight

**Files:**
- Modify: `README.md` (add an iOS keyboard section)
- Modify: `PRD.md` (add the iOS keyboard feature)

**Interfaces:**
- Consumes: everything from Tasks 1 to 6
- Produces: a build available in TestFlight

- [ ] **Step 1: Run on the physical iPhone**

Connect Zdenek's iPhone, select it as the destination, run the `Whisper Pro iOS` scheme. In the app: paste the Soniox API key, tap Save key, tap Allow microphone.

- [ ] **Step 2: Enable the keyboard on the device**

Settings > General > Keyboard > Keyboards > Add New Keyboard > Whisper Pro. Then tap Whisper Pro and enable Allow Full Access.

- [ ] **Step 3: Verify live dictation end to end**

Open Notes, tap a new note, press the globe key until the Whisper Pro panel appears, tap the microphone and speak a Czech sentence for about 10 seconds.

Expected: text appears in the note while speaking, updates in place as Soniox refines the words, and a finished sentence stays put followed by a space. Tap stop and confirm the text remains.

If nothing appears, check that Allow Full Access is on, and read the extension log with:
`xcrun devicectl device info details` to confirm the device, then use Console.app filtered on process `Whisper Pro Keyboard`.

- [ ] **Step 4: Check memory headroom**

With the keyboard open and dictating, in Xcode use Debug > Attach to Process > Whisper Pro Keyboard and watch the memory gauge.
Expected: under 60 MB. If it exceeds that, the extension will be killed by the system, and the cause must be fixed before shipping.

- [ ] **Step 5: Update the documentation**

Add a short section to `README.md` describing the iOS keyboard: what it does, that it needs Allow Full Access, and that the API key is entered in the iOS app. Add the same feature to `PRD.md` alongside the existing macOS features. No emoji, no em dash.

- [ ] **Step 6: Archive and upload to TestFlight**

In Xcode: select "Any iOS Device" as the destination, Product > Archive, then Distribute App > TestFlight & App Store > Upload. Team `A6D3VFTJYT`.

Expected: the build appears in App Store Connect > TestFlight within roughly 15 minutes.

- [ ] **Step 7: Commit the documentation**

```bash
git add README.md PRD.md
git commit -m "docs: document the iOS dictation keyboard"
```

---

## Known limitations of v1

- The keyboard has no letter keys. The globe key or the Switch keyboard button returns to the system keyboard.
- Language hints inside the extension fall back to `["cs", "en"]` because the extension has its own UserDefaults container. This matches the wanted behaviour, so it is not wired to the Mac settings.
- No dictation history, no custom vocabulary, and no local Whisper model on iOS. Those stay macOS only.
- Distribution is TestFlight only. No App Store review is planned.
