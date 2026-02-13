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

func sourceID(_ source: TISInputSource) -> String {
    stringProperty(source, kTISPropertyInputSourceID)
}

func preferredSource(mode: TISInputSource?, bundle: TISInputSource?) -> (label: String, source: TISInputSource)? {
    if let mode { return ("mode", mode) }
    if let bundle { return ("bundle", bundle) }
    return nil
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
guard let initialTarget = preferredSource(mode: modeSource, bundle: bundleSource) else {
    fputs("No preferred source available for mode \(modeId) or bundle \(bundleId)\n", stderr)
    exit(1)
}
sourceSummary("Initial target", initialTarget.source)

if let abc = firstSource(key: kTISPropertyInputSourceID, value: "com.apple.keylayout.ABC"),
   boolProperty(abc, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(abc, label: "ABC")
}

var seenSourceIDs = Set<String>()
for (label, candidate) in [("mode", modeSource), ("bundle", bundleSource)] {
    guard let source = candidate else { continue }
    let sourceId = sourceID(source)
    if !seenSourceIDs.insert(sourceId).inserted {
        continue
    }
    deselectDisableSource(source, label: "\(label)-disable")
}

_ = enableSource(initialTarget.source, label: "\(initialTarget.label)-pass1")

if boolProperty(initialTarget.source, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(initialTarget.source, label: "\(initialTarget.label)-pass1")
} else {
    print("\(initialTarget.label)-pass1 is not select-capable; skipping select")
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

guard let targetPass2 = preferredSource(mode: modeSource, bundle: bundleSource) else {
    fputs("No preferred source available in pass2 for mode \(modeId) or bundle \(bundleId)\n", stderr)
    exit(1)
}
_ = enableSource(targetPass2.source, label: "\(targetPass2.label)-pass2")
if boolProperty(targetPass2.source, kTISPropertyInputSourceIsSelectCapable) == true {
    _ = selectSource(targetPass2.source, label: "\(targetPass2.label)-pass2")
} else {
    print("\(targetPass2.label)-pass2 is not select-capable; skipping select")
}

if let modeSource, let bundleSource, sourceID(modeSource) != sourceID(bundleSource) {
    deselectDisableSource(bundleSource, label: "bundle-cleanup-pass2")
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
