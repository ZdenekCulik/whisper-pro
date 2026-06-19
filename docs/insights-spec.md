# Whisper Pro — Insights: technická specifikace statistik

## 1. Kde data žijí (datová vrstva)

Aplikace používá **SwiftData** se třemi oddělenými úložišti
(v `~/Library/Application Support/com.prakashjoshipax.VoiceInk/`):

- **`default.store`** → model `Transcription` (každý jednotlivý přepis: text, časová značka, délka, použitý model, mód, …).
- **`stats.store`** → model `SessionMetric` (jedna „session" = jedno dokončené diktování; z tohoto modelu se počítá VĚTŠINA statistik).
- **`dictionary.store`** → modely `VocabularyWord` (vlastní slova) a `WordReplacement` (pravidla nahrazení).

Klíčový model `SessionMetric` má pole:
`timestamp`, `wordCount`, `audioDuration` (s), `transcriptionDuration` (s), `speedFactor`, `modeName`, `appName`, `appBundleId`, `aiEnhancementModelName`, `enhancementDuration`.

## 2. Kdy se session zaznamená (okamžik měření)

Po každém **úspěšně dokončeném** přepisu (`TranscriptionPipeline` → `SessionMetricRecorder.recordRecorderSession`) se vytvoří jeden `SessionMetric`. Při tom se spočítá:

- **`wordCount`** = `WordCounter.count(in: finalText)`. `finalText` = AI-vylepšený text, pokud proběhlo AI vylepšení, jinak surový přepis. Počítání slov používá Apple `NLTokenizer(unit: .word)` — tedy **lingvistické tokeny slov**, ne jen mezery (interpunkce se nepočítá jako slovo).
- **`audioDuration`** = délka nahrávky v sekundách.
- **`transcriptionDuration`** = jak dlouho trvalo model přepsat (s).
- **`speedFactor`** = `audioDuration / transcriptionDuration` (kolikrát rychleji než realtime).
- **`appName` / `appBundleId`** = aplikace, do které jsi diktoval — zachycená na **startu nahrávání** přes `ActiveWindowService.shared.currentApplication` (frontmost app).
- **`modeName`** = aktivní mód.
- **`aiEnhancementModelName`** = vyplněno, jen pokud session prošla AI vylepšením.

Po vložení se pošle notifikace `.sessionMetricsDidChange`, na kterou dashboard reaguje a přepočítá statistiky.

## 3. Jednotlivé statistiky — přesné vzorce

### Hero sekce (horní karta) — počítá `DashboardStatsLoader` / `DashboardContent`

- **Sessions** = `COUNT(*)` všech `SessionMetric`. (= počet diktování celkem.)
- **Words** = `SUM(wordCount)` přes všechny `SessionMetric`.
- **Words per minute (WPM)** = `totalWords / (totalDuration / 60)`, kde `totalDuration = SUM(audioDuration)`. Tedy průměrná rychlost řeči napříč celou historií.
- **Time saved** = `max(estimatedTypingTime − totalDuration, 0)`, kde `estimatedTypingTime = (totalWords / 35) × 60` sekund. **Konstanta 35 = předpokládaná rychlost psaní na klávesnici (35 wpm).** Logika: kolik času bys strávil psaním stejného počtu slov minus čas, který sis odmluvil.
- **Keystrokes** = `totalWords × 5`. **Odhad** — předpokládá průměrně 5 znaků (úhozů) na slovo. Není to reálně naměřený počet úhozů.

### Insights panel — počítá `InsightsLoader` (jeden průchod přes všechny `SessionMetric`)

- **Activity (heatmapa)** = pro každý den posledních **17 týdnů (119 dní)** se sečte `SUM(wordCount)` za daný den (bucket podle `startOfDay` v **lokálním** časovém pásmu). Intenzita dlaždice = 5 úrovní normalizovaných vůči nejaktivnějšímu dni (poměr k maximu: <0.15, <0.4, <0.7, jinak nejvyšší). Den bez diktování = úroveň 0.
- **Day streak (aktuální)** = počet **po sobě jdoucích** dní s aspoň 1 slovem, počítáno od dneška zpět; přeruší se prvním prázdným dnem.
- **Longest streak** = nejdelší souvislá série dní s aktivitou v celém 119denním okně.
- **When you dictate (hodiny dne)** = pole 24 hodnot; pro každou session se `wordCount` přičte do koše podle `hour(timestamp)` v lokálním čase. Špička = hodina s nejvíc slovy → text „You dictate most around X".
- **Top apps** = seskupení sessions podle `appName` (vyloučeny prázdné a vlastní appka — bundle ID `com.prakashjoshipax.VoiceInk` a `…WhisperPro`). Top 5 podle **počtu sessions**, `fraction = počet / součet_top_appek`, `bundleId` se použije k načtení **reálné macOS ikony** přes `NSWorkspace`.
- **Total words trend / delta** = týdenní součty `wordCount` za posledních 12 týdnů (pro kumulativní graf). **Delta „X% this month"** = `(slova_tento_měsíc − slova_minulý_měsíc) / slova_minulý_měsíc × 100`.
- **Dictionary entries** = `COUNT(VocabularyWord) + COUNT(WordReplacement)` (vlastní slova + pravidla nahrazení).
- **Enhanced sessions** = počet `SessionMetric`, kde `aiEnhancementModelName` není prázdné (kolikrát Whisper text vyladil přes AI).

### Zobrazované konstanty (NEjsou z dat, jsou to fixní referenční hodnoty v UI)

- WPM speedometer: **Typing = 40**, **Talking = 150** wpm jako referenční body (pro přirovnání „kolikrát rychleji než psaní"). Násobek = `tvoje_wpm / 40`.

## 4. Jak se to obnovuje

- Načte se na pozadí při zobrazení dashboardu (`.task`).
- Přepočítá se po **každém novém diktování** (notifikace `.sessionMetricsDidChange`).
- Načítání běží mimo hlavní vlákno, dávkově (po 500 záznamech).

## 5. Důležité limity / poznámky pro návrh textů

1. **Top apps + ikony se plní až od teď** — staré záznamy (před přidáním capture) nemají `appName`, takže žebříček roste postupně, jak diktuješ.
2. **Keystrokes (×5) a Time saved (35 wpm) jsou odhady**, ne přesná měření — vhodné formulovat jako „~" nebo „odhadem".
3. **WPM = rychlost řeči** (slova / délka audia), ne rychlost psaní.
4. **Activity i hodiny jsou v lokálním čase**, okno je pevných 119 dní (cca půl roku).
5. **Sessions ≠ Transcriptions** — session se zaznamená jen u úspěšně dokončených přepisů; zrušené/neúspěšné se nepočítají.
6. Streak se počítá podle **slov za den > 0**, ne podle počtu sessions.
