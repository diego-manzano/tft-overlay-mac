# TFT Overlay for Mac

A native macOS overlay for Teamfight Tactics — like MetaTFT/Blitz on Windows, but built for the Mac. Floating always-on-top panel with meta comps, augment tiers, item stats, shop odds, and a rolldown hit calculator. Minimal dark UI, lives in the menu bar.

**Vanguard-safe by design**: the app never reads game memory, injects code, or touches the game process. It only reads the League client's local lockfile (the same LCU API the client exposes for everyone) to know when a game is running, and ships with bundled static meta data.

## Features

- **Comps** — current meta comps with average placement, play-style badges (Reroll / Fast 9), 3★ carry indicators, best-in-slot items, and recommended augments. Search and filter.
- **Augments** — tier list (S–D) with silver/gold/prismatic filter.
- **Items** — average placement and top-4 rate, filterable by category (completed, radiant, artifact, emblem, component).
- **Odds** — shop odds by level, pool bag sizes per cost, and a **hit calculator**: pick a champ, enter how many copies are gone, and it tells you the chance per shop and the gold a rolldown will cost (50/80/95% confidence). Hover the ⓘ marks for explanations.
- Auto-shows when a TFT game starts, hides when it ends (toggleable).
- Global hotkey **⌥Space** to show/hide. Click-drag anywhere on the panel to move it, drag edges to resize.

## Install

Requirements: **macOS 14 or later** (Apple Silicon or Intel).

1. Download `TFTOverlay.zip` from the [latest release](../../releases/latest) and unzip it.
2. Drag `TFTOverlay.app` into `/Applications`.
3. The app is ad-hoc signed (no paid developer certificate), so macOS quarantines it on first launch. Either:
   - **Right-click** the app → **Open** → **Open** in the dialog, or
   - run `xattr -cr /Applications/TFTOverlay.app` in Terminal, then open it normally.
4. Look for the gold stack icon in your menu bar. Press **⌥Space** to toggle the overlay.

> **Important:** League must run in *borderless* (or windowed) mode, not exclusive fullscreen — otherwise no overlay can draw above the game.

## Build from source

```bash
brew install xcodegen
git clone https://github.com/diego-manzano/tft-overlay-mac.git
cd tft-overlay-mac
xcodegen generate
xcodebuild -project TFTOverlay.xcodeproj -scheme TFTOverlay -configuration Release build
```

The app lands in `build/` (or DerivedData if you build from Xcode).

## Refreshing the meta data

Meta data (comps, augment tiers, item stats, shop odds, bag sizes) is snapshotted into the app bundle at build time. To pull the latest patch's data:

```bash
python3 scripts/build_snapshot.py   # downloads data + champion/item icons
xcodegen generate && xcodebuild ...  # rebuild
```

Sources: [CommunityDragon](https://communitydragon.org) for static game data and icons, MetaTFT's public endpoints for tier lists and comp stats.

## How game detection works

The League client writes a `lockfile` with a local API port and password. The app polls `/lol-gameflow/v1/gameflow-phase` over localhost and checks for the TFT game process to know when to auto-show. That's it — no screen capture, no memory reading, no input hooks.
