# Whisper Pro — Dashboard redesign + app-wide theming

Date: 2026-06-13
Branch: `dashboard-theming`

## Goal

The dashboard's blue gradient hero banner reads like an ad. Replace it with mobile/top-tier-inspired
layouts, and add an app-wide theme + font system the user can flip live from a control bar above the dashboard.

Success = builds clean (`xcodebuild ... CODE_SIGNING_ALLOWED=NO`), every skin × layout renders in an Xcode
`#Preview` gallery, switching is live (no restart), and two review agents find no critical issues.

## A. Theme engine (app-wide)

New `ThemeManager: ObservableObject`, persisted via `@AppStorage`, injected at root in `WhisperPro.swift`.

Two axes:

### Skin (single picker — 4 options)
| Skin | colorScheme | background | surface/card | primary text | secondary | accent | border |
|------|------------|-----------|--------------|-------------|-----------|--------|--------|
| **Light** | .light | system | system | system | system | system blue | system |
| **Dark** | .dark | system | system | system | system | system blue | system |
| **Warm** (Claude béžová) | .light | `#F4F3EE` | `#EBEBDF` | `#1A1916` | `#7A7870` | `#DA7756` | `#D3D1C7` |
| **Midnight** (deep navy) | .dark | `#0C1120` | `#18181B` | `#F8FAFC` | `#8895A7` | `#3A82F6` | `#1E293B` |

- Light/Dark = native semantic colors (ThemeManager returns `nil` overrides → app looks stock).
- Warm/Midnight = custom hex palette via `Color(hex:)` helper.
- Root wiring: `.preferredColorScheme(skin.colorScheme)`, `.tint(skin.accent)` (recolors all
  `Color.accentColor` usage app-wide for free), root/window `background(skin.background)`.

### Font (single picker — 2 options)
| Font | Maps to | Notes |
|------|---------|-------|
| **System** | SF Pro (`.default` design) ≈ Inter | default |
| **Rounded** | SF Pro Rounded (`.rounded` design) ≈ Geist | softer |

- App-wide via root `.fontDesign(themeManager.fontDesign)`. This auto-switches every
  `.font(.system(size:weight:))` that does NOT hardcode a `design:`.
- Phase-0 audit: count `.font(.system(... design:` usages. Fonts that explicitly pass
  `.monospaced` or `.serif` MUST stay untouched (timers, code). Explicit `.default`/`.rounded`
  ones get converted to no-design so the env modifier controls them.
- Tracking: applied on large display type in the dashboard variants — big numbers `-1px`,
  small labels `+0.1px`. Body text app-wide stays default (global per-size tracking is out of scope).

## B. Theme control bar

A clean strip above the dashboard content (in `DashboardContent.swift` / `DashboardView.swift`):
- Skin picker: Light · Dark · Warm · Midnight (segmented or swatch row).
- Font picker: System · Rounded.
- Reads/writes `ThemeManager`. Replaces the temporary V1/V2/V3 picker.

## C. Three new dashboard layouts (replace V1/V2/V3)

Grounded in Mobbin research (Opal, Vocabulary, 5 Minute Journal, Spotify, Tonal):
- **V4 — Recap list** (Opal): hero "time saved" as big number, the 4 stats as clean stacked
  rows (big number left, small label under), no card-ad feel.
- **V5 — Featured + grid** (Vocabulary / 5MJ): one full-width hero card (time saved), then the
  4 stats in a compact 2×2 grid with neutral fills, no shadow.
- **V6 — Display hero** (Spotify / Tonal): giant display number, unit baseline-aligned beside it,
  generous whitespace, minimal — stats below in a quiet row.

All three read theme colors and apply correct tracking. A small V4/V5/V6 picker stays for now
(separate from the theme bar) so the user can choose; once chosen, collapse to the winner.

## D. Evals / verification

Native macOS app → no headless screenshot. Verification gates:
1. `xcodebuild -scheme "Whisper Pro" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` → BUILD SUCCEEDED.
2. `#Preview` gallery view rendering every layout (V4/V5/V6) × every skin (Light/Dark/Warm/Midnight)
   — user eyeballs in Xcode canvas.
3. Reality Checker agent: diff vs this spec checklist.
4. Code review agent: correctness of ThemeManager wiring + font migration (no broken monospaced fonts).

## Out of scope
- Bundled font files (user chose system-similar fonts).
- Global per-size tracking on body text.
- Re-skinning every deep system surface (translucent cards over warm/midnight bg are acceptable).
