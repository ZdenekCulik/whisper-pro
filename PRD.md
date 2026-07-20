# Whisper Pro: Product Requirements Document

## 1. Product vision

Whisper Pro turns speech into text anywhere on macOS, fast enough that dictation replaces
typing rather than feeling like a workaround. Press a hotkey, speak, and the transcribed
text lands in whatever app has focus, cleaned up and formatted, with no extra steps.

## 2. Target user

A single user: the author, dictating daily into chat apps, editors, and browsers. The
product is not built for a general audience, a team, or a paying customer base. Every
decision optimizes for that one workflow: reliability, speed, and low friction on a
personal Mac, not configurability for strangers.

## 3. Problem statement

Typing is slower than speaking, and switching between "hands on keyboard" and "voice
memo app, transcribe later, copy-paste" breaks flow entirely. Existing dictation tools
(macOS built-in dictation, cloud note-taking apps) are either too inaccurate, too slow to
start, tied to a single provider, or don't format/clean the output enough to paste
directly into a message or document. Whisper Pro exists to close that gap: one hotkey,
provider-agnostic transcription, and an output pipeline that produces text ready to send.

## 4. Core user flows

### 4.1 Dictate and send
1. User presses the configured global hotkey (primary or secondary shortcut, or a
   middle-click hold).
2. A floating recorder widget appears (mini panel or notch-style panel) and starts
   capturing audio; system audio playback is muted for the duration if enabled.
3. Speech streams to the configured transcription provider. With a streaming provider,
   partial text appears live in the widget as the user talks.
4. On stop, the transcript passes through processing (filler word removal, paragraph
   formatting, personal dictionary replacements) and optional AI enhancement, then is
   typed into the focused app via simulated keystrokes.
5. If configured, an Enter key press is simulated afterward, so a chat message dictated
   into Slack or iMessage is sent without the user touching the keyboard.

### 4.2 Switch transcription engine or model
1. User opens Settings, AI Models.
2. Picks a cloud provider (Soniox, AssemblyAI, Deepgram, ElevenLabs, Groq, Mistral,
   Cartesia, Speechmatics, xAI, Gemini) and enters an API key, or picks a local model
   (a whisper.cpp GGML model, or a FluidAudio Parakeet model) and downloads it on-device.
3. The new engine is used on the next dictation, no restart required.

### 4.3 Context-aware Modes
1. User defines or picks a starter Mode (Dictation, Enhancement, Email, Rewrite,
   Assistant) tied to a trigger: the frontmost app, or a browser URL pattern.
2. When that app or site is focused, the matching Mode's prompt, AI enhancement
   settings, and (optionally) a custom shell command run on the transcript instead of
   the default pipeline.
3. This lets the same hotkey behave differently in, say, an email client versus a code
   editor versus a chat app, without the user manually switching settings each time.

### 4.4 First run / onboarding
1. Trust screen introduces the app.
2. Permissions screen requests Microphone and Accessibility, with a one-click repair
   path if Accessibility shows granted but doesn't work (a stale TCC entry from a
   previous build).
3. User picks and downloads a transcription model, or sets up a cloud provider
   (Soniox is the guided default) and enters an API key.
4. The dictation hotkey is confirmed/configured on the final onboarding screen so the
   user leaves onboarding able to dictate immediately.

### 4.5 Review history and progress
1. User opens the Dashboard to see stats: hours saved, dictation streaks, a
   contribution graph, top apps dictated into, and recent transcripts.
2. User opens History to browse, search, or recover past transcriptions (a recovery
   store protects against losing a transcript if the app crashes mid-session).
3. The English Coach surfaces observations and phrasing suggestions derived from the
   user's own dictation history.

## 5. Feature list and rationale

