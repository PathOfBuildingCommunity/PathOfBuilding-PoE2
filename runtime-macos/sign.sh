#!/bin/bash
# Adhoc-sign all macOS binaries in this directory. Required after a fresh clone
# or after `git pull` updates the binaries — macOS Gatekeeper refuses to load
# unsigned dylibs into signed binaries.
cd "$(dirname "$0")"
for f in pob2 *.dylib; do
    [ -f "$f" ] || continue
    codesign --force --sign - "$f"
done
echo "signed."
