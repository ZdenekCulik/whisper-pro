<div align="center">
  <img src="Whisper Pro/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="160" height="160" />
  <h1>Whisper Pro</h1>
  <p>A native macOS app that turns your voice into text, almost instantly.</p>

  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
  ![Swift](https://img.shields.io/badge/Swift-orange)
</div>

---

Whisper Pro is a personal macOS voice-to-text app: press a hotkey, speak, and the text is
typed in wherever your cursor is. Transcription runs through your own speech-to-text
provider (e.g. Soniox), with optional AI cleanup of the text.

This is a private fork that I build and run for myself — it's not a commercial product and
isn't sold or distributed publicly.

## Features

- 🎙️ Fast voice-to-text via a global hotkey, pasted right at your cursor
- ⚡ Modes — per-app / per-context settings for how text is transcribed and formatted
- 📝 Personal dictionary and smart text replacements
- 🔄 Live transcript while you speak
- 📊 Dashboard with your own dictation stats

## Build from source

Full instructions are in [BUILDING.md](BUILDING.md). Short version:

```bash
git clone https://github.com/ZdenekCulik/whisper-pro.git
cd whisper-pro
make local      # ad-hoc build, no Apple Developer account needed
```

After first launch, add your own speech-to-text API key (e.g. Soniox) in the app's
settings — no keys are bundled in this repo.

## Requirements

- macOS 14.0 or later
- Xcode (latest)

## Acknowledgments

Built on these open-source projects:

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — on-device Whisper inference
- [FluidAudio](https://github.com/FluidInference/FluidAudio) — Parakeet model support
- [Sparkle](https://github.com/sparkle-project/Sparkle), [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin), [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter), [Zip](https://github.com/marmelroy/Zip), [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit), [Swift Atomics](https://github.com/apple/swift-atomics)

## License

Licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE).