| Feature | Rationale |
|---|---|
| Global hotkey dictation (primary + secondary shortcut, middle-click toggle) | Core interaction: dictation must start with zero clicks through menus. |
| Floating recorder widget (mini panel, notch-style panel, multiple visual variants) | Visual confirmation that recording is live, without stealing window focus from the app being dictated into. |
| Multi-provider transcription (cloud and local) | No single provider is reliably fastest, cheapest, or most accurate for every language and network condition; provider choice is the user's, not locked in. |
| Streaming (realtime) transcription with word-agreement merging | Live partial text reduces perceived latency and lets the user see mistakes as they happen instead of after a long pause. |
| Local model support (whisper.cpp, FluidAudio Parakeet, native Apple Speech) | Works offline, avoids per-minute API cost, and keeps audio on-device when privacy matters more than raw accuracy. |
| AI enhancement / post-processing (configurable AI provider, including local Ollama) | Raw ASR output has filler words, run-on sentences, and no punctuation cleanup; enhancement makes the text closer to what a person would type. |
| Personal dictionary (vocabulary words, word replacements) | ASR engines mis-transcribe names, jargon, and abbreviations consistently; a per-user dictionary fixes the same mistake permanently instead of every time. |
| Filler word removal, paragraph formatting | Small, cheap cleanup steps that make dictated text readable without invoking a full AI pass every time. |
| Modes (app/URL-triggered behavior, custom shell commands) | Different destinations need different formatting and tone; the app should adapt automatically to where the text is going. |
| Auto-pause system audio during recording | Prevents music or a video call from bleeding into the microphone and corrupting the transcript. |
| Send-on-Enter | Removes the last manual step for chat-style destinations, so dictation is a complete send action, not just text insertion. |
| Dashboard stats, streaks, insights | Personal motivation and a sanity check that the tool is actually being used and saving time. |
| Transcript history + crash recovery store | Losing a long dictation to a crash is worse than typing it in the first place; recovery removes that risk. |
| English Coach | Turns the by-product of daily dictation (a large corpus of the user's own speech) into passive language-learning feedback. |
| Onboarding with permission repair | Accessibility grants silently go stale after every ad-hoc rebuild during development; the repair flow turns a recurring dev annoyance into a one-click fix instead of a support dead end. |
| Homebrew cask + notarized DMG distribution | Lets the app be installed and updated like any other Mac app, without requiring Xcode or a build step for casual reinstalls. |

## 6. Non-goals

- **Not a commercial product.** No pricing, no support SLA, no roadmap commitments. The
  inherited VoiceInk licensing/trial gate (Polar-based license keys, trial countdown)
  is present in the code but deliberately disabled; the app always runs fully unlocked
  (see `LicenseViewModel.init`).
- **Not App Store distributed.** The app needs Accessibility automation and disables
  the App Sandbox entirely, which the Mac App Store does not allow.
- **Not multi-user or team-oriented.** No shared configuration, no admin controls, no
  usage analytics sent anywhere.
- **Not aiming for maximum configurability for other users.** Features are added when
  the author needs them for personal dictation, not to serve a broad settings surface.
- **Not currently self-updating.** Sparkle auto-update is wired into the app but is a
  no-op today: the appcast has no published releases, so installed copies do not
  update themselves yet.

## 7. Technical overview

- **Shape:** SwiftUI macOS app, `MenuBarExtra`-based menu bar app that can also show a
  regular window and Dock icon (user-toggleable "menu bar only" mode).
- **Entry point:** `WhisperProApp` (`Whisper Pro/WhisperPro.swift`) wires up all core
  services at launch: the transcription engine, model managers, shortcut manager, menu
  bar manager, AI service, and enhancement service.
- **Transcription engine:** `WhisperProEngine` orchestrates recording (`Recorder`,
  `CoreAudioRecorder`) through a pipeline (`TranscriptionPipeline`) that dispatches to
  whichever provider is active: local Whisper models, local FluidAudio (Parakeet)
  models, native Apple Speech, or one of the cloud providers under
  `Transcription/Cloud` and `Transcription/Streaming` (Soniox, AssemblyAI, Deepgram,
  ElevenLabs, Groq, Mistral, Cartesia, Speechmatics, xAI, Gemini).
- **Processing layer:** `Transcription/Processing` handles filler-word removal,
  paragraph formatting, and dictionary word replacement before AI enhancement
  (`Services/AIEnhancement`) optionally rewrites the text further.
- **Delivery:** `TranscriptionDelivery` and `CustomCommandDeliveryRunner` type the final
  text into the focused app via Accessibility APIs and optionally simulate an Enter
  key press or run a custom shell command on the output.
- **Modes:** `Modes/` tracks the frontmost app (`ActiveWindowService`) and, for
  supported browsers, the current URL (`BrowserURLService`) to select which Mode's
  configuration and prompt apply.
- **Persistence:** SwiftData, split across several local, non-CloudKit stores
  (transcripts, dictionary, stats, coach notes, typed chat-log metrics), stored under
  the legacy `com.prakashjoshipax.VoiceInk` Application Support path so the app's
  history survived the VoiceInk-to-Whisper Pro rename.
- **Permissions:** Microphone (`NSMicrophoneUsageDescription`), Accessibility (typing
  and Enter simulation, requested via `AXIsProcessTrustedWithOptions`), Screen
  Recording and Apple Events (context detection for Modes). The App Sandbox is
  disabled (`com.apple.security.app-sandbox = false`) because Accessibility automation
  and the entitlements it needs are incompatible with sandboxing.
- **Signing model:** three entitlement/build variants exist: a full signed build with
  iCloud/keychain entitlements (`WhisperPro.entitlements`), a local ad-hoc build with
  stripped entitlements for building without a paid developer account
  (`WhisperPro.local.entitlements`), and a distribution build for sharing a DMG with
  someone else (`WhisperPro.dist.entitlements`).
- **Auto-update:** Sparkle is integrated (`SUFeedURL` pointing at the repo's
  `appcast.xml`) but currently inert, as noted in section 6.

## 8. Distribution model

- **Primary path:** Homebrew cask, `brew install --cask zdenekculik/tap/whisper-pro`,
  pointing at the `ZdenekCulik/homebrew-tap` repository. Bumped on every release
  (version + sha256).
- **Secondary path:** a notarized `.dmg` built with `make dmg` (Developer ID signing
  plus Apple notarization, or an ad-hoc-signed DMG if no paid developer account is
  configured), published to GitHub Releases.
- **Source:** the repository itself is public and buildable via `make local` (no paid
  developer account needed) or `make signed` (stable signature, permissions survive
  rebuilds). See `README.md` and `BUILDING.md`.
- **License:** GNU GPL-3.0, inherited from and required by the upstream VoiceInk fork.

## 9. Success criteria

Since this is a single-user personal tool, success is defined against the author's own
daily use rather than growth or revenue metrics:

- Dictation is fast and accurate enough to be the default input method for chat
  messages, not an occasional novelty.
- A rebuild during development never requires re-granting Accessibility manually
  (the repair flow catches it).
- Switching transcription provider or model is a settings change, never a code change.
- No dictation session is lost to a crash (recovery store holds up).
- The Dashboard's stats (hours saved, streak) reflect real, sustained daily use over
  time.

## 10. Future ideas

Speculative only, not committed:

- Publish an actual Sparkle appcast so installed copies self-update.
- Expand Modes with more starter templates beyond the current five (Dictation,
  Enhancement, Email, Rewrite, Assistant).
- Broader language support/testing beyond the current Czech-first fix and English
  defaults.
- Investigate a lightweight way to accept external contributions given the "no
  support" stance, if community interest appears.
