#!/usr/bin/env bash
# Downloads Godot 4.7.2 (Standard, Linux) and, with --templates, the export templates.
# Installs into ~/.cache/sengoku/ and prints the binary path. Safe to re-run.
set -euo pipefail
VERSION="4.7.2"
CACHE="${SENGOKU_CACHE:-$HOME/.cache/sengoku}"
BIN="$CACHE/Godot_v${VERSION}-stable_linux.x86_64"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
mkdir -p "$CACHE"
if [ ! -x "$BIN" ]; then
  echo "Downloading Godot ${VERSION}..." >&2
  curl -sSL -o "$CACHE/godot.zip" "$URL/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -oq "$CACHE/godot.zip" -d "$CACHE" && rm "$CACHE/godot.zip"
  chmod +x "$BIN"
fi
if [ "${1:-}" = "--templates" ]; then
  TPL="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
  if [ ! -f "$TPL/windows_release_x86_64.exe" ]; then
    echo "Downloading export templates (~1 GB)..." >&2
    curl -sSL -o "$CACHE/templates.tpz" "$URL/Godot_v${VERSION}-stable_export_templates.tpz"
    mkdir -p "$TPL" && unzip -oq "$CACHE/templates.tpz" -d "$CACHE/tpl"
    cp "$CACHE"/tpl/templates/* "$TPL/" && rm -rf "$CACHE/tpl" "$CACHE/templates.tpz"
  fi
fi
echo "$BIN"
