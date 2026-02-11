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
chown -R root:staff "$DEST_APP" || true
chmod -R 775 "$DEST_APP" || true
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST_APP/Contents/Info.plist")"
MODE_ID="$(/usr/libexec/PlistBuddy -c 'Print :ComponentInputModeDict:tsVisibleInputModeOrderedArrayKey:0' "$DEST_APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "${MODE_ID}" ]]; then
  MODE_ID="${BUNDLE_ID}.Default"
fi

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
swift - "$DEST_APP" "$BUNDLE_ID" "$MODE_ID" <<'SWIFT'
import Foundation
import Carbon

let appPath = CommandLine.arguments[1]
let bundleId = CommandLine.arguments[2]
let modeId = CommandLine.arguments[3]

func sources(key: CFString, value: String) -> [TISInputSource] {
    let filter = [key: value as CFString] as CFDictionary
    let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as! [TISInputSource]
    print("Found input sources for \(value): \(sources.count)")
    return sources
}

func firstSource(key: CFString, value: String) -> TISInputSource? {
    sources(key: key, value: value).first
}

func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    guard let value = unsafeBitCast(raw, to: CFBoolean?.self) else { return nil }
    return CFBooleanGetValue(value)
}

func stringProperty(_ source: TISInputSource, _ key: CFString) -> String {
    guard let raw = TISGetInputSourceProperty(source, key) else { return "nil" }
    let value = Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
    return String(describing: value)
}

func sourceSummary(_ label: String, _ source: TISInputSource?) {
    guard let source else {
        print("\(label): nil")
        return
    }
    print("\(label) id: \(stringProperty(source, kTISPropertyInputSourceID))")
    print("\(label) name: \(stringProperty(source, kTISPropertyLocalizedName))")
    print("\(label) type: \(stringProperty(source, kTISPropertyInputSourceType))")
    print("\(label) enabled: \(boolProperty(source, kTISPropertyInputSourceIsEnabled).map(String.init(describing:)) ?? "nil")")
    print("\(label) selected: \(boolProperty(source, kTISPropertyInputSourceIsSelected).map(String.init(describing:)) ?? "nil")")
    print("\(label) select-capable: \(boolProperty(source, kTISPropertyInputSourceIsSelectCapable).map(String.init(describing:)) ?? "nil")")
}

@discardableResult
func enableSource(_ source: TISInputSource, label: String) -> OSStatus {
    let status = TISEnableInputSource(source)
    print("TISEnableInputSource(\(label)): \(status)")
    return status
}

@discardableResult
func selectSource(_ source: TISInputSource, label: String) -> OSStatus {
    let status = TISSelectInputSource(source)
    print("TISSelectInputSource(\(label)): \(status)")
    return status
}

func deselectDisableSource(_ source: TISInputSource, label: String) {
    let deselectStatus = TISDeselectInputSource(source)
    print("TISDeselectInputSource(\(label)): \(deselectStatus)")
    let disableStatus = TISDisableInputSource(source)
    print("TISDisableInputSource(\(label)): \(disableStatus)")
}

let distributedCenter = DistributedNotificationCenter.default()
let enabledChangedName = Notification.Name(rawValue: kTISNotifyEnabledKeyboardInputSourcesChanged as String)
var enabledChangedCount = 0
let enabledObserver = distributedCenter.addObserver(forName: enabledChangedName, object: nil, queue: nil) { _ in
    enabledChangedCount += 1
    print("Observed notification: \(enabledChangedName.rawValue) count=\(enabledChangedCount)")
}
defer {
    distributedCenter.removeObserver(enabledObserver)
}

let appURL = URL(fileURLWithPath: appPath) as CFURL
let registerStatus = TISRegisterInputSource(appURL)
print("TISRegisterInputSource: \(registerStatus)")
guard registerStatus == noErr else { exit(1) }

var modeSource = firstSource(key: kTISPropertyInputSourceID, value: modeId)
var bundleSource = firstSource(key: kTISPropertyInputSourceID, value: bundleId)
    ?? firstSource(key: kTISPropertyBundleID, value: bundleId)
guard modeSource != nil || bundleSource != nil else {
    fputs("No TIS source found after registration for mode \(modeId) or bundle \(bundleId)\n", stderr)
    exit(1)
}

sourceSummary("Mode source (pass1)", modeSource)
sourceSummary("Bundle source (pass1)", bundleSource)
let initialTarget = modeSource ?? bundleSource!
sourceSummary("Initial target", initialTarget)

if let abc = firstSource(key: kTISPropertyInputSourceID, value: "com.apple.keylayout.ABC"),
   boolProperty(abc, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(abc, label: "ABC")
}

