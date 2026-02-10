#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ge 1 ]]; then
  APP_PATH="$1"
else
  if [[ -d "./build/Build/Products/Debug/Typut.app" ]]; then
    APP_PATH="./build/Build/Products/Debug/Typut.app"
  elif [[ -d "./build/Build/Products/Release/Typut.app" ]]; then
    APP_PATH="./build/Build/Products/Release/Typut.app"
  elif [[ -d "./build/Release/Typut.app" ]]; then
    APP_PATH="./build/Release/Typut.app"
  else
    APP_PATH="./build/Build/Products/Debug/Typut.app"
  fi
fi
DEST_DIR="/Library/Input Methods"
DEST_APP="$DEST_DIR/Typut.app"
GUI_USER="${SUDO_USER:-$(stat -f%Su /dev/console)}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found: $APP_PATH"
  echo "usage: $0 [path/to/Typut.app]"
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
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST_APP/Contents/Info.plist")"

echo "Registering input source (Carbon TIS API) as user: $GUI_USER"
sudo -u "$GUI_USER" env \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swift - "$DEST_APP" "$BUNDLE_ID" <<'SWIFT'
import Foundation
import Carbon

let appPath = CommandLine.arguments[1]
let bundleId = CommandLine.arguments[2]

let url = URL(fileURLWithPath: appPath) as CFURL
let registerStatus = TISRegisterInputSource(url)
print("TISRegisterInputSource: \(registerStatus)")
guard registerStatus == noErr else { exit(1) }

let filter = [kTISPropertyBundleID: bundleId as CFString] as CFDictionary
let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
print("Found input sources for \(bundleId): \(sources.count)")
guard let source = sources.first else {
    fputs("No TIS source found after registration\n", stderr)
    exit(1)
}

let enableStatus = TISEnableInputSource(source)
print("TISEnableInputSource: \(enableStatus)")

let selectStatus = TISSelectInputSource(source)
print("TISSelectInputSource: \(selectStatus)")
if selectStatus != noErr {
    print("Note: select may fail depending on current session/context. You can still switch to Typut from the input menu.")
}
SWIFT

sudo -u "$GUI_USER" killall TextInputMenuAgent 2>/dev/null || true
echo "Installed to: $DEST_APP"
echo "If Typut is still not listed, log out and log back in once."
