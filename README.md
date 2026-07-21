# EarthWallpaper

A macOS menu bar app that fills your desktop with a live map of Earth, showing the day/night terminator in real time. Add cities to see their local times as bright labels on the map — a world clock you reveal with one keystroke.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue)

## What it does

- Renders a flat map of Earth with accurate day/night shading, refreshed on a schedule you choose
- Lets you pin cities by name — each appears on the map as a yellow marker with its current local time
- Shows the current moon phase (name and % illumination) as an inset on the map and in the menu bar dropdown
- Marks where the Sun and Moon are directly overhead — a sun glyph at the subsolar point and a mini phase disc at the sublunar point, moving across the map in real time
- Lives in the menu bar; use the Show Desktop trackpad gesture (or key) to glance at the map, then return to work

## Requirements

- macOS 13 Ventura or later
- [Homebrew](https://brew.sh)
- xplanet — install with `brew install xplanet` (required at runtime, not just to build)
- Xcode 15 or later (for the build step)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install with `brew install xcodegen`

## Installation

```bash
git clone https://github.com/dougwyu/EarthWallpaper.git
cd EarthWallpaper
./install.sh
```

`install.sh` generates the Xcode project, builds a Release binary, copies the app to `/Applications/`, refreshes the icon cache, and launches it.

If macOS shows a Gatekeeper warning ("app from unidentified developer"), go to **System Settings → Privacy & Security** and click **Open Anyway** — or run `xattr -dr com.apple.quarantine /Applications/EarthWallpaper.app`.

## Usage

1. Click the **globe icon** (🌎) in the menu bar to open the panel
2. Click **Settings** to add cities and set the update interval
3. Type a city name (e.g. `Tokyo`, `London`, `New York`) and click **Add** — the app geocodes the name automatically, no API key needed
4. Click **Update Now** to redraw the map immediately
5. Assign a **Show Desktop** shortcut in **System Settings → Keyboard → Keyboard Shortcuts → Mission Control → Show Desktop** (e.g. F12) to reveal the map with one key

The map refreshes automatically on the interval you set (default: every 5 minutes; set it to 1 minute for a live clock).

## Configuration

All settings are in the Settings panel:

| Setting | Default | Description |
|---|---|---|
| Cities | (none) | Cities to label on the map with their local time |
| Update interval | 5 minutes | How often the map is re-rendered (1–60 min) |

Settings persist across restarts via `UserDefaults`.

## How it works

EarthWallpaper is a thin Swift/SwiftUI wrapper around [xplanet](https://xplanet.sourceforge.net/). On each update cycle it:

1. Runs `xplanet` with `-projection rectangular` to produce a full-Earth PNG sized to your screen, with accurate day/night shading. This base map is cached and only re-rendered every ~10 minutes — the terminator barely moves per minute, so re-rendering each tick would be wasted work.
2. Draws the annotation layer on the cached base with Core Graphics — bright yellow city dots and `HH:MM` labels, plus a moon-phase inset (computed from a truncated Meeus series, verified against known eclipses). xplanet's own marker/text rendering is unreliable on some Homebrew builds, so the app renders all of this itself.
3. Displays the result in a borderless window pinned just below the desktop icons.

City coordinates and time zones are resolved via the free [Open-Meteo geocoding API](https://open-meteo.com/en/docs/geocoding-api) — no API key, and it works for cities worldwide.

### Why a window instead of the desktop picture?

The app does **not** change your macOS wallpaper. On macOS 14+ (and especially macOS 26) `NSWorkspace.setDesktopImageURL` updates the setting but often fails to repaint the screen on frequent updates, and unique-filename workarounds flood **Settings → Wallpaper → Your Photos**. Instead, EarthWallpaper draws into a window at the desktop layer (above the system wallpaper, below your icons), so it:

- repaints instantly every cycle,
- needs no permissions,
- leaves your Wallpaper settings untouched,
- is revealed by Show Desktop / Mission Control and shows on all Spaces, just like a wallpaper.

The update timer is aligned to minute boundaries so the clock stays accurate.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
