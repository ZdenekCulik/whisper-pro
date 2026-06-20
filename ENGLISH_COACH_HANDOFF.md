# Ambient English Coach — handoff

Status: **feature built + compiling + installed.**
Root cause of "no card" is **diagnosed and is NOT a code bug** (see below).
The missing-provider case is now non-silent: the coach shows a one-time warning toast
with an "AI Models" action when the AI call fails because no provider key is configured.
It also falls back to a configured chat provider if the selected provider has no key
(OpenAI first, then other connected providers).
Latest display fix: corrections were being saved but the card could be missed because
it dismissed on the next recorder toggle and sat too low/low-level. The card now stays
for its auto-dismiss window and is raised above the recorder layer.

## What it does
After each English dictation, pick ONE useful correction (word/phrase/collocation a
non-native speaker got wrong), save it, and show a small floating card bottom-center
(`said → corrected` in green + a handwritten "why"). Collected on the dashboard.

## Root cause of "card never shows" (CONFIRMED, not a guess)
A temporary self-test previously ran the AI path on a hardcoded sentence at launch and wrote to
`/tmp/whisperpro_coach_diag.txt`:
```
SELFTEST start provider=Gemini apiValid=false
AI FAILED: AI provider not configured. Please check your API key.
```
- `EnglishCoachService.handleCompleted` runs fine (observer + all gates pass: enabled,
  status=completed, words≥4, lang=en).
- The AI call fails: `APIKeyManager.getAPIKey(forProvider:"Gemini")` looks up keychain
  key **`geminiAPIKey`** (APIKeyManager.swift:16) which is **not stored**. So no usable
  AI enhancement key is configured → `EnhancementError.notConfigured`.
- **Fix = user must add an AI provider API key in AI Models** (Gemini/OpenAI/Anthropic/
  Groq). Then the coach (and AI enhancement) work. Verify with a real English dictation.

## Files added (all compile; `make signed` succeeds)
- `Whisper Pro/Models/CoachNote.swift` — @Model (own `coach.store`).
- `Whisper Pro/Services/EnglishCoach/EnglishCoachService.swift` — singleton; observes
  `.transcriptionCompleted`, detects English (NLLanguageRecognizer), calls
  `AIService.completeChat`, resolves a configured chat provider, parses a line format,
  persists `CoachNote`, publishes `latestSuggestion`, posts `.englishCoachCorrectionReady`.
- `Whisper Pro/Views/Coach/CoachCardView.swift` — the card + `CoachCardPresenter`
  (lightweight floating NSPanel, decoupled from the recorder for safety; no longer
  dismisses on the next recorder toggle).
- `Whisper Pro/Views/Settings/EnglishCoachSettingsView.swift` — toggle + native language.
- `Whisper Pro/Views/Dashboard/CoachPhrasesCard.swift` — dashboard collection.

## Integration edits (done)
- `WhisperPro.swift`: `CoachNote.self` added to master `Schema`; `coach.store` config in
  both `createPersistentContainer` + `createInMemoryContainer`; at init →
  `EnglishCoachService.shared.configure(aiService:container:)` + `CoachCardPresenter.shared.start()`.
- `AppDefaults.swift`: registered `englishCoachEnabled` (false), `englishCoachNativeLanguage` ("cs").
- `AppNotifications.swift`: added `.englishCoachCorrectionReady`.
- `SettingsView.swift`: "English Coach" section → `EnglishCoachSettingsView()`.
- `DashboardContent.swift`: `CoachPhrasesCard()` between heroSection and RecentTranscriptsSection.

## TODO for whoever finishes this
1. **Done**: missing AI provider now shows a one-time `NotificationManager` toast:
   "English Coach needs an AI provider. Add a key in AI Models." The action opens the
   AI Models screen.
   Also done: if the selected provider is unconfigured, the coach now falls back to
   connected chat providers, preferring OpenAI.
2. **Done**: TEMP diagnostics were removed from `EnglishCoachService.swift`:
   - `diag(_:)` helper (writes `/tmp/whisperpro_coach_diag.txt`) + all `diag(...)` calls.
   - `selfTest()` method + the `/tmp/whisperpro_coach_selftest` flag check in `configure()`.
3. **Keep** the change that removed the `aiService.isAPIKeyValid` gate (handleCompleted now
   just `guard let aiService` and lets `completeChat` throw) — that's intentional/correct.
4. **Done**: prompt tuned to target word-choice / idiom / collocation / false-friend
   errors, not spelling/tense/plural/inflection-only fixes. See
   `EnglishCoachService.systemPrompt`.
   Also tightened to preserve intended meaning for lend/borrow mistakes.
5. **Optional**: move the card INTO the recorder widget instead of a separate floating panel
   (user originally wanted "the widget shrinks into the card"). Map for that is in the
   workflow output; the assistant-panel pattern (`WhisperProEngine+Assistant.swift`,
   `hasAssistantResponse` in `MiniRecorderView`) is the precedent.

## Verification state
- Compiles (`make signed` BUILD SUCCEEDED on Jun 19, 2026), installed to /Applications
  (stable Apple Dev cert).
- Codex independent review ran **twice**, found 5 P2s — **all fixed**. Then Codex hit its
  usage limit (resets ~Jun 20 01:28). The 2 later fixes + the temp diagnostics have NOT been
  Codex-reviewed yet — re-run `codex exec review --uncommitted` after the limit resets.
- **Not committed** (waiting on explicit "comit push").
