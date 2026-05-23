# Path of Building (PoE2) — macOS Apple Silicon runtime

Native macOS arm64 runtime for Path of Building (PoE2 community fork).

## Quick start

```
git clone --recursive https://github.com/nelkonandparker/PathOfBuilding-PoE2.git
cd PathOfBuilding-PoE2/runtime-macos
./sign.sh
./pob2 Launch.lua
```

## What's in here

- `pob2` — small launcher that loads `libSimpleGraphic.dylib` and runs `Launch.lua`.
- `*.dylib` — SimpleGraphic engine + dependencies, built for arm64.
- `lua/` — PoB's Lua modules (xml, sha1, etc.).
- `Assets/`, `Classes/`, `Data/`, `Export/`, `Modules/`, `TreeData/` — symlinks to `../src/` (PoB's main Lua/data tree).
- `launcher.c` — source for the launcher, in case you want to rebuild it:
  ```
  clang -O2 launcher.c -o pob2 -L. -lSimpleGraphic -Wl,-rpath,@executable_path
  ./sign.sh
  ```

## Signing

After cloning, or after `git pull` updates any binary, run `./sign.sh`. It adhoc-signs everything with a self-issued signature so Gatekeeper allows it. No Apple developer account required.

## Updating

`git pull`, then re-run `./sign.sh` if any `.dylib` or `pob2` changed.

PoB's in-app updater targets the Windows release; dismiss its "Update check failed" popup on macOS.
