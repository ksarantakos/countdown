#!/usr/bin/env bash
# Builds WoWCountdown.app into dist/, ad-hoc signs it, zips it, and installs it to ~/Applications.
#
#   ./build.sh               Apple Silicon (arm64) build
#   ./build.sh --universal   arm64 + x86_64; fails if either architecture fails
#   ./build.sh --no-install  skip installing to ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="WoWCountdown"
BUNDLE_ID="com.ksarantakos.wowcountdown"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

UNIVERSAL=0
INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    --no-install) INSTALL=0 ;;
    *) echo "error: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Prefer full Xcode when the active developer directory is the Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p)" == *CommandLineTools* && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  echo "note: using DEVELOPER_DIR=$DEVELOPER_DIR (xcode-select points at the Command Line Tools)"
fi

ARCHS=(arm64)
(( UNIVERSAL )) && ARCHS+=(x86_64)

BINARIES=()
RESOURCE_BUNDLE=""
for arch in "${ARCHS[@]}"; do
  echo "==> swift build -c release --arch $arch"
  if ! swift build -c release --arch "$arch"; then
    echo "error: $arch build failed" >&2
    exit 1
  fi
  bin_dir="$(swift build -c release --arch "$arch" --show-bin-path)"
  BINARIES+=("$bin_dir/$APP_NAME")
  RESOURCE_BUNDLE="$bin_dir/${APP_NAME}_${APP_NAME}.bundle"
done

APP="dist/$APP_NAME.app"
echo "==> assembling $APP"
rm -rf "$APP" "dist/$APP_NAME.app.zip"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if (( ${#BINARIES[@]} > 1 )); then
  lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
else
  cp "${BINARIES[0]}" "$APP/Contents/MacOS/$APP_NAME"
fi

actual_archs="$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
for arch in "${ARCHS[@]}"; do
  if [[ " $actual_archs " != *" $arch "* ]]; then
    echo "error: binary is missing $arch (has: $actual_archs)" >&2
    exit 1
  fi
done

[[ -d "$RESOURCE_BUNDLE" ]] || { echo "error: resource bundle not found: $RESOURCE_BUNDLE" >&2; exit 1; }
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> signing (ad-hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "dist/$APP_NAME.app.zip"
echo "==> built $APP ($actual_archs) and dist/$APP_NAME.app.zip"

if (( INSTALL )); then
  if pgrep -xq "$APP_NAME"; then
    echo "==> quitting running $APP_NAME"
    osascript -e "quit app id \"$BUNDLE_ID\"" || true
    for _ in {1..20}; do pgrep -xq "$APP_NAME" || break; sleep 0.25; done
    if pgrep -xq "$APP_NAME"; then echo "error: $APP_NAME is still running; quit it and retry" >&2; exit 1; fi
  fi
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP_NAME.app"
  ditto "$APP" "$HOME/Applications/$APP_NAME.app"
  echo "==> installed to ~/Applications/$APP_NAME.app"
fi
