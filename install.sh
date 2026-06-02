#!/usr/bin/env bash
set -euo pipefail

# strict bash error handling
# -e: exit immediately if a command exits with a non-zero status
# -u: treat unset variables as an error and exit immediately
# -o pipefail: the return value of a pipeline is the status of the last command

if [[ $# -ge 1 ]]; then
  APP_PATH="$1"
else
  if [[ -d "./build/Build/Products/Debug/SwiftIMEStarter.app" ]]; then
    APP_PATH="./build/Build/Products/Debug/SwiftIMEStarter.app"
  elif [[ -d "./build/Build/Products/Release/SwiftIMEStarter.app" ]]; then
    APP_PATH="./build/Build/Products/Release/SwiftIMEStarter.app"
  elif [[ -d "./build/Release/SwiftIMEStarter.app" ]]; then
    APP_PATH="./build/Release/SwiftIMEStarter.app"
  else
    APP_PATH="./build/Build/Products/Debug/SwiftIMEStarter.app"
  fi
fi

DEST_DIR="/Library/Input Methods"
DEST_APP="$DEST_DIR/SwiftIMEStarter.app"
GUI_USER="${SUDO_USER:-$(stat -f%Su /dev/console)}"
GUI_UID="$(id -u "$GUI_USER")"
GUI_HOME="$(dscl . -read "/Users/$GUI_USER" NFSHomeDirectory | awk '{print $2}')"

run_as_gui_user() {
  launchctl asuser "$GUI_UID" sudo -u "$GUI_USER" "$@"
}

kill_gui_proc() {
  run_as_gui_user /usr/bin/killall -9 "$1" >/dev/null 2>&1 || true
}

refresh_gui_job() {
  local label="$1"
  if launchctl kickstart -k "gui/$GUI_UID/$label" >/dev/null 2>&1; then
    echo "Refreshed launchd job: $label"
  else
    echo "warning: failed to refresh launchd job: $label"
  fi
}

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found: $APP_PATH"
  echo "usage: $0 [path/to/SwiftIMEStarter.app]"
  exit 1
fi

echo "Installing from: $APP_PATH"
if [[ "${EUID}" -ne 0 ]]; then
  echo "error: installing to /Library/Input Methods requires sudo"
  echo "run: sudo $0 ${APP_PATH@Q}"
  exit 1
fi

mkdir -p "$DEST_DIR"
rm -rf "$DEST_APP"
cp -R "$APP_PATH" "$DEST_APP"
chown -R root:staff "$DEST_APP" || true
chmod -R 775 "$DEST_APP" || true
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST_APP/Contents/Info.plist")"
MODE_ID="$(/usr/libexec/PlistBuddy -c 'Print :ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey:0' "$DEST_APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "${MODE_ID}" ]]; then
  MODE_ID="${BUNDLE_ID}"
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTER_SWIFT_SCRIPT="$SCRIPT_DIR/scripts/register_input_source.swift"
SYNC_PREFS_SWIFT_SCRIPT="$SCRIPT_DIR/scripts/sync_input_source_prefs.swift"
WATCH_READY_SWIFT_SCRIPT="$SCRIPT_DIR/scripts/watch_input_source_ready.swift"

# try to refresh app registration system-wide
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
  run_as_gui_user "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

echo "Refreshing pasteboard cache before registration..."
kill_gui_proc "pboard"
run_as_gui_user rm -f "$GUI_HOME/Library/Caches/com.apple.tiswitcher.cache" >/dev/null 2>&1 || true

echo "Registering input source (Carbon TIS API) as user: $GUI_USER"
run_as_gui_user env \
  SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
  swift "$REGISTER_SWIFT_SCRIPT" "$DEST_APP" "$BUNDLE_ID" "$MODE_ID"

echo "Syncing input-source preference domains..."
run_as_gui_user env \
  SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
  swift "$SYNC_PREFS_SWIFT_SCRIPT" "$BUNDLE_ID" "$MODE_ID"

echo "Refreshing text input/session agents..."
# kill_gui_proc "TextInputMenuAgent"
# kill_gui_proc "TextInputSwitcher"
# kill_gui_proc "localizationswitcherd"
# kill_gui_proc "pboard"
# refresh_gui_job "com.apple.cfprefsd.agent"
# kill_gui_proc "SystemUIServer"

if run_as_gui_user /usr/bin/defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | /usr/bin/grep -q "$BUNDLE_ID"; then
  echo "HIToolbox now includes $BUNDLE_ID"
else
  echo "warning: HIToolbox still does not list $BUNDLE_ID immediately"
fi
if run_as_gui_user /usr/bin/defaults read com.apple.inputsources AppleEnabledThirdPartyInputSources 2>/dev/null | /usr/bin/grep -q "$MODE_ID"; then
  echo "inputsources now includes mode $MODE_ID"
else
  echo "warning: inputsources still does not list mode $MODE_ID immediately"
fi

echo "Waiting for SwiftIMEStarter input-source readiness (permission-grant flow, Ctrl-C to stop)..."
run_as_gui_user env \
  SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
  swift "$WATCH_READY_SWIFT_SCRIPT" "$BUNDLE_ID" "$MODE_ID" "0"

echo "Installed to: $DEST_APP"
echo "If SwiftIMEStarter is still not listed, log out and log back in once."