var seenSourceIDs = Set<String>()
for (label, candidate) in [("mode", modeSource), ("bundle", bundleSource)] {
    guard let source = candidate else { continue }
    let sourceId = stringProperty(source, kTISPropertyInputSourceID)
    if !seenSourceIDs.insert(sourceId).inserted {
        continue
    }
    deselectDisableSource(source, label: "\(label)-disable")
}

if let bundleSource {
    _ = enableSource(bundleSource, label: "bundle-pass1")
}
if let modeSource {
    _ = enableSource(modeSource, label: "mode-pass1")
}

if boolProperty(initialTarget, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(initialTarget, label: "target-pass1")
} else {
    print("target-pass1 is not select-capable; skipping select")
}

let waitDeadline = Date().addingTimeInterval(2.0)
while Date() < waitDeadline && enabledChangedCount == 0 {
    CFRunLoopRunInMode(.defaultMode, 0.1, true)
}
print("Enabled-source notifications observed: \(enabledChangedCount)")

modeSource = firstSource(key: kTISPropertyInputSourceID, value: modeId)
bundleSource = firstSource(key: kTISPropertyInputSourceID, value: bundleId)
    ?? firstSource(key: kTISPropertyBundleID, value: bundleId)

sourceSummary("Mode source (pass2)", modeSource)
sourceSummary("Bundle source (pass2)", bundleSource)

if let bundleSource {
    _ = enableSource(bundleSource, label: "bundle-pass2")
}
if let modeSource {
    _ = enableSource(modeSource, label: "mode-pass2")
}
if let modeSource, boolProperty(modeSource, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(modeSource, label: "mode-pass2")
} else if let bundleSource, boolProperty(bundleSource, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(bundleSource, label: "bundle-pass2")
}

let tisNotifications = [
    "com.apple.Carbon.TISNotifyEnabledKeyboardInputSourcesChanged",
    "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged",
    "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChangedForCurrentSession",
]
for notification in tisNotifications {
    distributedCenter.postNotificationName(
        Notification.Name(notification),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
    print("Posted notification: \(notification)")
}

CFRunLoopRunInMode(.defaultMode, 0.8, false)
SWIFT

echo "Syncing input-source preference domains..."
run_as_gui_user env \
SWIFT_MODULECACHE_PATH=/tmp/swift-module-cache \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
swift - "$BUNDLE_ID" "$MODE_ID" <<'SWIFT'
import Foundation

let bundleId = CommandLine.arguments[1]
let modeId = CommandLine.arguments[2]
typealias Entry = [String: Any]

let keyboardEntry: Entry = [
    "Bundle ID": bundleId,
    "InputSourceKind": "Keyboard Input Method",
]
let modeEntry: Entry = [
    "Bundle ID": bundleId,
    "Input Mode": modeId,
    "InputSourceKind": "Input Mode",
]

func entryMatches(_ lhs: Entry, _ rhs: Entry) -> Bool {
    let kindMatch = (lhs["InputSourceKind"] as? String) == (rhs["InputSourceKind"] as? String)
    let bundleMatch = (lhs["Bundle ID"] as? String) == (rhs["Bundle ID"] as? String)
    let modeMatch = (lhs["Input Mode"] as? String) == (rhs["Input Mode"] as? String)
    return kindMatch && bundleMatch && modeMatch
}

func mergeEntries(domain: String, key: String, entries: [Entry]) {
    let defaults = UserDefaults.standard
    var prefs = defaults.persistentDomain(forName: domain) ?? [:]
    var current = prefs[key] as? [Entry] ?? []
    var inserted = 0

    for entry in entries where !current.contains(where: { entryMatches($0, entry) }) {
        current.append(entry)
        inserted += 1
    }

    prefs[key] = current
    defaults.setPersistentDomain(prefs, forName: domain)
    defaults.synchronize()
    print("Updated \(domain) \(key): +\(inserted), total \(current.count)")
}

mergeEntries(
    domain: "com.apple.inputsources",
    key: "AppleEnabledThirdPartyInputSources",
    entries: [keyboardEntry, modeEntry]
)
mergeEntries(
    domain: "com.apple.HIToolbox",
    key: "AppleEnabledInputSources",
    entries: [keyboardEntry, modeEntry]
)
mergeEntries(
    domain: "com.apple.HIToolbox",
    key: "AppleInputSourceHistory",
    entries: [modeEntry]
)
SWIFT

echo "Refreshing text input/session agents..."
kill_gui_proc "TextInputMenuAgent"
kill_gui_proc "TextInputSwitcher"
kill_gui_proc "localizationswitcherd"
kill_gui_proc "pboard"
refresh_gui_job "com.apple.cfprefsd.agent"
kill_gui_proc "SystemUIServer"

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

echo "Installed to: $DEST_APP"
echo "If Typut is still not listed, log out and log back in once."
