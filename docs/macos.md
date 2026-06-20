# Native macOS Apple Silicon Runtime

The macOS port keeps Path of Building's Lua application and calculation engine
unchanged. The native app replaces only the Windows-only SimpleGraphic runtime
bundle with a macOS host that exposes the same Lua globals used by
`src/Launch.lua`.

## Requirements

- Apple Silicon Mac
- macOS 13 or newer
- Homebrew packages: `cmake`, `ninja`, `sdl3`, `luajit`, `curl`, `zlib`, `zstd`

## Build

```bash
brew install cmake ninja sdl3 luajit curl zlib zstd
tools/macos/build_app.sh
```

The build writes `build/macos-arm64/PathOfBuilding-PoE2.app`.

## Package

```bash
tools/macos/package_app.sh
```

The package step creates `dist/macos-arm64/PathOfBuilding-PoE2-macos-arm64.zip`
and refreshes `runtime-macos-arm64/` so `update_manifest.py` can include the
native runtime as `platform="macos-arm64"`.

## Tests

The existing calculation and feature tests remain the authority for parity:

```bash
docker-compose up
```

For local LuaJIT environments:

```bash
cd src
luajit HeadlessWrapper.lua
cd ..
busted --lua=luajit
```

Before release, verify the native host manually:

- Launches to an unnamed build
- Can resize and redraw the window
- Can paste/import and generate/share build codes
- Opens browser links and trade/wiki URLs
- OAuth redirect server completes account authentication
- Saves builds under `~/Library/Application Support/Path of Building (PoE2)`

## Runtime behaviour

- User data (builds, settings, cached API responses) is stored under
  `~/Library/Application Support/Path of Building (PoE2)/`.
- The packaged manifest tags the `<Version>` element with
  `platform="macos-arm64"`, so the app runs as a normal release rather than in
  developer mode.
- The in-app auto-updater is disabled on macOS (the Windows `Update.exe` runtime
  is not shipped). Update by downloading a newer release.

## Release Notes

The macOS artifact is native Apple Silicon. It does not use Wine, CrossOver, or
the Windows `.exe` runtime. The Windows runtime binaries (`.exe`/`.dll`) are not
part of this port; only the shared Lua sources, fonts
(`runtime/SimpleGraphic/Fonts`) and Lua libraries (`runtime/lua`) are retained.

