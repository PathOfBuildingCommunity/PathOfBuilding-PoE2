# Path of Building (PoE2) — Native macOS Port
## An offline build planner for Path of Exile 2, running natively on Apple Silicon macOS.

> **Side project notice:** This is a personal side project. It may contain bugs and is not officially supported. I use this app actively and will keep it updated as best I can. Feedback, bug reports, and contributions are very welcome — thank you!

This is a **native macOS (Apple Silicon) port** of [Path of Building Community for Path of Exile 2](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2).

It keeps the original Lua application and the entire calculation engine **unchanged** — every offence/defence calculation, the passive tree, items, skills and import/export logic are identical to the upstream project. Only the Windows-only SimpleGraphic runtime has been replaced with a native macOS host (SDL3 + LuaJIT + a bitmap font/DDS renderer), so it runs as a real `.app` instead of through Wine/CrossOver or the Windows `.exe`.

## ⬇️ Download
**[Download the latest release](https://github.com/stevep51/PathOfBuilding-PoE2-MacOS/releases/latest)** — grab `PathOfBuilding-PoE2-macos-arm64.zip` from the assets, unzip, and move **Path of Building (PoE2).app** to your Applications folder. See [Install](#install) below for the first-launch (Gatekeeper) step.

## Requirements
- Apple Silicon Mac (arm64)
- macOS 13 (Ventura) or newer

## Install
Download the latest `PathOfBuilding-PoE2-macos-arm64.zip` from the [Releases page](https://github.com/stevep51/PathOfBuilding-PoE2-MacOS/releases/latest), unzip it, and move **Path of Building (PoE2).app** to your Applications folder. On first launch, macOS Gatekeeper may require you to right‑click the app and choose **Open** (it is not notarized).

Your builds and settings are stored under:
`~/Library/Application Support/Path of Building (PoE2)/`

## Is it safe? (account sign-in & privacy)
Yes — and you don't have to take that on faith. This app talks **only** to
Grinding Gear Games' official servers, has no telemetry, and never sends your
account, tokens, or builds to anyone. Sign-in is optional and uses the standard
OAuth + PKCE flow: you log in on `pathofexile.com` in your browser, and the app
never sees your password. See **[SECURITY.md](SECURITY.md)** for the full
breakdown (including how to verify or build the app yourself).

## Features
* Comprehensive offence + defence calculations:
  * Calculate your skill DPS, damage over time, life/mana/ES totals and much more!
  * Can factor in auras, buffs, charges, curses, monster resistances and more, to estimate your effective DPS
  * Also calculates life/mana reservations
  * Shows a summary of character stats in the side bar, as well as a detailed calculations breakdown tab
  * Supports all skills and support gems, and most passives and item modifiers
  * Full support for minions, party play and support builds
* Passive skill tree planner:
  * Support for jewels including most radius/conversion and timeless jewels
  * Alternate path tracing (mouse over a sequence of nodes while holding shift, then click to allocate them all)
  * Fully integrated with the offence/defence calculations
  * Can import PathOfExile.com and PoEPlanner.com passive tree links
* Skill planner: add any number of main or supporting skills; toggle auras/curses/buffs on and off
* Item planner: paste items straight from the game, search trade, craft items, and browse a unique/rare database
* Import your characters directly from your Path of Exile account (OAuth sign-in)
* Share builds with other Path of Building users via build codes

## Building from source
See **[docs/macos.md](docs/macos.md)** for full build/package instructions. In short:

```bash
brew install cmake ninja sdl3 luajit curl zlib zstd
tools/macos/build_app.sh      # builds build/macos-arm64/PathOfBuilding-PoE2.app
tools/macos/package_app.sh    # produces dist/macos-arm64/PathOfBuilding-PoE2-macos-arm64.zip
```

## What's different from upstream
The calculation engine, data, passive tree, skills, items and UI logic are **unchanged**. The changes below are what make it run natively on macOS:

- **Native macOS host** (`macos/`) replaces the Windows-only SimpleGraphic runtime: a Cocoa + SDL3 window with layer-correct draw ordering, a bitmap font renderer, DDS/TGA texture decoders, libcurl-backed HTTPS downloads, a loopback OAuth sign-in server, and background sub-scripts. The app loads its bundled Lua from inside the `.app` (`Contents/Resources`), falling back to the source tree when run from a checkout.
- **macOS-native conventions:** keyboard shortcuts use `Cmd` (e.g. `Cmd`+1–7 to switch tabs, `Cmd`+S to save, `` Cmd+` `` for the console), and user data is stored under `~/Library/Application Support/Path of Building (PoE2)/` instead of the Windows path.
- **Windows runtime removed:** the `.exe`/`.dll` binaries are not shipped. Only the shared Lua sources, fonts (`runtime/SimpleGraphic/Fonts`) and Lua libraries (`runtime/lua`) are retained.
- **Updates:** there is no in-app auto-updater on macOS. The **Check for Update** button instead opens the [Releases page](https://github.com/stevep51/PathOfBuilding-PoE2-MacOS/releases) so you can download the newest build, and each release ships a SHA-256 checksum to verify the download (see [SECURITY.md](SECURITY.md)). The **About** dialog links to this repository.
- **Versioning:** releases keep the upstream engine version and add a macOS build counter (e.g. tag `v0.16.0-macos.1`), shown in-app as `Version: 0.16.0` above `macOS Port (build 1)`. See [RELEASE.md](RELEASE.md) for the scheme.

## Changelog
You can find the full version history [here](CHANGELOG.md).

## Credits
This port stands entirely on the work of the **[Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2)** team, who created and maintain Path of Building and the PoE2 fork. All calculation logic, data and UI are theirs.

## Licence
[MIT](https://opensource.org/licenses/MIT)

For 3rd-party licences, see [LICENSE](LICENSE.md). The licensing information is considered to be part of the documentation.
