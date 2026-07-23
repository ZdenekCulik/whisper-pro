# iOS Keyboard Extension - Design Spec

Datum: 2026-07-23
Stav: schvaleno Zdenkem (brainstorming 2026-07-22/23)

## Cil

Diktovat na iPhonu do libovolne aplikace pres vlastni klavesnici (keyboard extension), ktera streamuje zvuk na Soniox a zivy prepis vklada primo do textoveho pole. Distribuce pres TestFlight.

## Rozhodnuti ze zadani

- Rozsah: diktovani vsude pres klavesnici; hlavni iOS appka slouzi jen k nastaveni.
- Flow: zivy prubezny prepis (Soniox streaming), ne nahraj-stop-vloz.
- Podoba klavesnice: pouze diktovaci panel (zadna QWERTY) - velke tlacitko nahravani, zive naskakujici text, smazani posledni vety, globus pro prepnuti na systemovou klavesnici.
- Jazyky: stejne jako na Macu - cestina prioritne + multilang.
- Pristup: novy iOS target ve stavajicim Whisper Pro.xcodeproj (varianta A), Soniox klient se sdili, nekopiruje.

## Architektura

Dva nove targety ve Whisper Pro.xcodeproj:

1. **Whisper Pro iOS (app)** - obrazovka nastaveni: zadani Soniox API klice, navod na zapnuti klavesnice + Allow Full Access, test mikrofonu. Klic se uklada do Keychain s App Group sdilenim, aby na nej dosahla extension.
2. **Whisper Pro Keyboard (keyboard extension)** - diktovaci panel. RequestsOpenAccess = YES (nutne pro sitovy pristup na Soniox).

Sdileny kod (existujici, macOS-cisty Swift):
- `Whisper Pro/Transcription/Streaming/SonioxRealtimeClient.swift` - WebSocket klient (wss://stt-rt.soniox.com/transcribe-websocket, model stt-rt-v5, API klic v config JSON, pote raw binary PCM ramce). Prenositelny beze zmeny (Foundation + URLSessionWebSocketTask).
- Relevantni casti `APIKeyManager` (Keychain, jiz iOS-kompatibilni) - rozsirit o App Group access group.

Novy iOS-only kod:
- **Audio capture**: AVAudioSession + AVAudioEngine, konverze na PCM 16-bit LE, 16 kHz, mono, ~100ms chunky (3200 B) - stejny kontrakt jako CoreAudioRecorder na Macu. (macOS CoreAudioRecorder je AUHAL, na iOS nepouzitelny.)
- **Lehky streaming koordinator** pro extension: propojuje recorder -> SonioxRealtimeClient -> vkladani textu. Nepouziva se macOS StreamingTranscriptionService (je @MainActor + SwiftData + FluidAudio, vazany na Mac lifecycle).
- **Vkladani textu**: UITextDocumentProxy - prubezny (partial) text se vklada a pri zmene maze/nahrazuje pres deleteBackward, committed text se fixuje. Zadne accessibility API (to je macOS koncept).

## Datovy tok

Klik na nahravani -> AVAudioEngine mikrofon -> konverze 16 kHz PCM -> SonioxRealtimeClient (WebSocket) -> partial/committed tokeny -> UITextDocumentProxy.insertText do aktivniho pole.

## Rizika a mitigace

1. **Mikrofon v keyboard extension** - nejcitlivejsi bod. Krok c. 1 implementace = mini-prototyp overujici nahravani v extension na Zdenkove iPhonu (dukaz: Superwhisper i Wispr Flow diktovaci klavesnice maji). Kdyz selze, stop a plan B pred stavbou zbytku.
2. **Allow Full Access** - bez nej extension nema sit; onboarding v appce musi uzivatele provest zapnutim.
3. **Nerozbit Mac build** - iOS soubory ve vlastnich slozkach, po kazde fazi overit build macOS targetu.
4. **Pametovy limit extensions** (~60-70 MB) - panel je jednoduchy, streaming bez bufferovani celych nahravek; hlidat pri verifikaci.

## Mimo rozsah (v1)

- Historie diktatu na mobilu
- Lokalni Whisper/FluidAudio na iPhonu
- Custom slovnik / nastaveni nad ramec API klice
- App Store release (jen TestFlight)

## Verifikace

- Po kazde fazi: build obou platforem prochazi.
- Finalni test: na realnem iPhonu pres TestFlight - prepnout na klavesnici, nadiktovat cesky text do Zprav/Notes, text zivy naskakuje a odpovida.
