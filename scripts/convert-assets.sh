#!/usr/bin/env bash
# One-off: converts the source AVIF icon into the committed app icon set and menu icon.
# Normal builds use the committed outputs and never need the AVIF.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-$HOME/Downloads/icon_512x512.avif}"
[[ -f "$SRC" ]] || { echo "error: source icon not found: $SRC" >&2; exit 1; }

sips -s format png "$SRC" --out Sources/WoWCountdown/Resources/MenuIcon.png >/dev/null

SET=Sources/WoWCountdown/Assets.xcassets/AppIcon.appiconset
mkdir -p "$SET"
images=""
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale))
    suffix=""
    if (( scale == 2 )); then suffix="@2x"; fi
    name="icon_${size}x${size}${suffix}.png"
    # The source is 512 px; the 1024 px slot is upscaled.
    sips -s format png -z "$px" "$px" "$SRC" --out "$SET/$name" >/dev/null
    images+="{\"idiom\":\"mac\",\"size\":\"${size}x${size}\",\"scale\":\"${scale}x\",\"filename\":\"$name\"},"
  done
done
printf '{"images":[%s],"info":{"version":1,"author":"xcode"}}\n' "${images%,}" > "$SET/Contents.json"
printf '{"info":{"version":1,"author":"xcode"}}\n' > Sources/WoWCountdown/Assets.xcassets/Contents.json
echo "wrote $SET and Sources/WoWCountdown/Resources/MenuIcon.png"
