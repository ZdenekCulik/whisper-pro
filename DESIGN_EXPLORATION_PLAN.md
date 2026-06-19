# Whisper Pro — Design Exploration (Zdenek, 2026-06-14)

Tři nezávislé úkoly, generované paralelně přes workflow (~46 agentů, Opus, max effort).
Integraci do switcherů + build dělám sám po workflow (delikátní, nesmí se rozbít).

## 1) Stickers — 10 nových tvarů
- Soubor: `Whisper Pro/Views/Dashboard/StickerAchievementBadge.swift`
- Co to je: holografický „foil" odznak (Pokémon-style sheen, 3D tilt) přes Sticker SPM balíček.
- Současný = `.v5` (blesk), tvar = uzavřený polygon normalizovaných bodů (0–1).
- Cíl: 10 NOVÝCH tvarů (`.v6`..`.v15`), různé tvary/styly (blesk, hvězda, štít, hexagon, diamant, bublina, equalizer, raketa, koruna, plamen).
- Switcher: dnes je `.v5` hardcoded všude → přidám runtime `@AppStorage` picker, ať je vidím v appce.
- V1 (jeho současný blesk `.v5`) zůstává netknutý.

## 2) Floating panel — 10 nových variant
- Jeho současný panel = V1, NETKNUTÝ. Přidávám jen nové soubory (V4+).
- Každá varianta = vlastní nový Swift soubor, musí splnit přesný kontrakt (context/init) co čte switcher.
- 10 distinct směrů: minimal pill, glass orb, Raycast spotlight bar, waveform-centric, dynamic-island/notch, assistant card, terminal/mono, neumorphic soft, vertical ticker, status HUD.
- Switcher: zaregistruju nové case do enumu + view-builderu (dělám sám).

## 3) Dashboard — 2 zcela nové směry (fresh)
- 2 nové layouty vedle Compact/Spotlight/Image, nic z toho neměním.
- Směr A „Command center" — bento grid, data-dense, Linear-style, velké statistiky + aktivita.
- Směr B „Calm/editorial" — vzdušné, typografií vedené, deníkový feed diktování.

## Postup
1. Workflow: Map (panel+dashboard struktura) → paralelní generace (stickery=data, panely+dashboardy=soubory) → každá varianta projde review/refine.
2. Já po workflow: zapojím switchery, přidám sticker picker, `xcodebuild` build, opravím chyby, screenshot ukázek.
3. Report: jak mezi nimi v appce přepínat.

## Pravidla
- Nic existujícího nemazat/nemeasit (jen přidávat). V1 panelu netknutý.
- Musí to zbuildit. Ověřím reálným buildem, ne jen tvrzením.
