<div align="center">
  <img src="Whisper Pro/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="160" height="160" />
  <h1>Whisper Pro</h1>

  <p align="center">
    <img src="docs/cover.jpg" alt="Whisper Pro — dashboard and floating dictation bar" width="100%">
  </p>

  <p>A native macOS app that turns your voice into text, almost instantly.</p>

  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
  ![Swift](https://img.shields.io/badge/Swift-orange)
</div>

---

Whisper Pro is a personal macOS voice-to-text app: press a hotkey, speak, and the text is
typed in wherever your cursor is. Transcription runs through your own speech-to-text
provider (e.g. Soniox), with optional AI cleanup of the text.

It started as a fork of [VoiceInk](https://github.com/Beingpax/VoiceInk) by Prakash Joshi
(Pax), and has since been heavily reworked and is maintained independently. It's built for
my own personal use and shared here as-is, under the GPL-3.0 license — not a commercial
product, no support or roadmap promises.

**Status:** actively used daily by the author (me). Issues and PRs may or may not get a
response.

**Known quirks:**
- The bundle id `com.prakashjoshipax.WhisperPro` is inherited from upstream VoiceInk and
  kept on purpose — changing it would reset existing installs' permissions and data
  (transcripts, stats, streak).
- Sparkle auto-update checks are wired up but currently a no-op — the appcast has no
  published releases yet, so the app won't actually update itself.

## Why Whisper Pro

- ⚡ **The fastest voice-to-text on macOS** — press (or hold) a global hotkey, speak, and the text streams in live, right where your cursor is
- 🎧 **Auto-pauses your music** while you dictate — and resumes it the moment you're done
- ↩️ **Dictate → send in one breath** — optional auto-Enter pastes the text and sends the message for you
- 🔌 **Bring your own engine** — plug in any speech-to-text provider, cloud (e.g. Soniox) or a fully local model
- 📝 **Personal dictionary & smart replacements** — it learns the names and words you actually use
- 📊 **Live transcript panel + your own stats** — see the words as you say them, track hours saved and your streak

## Build from source

Full instructions are in [BUILDING.md](BUILDING.md). Short version:

```bash
git clone https://github.com/ZdenekCulik/whisper-pro.git
cd whisper-pro
make local      # ad-hoc build, no Apple Developer account needed
```

For a build whose macOS permissions (Accessibility, Microphone) survive rebuilds, use
`make signed` instead (signs with your own Apple Development certificate — grant
permissions once). To produce a distributable DMG for sharing with someone else, use
`make dmg`.

After first launch, add your own speech-to-text API key (e.g. Soniox) in the app's
settings — no keys are bundled in this repo.

## Requirements

- macOS 14.0 or later
- Xcode (latest)

## Acknowledgments

Built on these open-source projects:

- [VoiceInk](https://github.com/Beingpax/VoiceInk) by Prakash Joshi (Pax) — the original project this app was forked from
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — on-device Whisper inference
- [FluidAudio](https://github.com/FluidInference/FluidAudio) — Parakeet model support
- [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)

## License

Licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE).
