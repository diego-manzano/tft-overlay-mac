# TFT Overlay for macOS — Plan

A native Mac overlay for Teamfight Tactics: floats over the game, shows meta comps,
item cheat-sheets, and augment tiers — like MetaTFT/Blitz on Windows, but Mac-native,
lightweight, and in the same Notion-minimal design language as Latch.

## Ground rules (Vanguard safety)

Riot's anti-cheat (Vanguard, now on macOS) bans memory reading and process injection.
Everything here uses only approved surfaces:

| Allowed ✅ | Banned ❌ |
| --- | --- |
| LCU API (local client REST/WS via lockfile) | Reading game process memory |
| Screen capture + OCR/CV (pixels) | Injecting code / hooking the game |
| Static data from CommunityDragon / Data Dragon | Automating inputs (scripting) |

An overlay window on macOS is just a floating `NSPanel` — no injection needed, unlike Windows.

## Architecture

```
TFTOverlay.app (SwiftUI + AppKit, macOS 14+)
├── OverlayWindow      NSPanel: borderless, .screenSaver level, transparent,
│                      .canJoinAllSpaces + .fullScreenAuxiliary, click-through
│                      except interactive zones
├── LCUClient          Finds League lockfile → local HTTPS/WSS (self-signed cert
│                      trust override) → subscribes to gameflow phase events
│                      lockfile: /Applications/League of Legends.app/Contents/LoL/lockfile
├── MetaStore          Static TFT data for current set: comps, augments, items
│                      (CommunityDragon JSON + curated tier data; cached, refresh daily)
├── Panels (SwiftUI)   Comps browser · Item cheat-sheet (BiS combos) ·
│                      Augment tier lookup · Settings
└── HotkeyManager      Global shortcut (e.g. ⌥Space) to show/hide overlay
```

## Milestones

### M1 — Floating overlay shell (an afternoon)
- Menu-bar app (no Dock icon), global hotkey toggles overlay panel
- Overlay floats above fullscreen games, remembers position/size
- Notion-style UI kit ported from Latch (paper/ink palette, emoji rows)
- **Exit criteria:** panel visibly floats over any fullscreen app, toggles cleanly

### M2 — Static meta panels (the useful core, no League needed to build)
- Pull current-set data from CommunityDragon; bundle a fallback snapshot
- Comps list: tier → comp → units/traits/positioning thumbnail
- Item cheat-sheet: component grid → best combined items per carry
- Augment tier table with search
- **Exit criteria:** usable as a manual reference during a real game

### M3 — League client awareness (needs League installed)
- LCUClient: lockfile discovery, auth, WebSocket `/lol-gameflow/v1/gameflow-phase`
- Auto-show overlay when a TFT game starts, auto-hide in lobby/out of game
- Show queue/lobby state in menu bar
- **Exit criteria:** overlay appears by itself when a TFT game begins

### M4 — Stretch: board/shop vision (the hard 20%)
- ScreenCaptureKit capture of the game window (needs Screen Recording permission)
- CV/OCR (Vision.framework) to read shop units → highlight units your comp wants
- Opponent scouting summary during carousel/combat
- **Exit criteria:** shop highlighting works at 1080p+ default HUD scale
- Risk: HUD-scale/resolution variance; ship M1–M3 first, this is v2 territory

## Data sources

- **CommunityDragon** — `raw.communitydragon.org` TFT set data (units, traits, items, augments)
- **Data Dragon** — official static assets/icons
- Comp tiers: start with a hand-curated JSON (editable in-app); scraping MetaTFT is
  ToS-gray — revisit later

## Risks / open questions

- LCU API surface for TFT specifically is thinner than for SR — M3 scope may narrow
  to gameflow events only (that's still enough for auto-show/hide)
- Vanguard macOS behavior around screen recording of the game window — believed fine
  (pixels not memory), verify on a real match before investing in M4
- League reinstall ~25–30 GB; disk currently has ~52 GB free → OK

## Non-goals (v1)

- Windows support, match history analytics, account stats, double-up voice comms —
  MetaTFT already does stats sites well; this is a *live reference overlay*, nothing more.
