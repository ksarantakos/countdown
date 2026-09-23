#!/usr/bin/env bash
# Builds WoWCountdown.app (with its widget extension) into dist/, zips it, and installs it to ~/Applications.
#
#   ./build.sh               Apple Silicon (arm64), signed with the team in Config/Local.xcconfig
#   ./build.sh --universal   arm64 + x86_64; fails if either architecture is missing
#   ./build.sh --adhoc       ad-hoc signing, for local experiments only
#   ./build.sh --no-install  skip installing to ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="WoWCountdown"
BUNDLE_ID="com.ksarantakos.wowcountdown"

UNIVERSAL=0
INSTALL=1
ADHOC=0
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    --no-install) INSTALL=0 ;;
    --adhoc) ADHOC=1 ;;
    *) echo "error: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Prefer full Xcode when the active developer directory is the Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" && "$(xcode-select -p)" == *CommandLineTools* && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  echo "note: using DEVELOPER_DIR=$DEVELOPER_DIR (xcode-select points at the Command Line Tools)"
fi

command -v xcodegen >/dev/null || { echo "error: xcodegen not found (brew install xcodegen)" >&2; exit 1; }

SIGNING_ARGS=()
if (( ADHOC )); then
  echo "note: ad-hoc signing (--adhoc); not for distribution"
  SIGNING_ARGS=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
elif ! grep -qE '^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*[A-Z0-9]{10}' Config/Local.xcconfig 2>/dev/null; then
  cat >&2 <<'MSG'
error: no signing team configured.
  Create Config/Local.xcconfig containing:
    DEVELOPMENT_TEAM = <your 10-character team ID>
  (Xcode → Settings → Accounts shows your teams.) Or pass --adhoc for a local-only build.
MSG
  exit 1
else
  SIGNING_ARGS=(-allowProvisioningUpdates)
fi

ARCHS="arm64"
(( UNIVERSAL )) && ARCHS="arm64 x86_64"

xcodegen generate --quiet
DERIVED=".build/xcode"
echo "==> xcodebuild (Release, $ARCHS)"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$DERIVED" ARCHS="$ARCHS" ONLY_ACTIVE_ARCH=NO \
  "${SIGNING_ARGS[@]}" -quiet build

BUILT="$DERIVED/Build/Products/Release/$APP_NAME.app"
APPEX="$BUILT/Contents/PlugIns/${APP_NAME}Widget.appex"
[[ -d "$APPEX" ]] || { echo "error: widget extension missing from $BUILT" >&2; exit 1; }

for binary in "$BUILT/Contents/MacOS/$APP_NAME" "$APPEX/Contents/MacOS/${APP_NAME}Widget"; do
  actual="$(lipo -archs "$binary")"
  for arch in $ARCHS; do
    [[ " $actual " == *" $arch "* ]] || { echo "error: $binary is missing $arch (has: $actual)" >&2; exit 1; }
  done
done
codesign --verify --deep --strict "$BUILT"

rm -rf "dist/$APP_NAME.app" "dist/$APP_NAME.app.zip"
mkdir -p dist
ditto "$BUILT" "dist/$APP_NAME.app"
ditto -c -k --keepParent "dist/$APP_NAME.app" "dist/$APP_NAME.app.zip"
echo "==> built dist/$APP_NAME.app ($(lipo -archs "dist/$APP_NAME.app/Contents/MacOS/$APP_NAME")) and dist/$APP_NAME.app.zip"

if (( INSTALL )); then
  if pgrep -xq "$APP_NAME"; then
    echo "==> quitting running $APP_NAME"
    osascript -e "quit app id \"$BUNDLE_ID\"" || true
    for _ in {1..20}; do pgrep -xq "$APP_NAME" || break; sleep 0.25; done
    if pgrep -xq "$APP_NAME"; then echo "error: $APP_NAME is still running; quit it and retry" >&2; exit 1; fi
  fi
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP_NAME.app"
  ditto "dist/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app"
  # Register the app (and its widget extension) with LaunchServices.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Applications/$APP_NAME.app"
  # The widget extension is a stateless service macOS relaunches on demand; stop any old
  # instance so the new build renders instead of the previous binary.
  if pkill -x "${APP_NAME}Widget"; then echo "==> stopped the previous widget extension"; fi
  echo "==> installed to ~/Applications/$APP_NAME.app"
fi
