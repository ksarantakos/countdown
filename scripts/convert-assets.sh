#!/usr/bin/env bash
# One-off: converts the source AVIF icon into the committed PNG + icns.
# Normal builds use the committed outputs and never need the AVIF.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-$HOME/Downloads/icon_512x512.avif}"
[[ -f "$SRC" ]] || { echo "error: source icon not found: $SRC" >&2; exit 1; }

sips -s format png "$SRC" --out Sources/WoWCountdown/Resources/AppIcon.png >/dev/null

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  if (( double <= 512 )); then
    sips -s format png -z "$double" "$double" "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  fi
done
iconutil -c icns "$ICONSET" -o Packaging/AppIcon.icns
echo "wrote Sources/WoWCountdown/Resources/AppIcon.png and Packaging/AppIcon.icns"
