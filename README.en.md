# D2 Survivors QoL Patch (D2S-MyPatch)

[한국어](README.md) | **English**

**Current patch: v1.50 · for game build 2026.1101.1** (previous build 2026.1030.2 also works)

An unofficial quality-of-life patch that makes farming in D2 Survivors much easier.
A **single bat file** handles feature selection, patching, restoring the original, and auto-updates.
The patch UI follows your Windows language (Korean / English).

> ⚠ While patched, your runs are **not sent to the leaderboard**. Restore the original before playing for the leaderboard.
> This is an unofficial patch. Back up your save (`%APPDATA%\D2 Survivors\save`) before first use.

## Download / Install

1. **[Download D2S-MyPatch.bat](https://github.com/mastree-master/D2S-MyPatch/raw/main/D2S-MyPatch.bat)** (save it anywhere and keep it there)
2. Close the game and run the bat → if "Windows protected your PC" appears, click **More info → Run anyway**
3. Check the features you want → **Apply checked** → start the game

To undo: run the bat → **Restore original**.

![Feature selection](docs/gui.png)

## Auto-update

When a new version is released, a notice appears at the bottom right of the game. Click it → **Yes**: the game closes, the patcher opens, and the game restarts after applying.
If the game itself updates, the patch is removed automatically. Run the bat again and it **re-applies only what still works** on the new game version and tells you what doesn't.

![Update notice](docs/update-notice.png)

## Main features

![In game](docs/play.webp)
Top bar (version · enabled features · speed · FPS), HUD layout top-left, run info top-right, pickup log and upgrade popup

### Automatic item handling
- Items, gold and chests are picked up instantly at any distance
- New uniques / sets / runewords are **auto-stashed**; better copies **auto-upgrade** (skills > aura/proc > other stats > defense)
- Runewords only upgrade within the same weapon type, one-handed preferred, duplicates sorted per type
- Charms with skills go to the stash, everything else is auto-sold
- When the inventory is full, items go to the stash

### Pickup log (chat style)
- Time · stashed / upgraded / bag / stash / sold, scroll back with the mouse wheel
- Hover a line for item stats (game colors); upgrades show **only changed stats, old (red) → new (green)**
- Unique/set upgrades can be undone
- Drag to move, resize from the corner

![Item stats on hover](docs/log-hover.webp)

### AFK mode (F8)
Black screen showing only elapsed time · game time · runs · wave · gold · stashed/upgraded/kept/sold counts. Keeps running when minimized.

![AFK mode](docs/afk.webp)

### Runeword list (F4)
Every runeword read from the game data: runes · level · item types, **fixed stats (grey) / variable stats min~max (yellow)**, search.

![Runeword list](docs/runewords.webp)

### More
- Auto-enter portal; after a clear, repeat the same tier or go up one tier
- Game speed 1 / 1.5 / 2 / 3x (F7)
- Character / inventory / skill panels don't pause the game, B opens the stash, Ctrl+click sends to stash
- Compare boxes next to tooltips show where copies are; hidden values shown. Hold **Shift** to list every copy (stash / personal / shared tabs / inventory)
- Brightness / contrast (PageUp·PageDown / Home·End), hide corpses, render resolution, FPS display (F9) and cap
- HUD layout: pets and skills one row each top-left, run info top-right
- Top bar shows version · game build · enabled features (✓/✗)

### Compare boxes · Stash
![Find runeword copies (Shift)](docs/shift-compare.webp)
![B stash](docs/stash.webp)

### Guide (F6) · Patch log (F10)
![Guide](docs/guide.webp)
![Patch log](docs/patchlog.webp)

## Hotkeys

| Key | Action |
|---|---|
| F6 | Guide |
| F4 | Runeword list |
| F3 | Drop chance calculator |
| F2 | Keep settings (sell / bag / stash per item, registered count) |
| F10 | Patch log |
| F7 | Game speed |
| F8 | AFK mode |
| F9 | FPS display |
| Shift (over an item) | Show every copy |
| B | Stash |
| Ctrl+click | Send inventory item to stash |
| PageUp / PageDown | Brightness |
| Home / End | Contrast |

## Font (optional)
Put `kodia.ttf` next to the bat and patch to replace the game font with it. (Font not included.)

## Notes
- Game numbers (damage, gold, stats) are not changed. Game speed only makes runs go faster.
- Screenshots show the Korean UI.
