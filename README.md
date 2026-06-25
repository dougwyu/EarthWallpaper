# EarthWallpaper

A macOS menu bar app that sets your desktop wallpaper to a live map of Earth, showing the day/night terminator in real time. Add cities to see their local times as labels on the map — a world clock you reveal with one keystroke.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue)

## What it does

- Renders a flat map of Earth with accurate day/night shading, updated on a schedule you choose
- Lets you pin cities by name — each one appears on the map with its current local time
- Lives in the menu bar; press your Show Desktop key (e.g. F12) to glance at the map, then return to work

## Requirements

- macOS 13 Ventura or later
- [Homebrew](https://brew.sh)
- xplanet — install with `brew install xplanet`
- Xcode 15 or later (for the build step)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — install with `brew install xcodegen`

## Installation

```bash
git clone https://github.com/yourusername/EarthWallpaper.git
cd EarthWallpaper
./install.sh
```

`install.sh` generates the Xcode project, builds a Release binary, copies the app to `/Applications/`, and launches it.

If macOS shows a Gatekeeper warning ("app from unidentified developer"), go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Usage

1. Click the **globe icon** (🌎) in the menu bar to open the panel
2. Click **Settings** to add cities and configure the update interval
3. Type a city name (e.g. `Tokyo`, `London`, `New York`) and click **Add** — the app geocodes the name automatically, no API key needed
4. Click **Update Now** to regenerate the wallpaper immediately
5. Assign a **Show Desktop** shortcut in **System Settings → Keyboard → Keyboard Shortcuts → Mission Control → Show Desktop** (e.g. F12) to reveal the map with one key

The wallpaper updates automatically on the interval you set (default: every 5 minutes).

## Configuration

All settings are in the Settings panel:

| Setting | Default | Description |
|---|---|---|
| Cities | (none) | Cities to label on the map with local time |
| Update interval | 5 minutes | How often xplanet rerenders the wallpaper (1–60 min) |

Settings persist across restarts via `UserDefaults`.

## How it works

EarthWallpaper is a thin Swift/SwiftUI wrapper around [xplanet](https://xplanet.sourceforge.net/). On each update cycle it:

1. Writes a marker file listing each city's coordinates and local time
2. Runs `xplanet` with `--projection rectangular` to produce a PNG sized to your screen
3. Sets the PNG as the desktop wallpaper via `NSWorkspace`

City coordinates are resolved via Apple's `CLGeocoder` (no location permission required — it uses the network, not device location).

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
