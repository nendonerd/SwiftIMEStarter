import Foundation
import Carbon

let bundleId = CommandLine.arguments[1]
let modeId = CommandLine.arguments[2]
let timeoutSeconds = CommandLine.arguments.count > 3 ? (Double(CommandLine.arguments[3]) ?? 0.0) : 0.0
let pollIntervalSeconds = 0.25
let userName = ProcessInfo.processInfo.environment["USER"] ?? NSUserName()

func runProcess(_ launchPath: String, _ arguments: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        return (1, "failed to run \(launchPath): \(error)")
    }

    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (process.terminationStatus, output)
}

func readODInputSourcesXML(user: String) -> String? {
    let result = runProcess("/usr/bin/dscl", [".", "-read", "/Users/\(user)", "dsAttrTypeNative:inputSources"])
    guard result.status == 0 else {
        return nil
    }
    return result.output
}

func odContainsTarget(_ xml: String) -> Bool {
    if xml.contains("<string>\(bundleId)</string>") {
        return true
    }
    if modeId != bundleId && xml.contains("<string>\(modeId)</string>") {
        return true
    }
    return false
}

func sources(key: CFString, value: String) -> [TISInputSource] {
    let filter = [key: value as CFString] as CFDictionary
    guard let sourceList = TISCreateInputSourceList(filter, true)?.takeRetainedValue() else {
        return []
    }
    return sourceList as? [TISInputSource] ?? []
}

func firstSource(key: CFString, value: String) -> TISInputSource? {
    sources(key: key, value: value).first
}

func resolveTargetSource() -> TISInputSource? {
    if let modeSource = firstSource(key: kTISPropertyInputSourceID, value: modeId) {
        return modeSource
    }
    if let bundleSource = firstSource(key: kTISPropertyInputSourceID, value: bundleId) {
        return bundleSource
    }
    return firstSource(key: kTISPropertyBundleID, value: bundleId)
}

func stringProperty(_ source: TISInputSource, _ key: CFString) -> String {
    guard let raw = TISGetInputSourceProperty(source, key) else { return "nil" }
    let value = Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
    return String(describing: value)
}

func currentInputSourceID() -> String {
    guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return "nil"
    }
    return stringProperty(current, kTISPropertyInputSourceID)
}

func isTargetSelected() -> Bool {
    let currentId = currentInputSourceID()
    return currentId == modeId || currentId == bundleId
}

let hasTimeout = timeoutSeconds > 0
let timeoutText = hasTimeout ? String(format: "%.1f", timeoutSeconds) + "s" : "infinite"
print("OD watcher: user=\(userName) mode=\(modeId) bundle=\(bundleId) timeout=\(timeoutText)")

let start = Date()
let deadline = start.addingTimeInterval(timeoutSeconds)

var odScanCount = 0
var selectAttemptCount = 0
var lastSelectStatus: OSStatus?
var lastCurrentSourceId: String?
var lastSourceMissing = false

let initialOD = readODInputSourcesXML(user: userName)
let initialPresent = initialOD.map(odContainsTarget) ?? false
print("OD watcher: initial dsAttrTypeNative:inputSources contains target=\(initialPresent)")

var odReady = initialPresent
while !odReady && (!hasTimeout || Date() < deadline) {
    odScanCount += 1
    if let xml = readODInputSourcesXML(user: userName), odContainsTarget(xml) {
        odReady = true
        let elapsed = Date().timeIntervalSince(start)
        let elapsedText = String(format: "%.2f", elapsed)
        print("OD watcher: detected target in dsAttrTypeNative:inputSources after \(elapsedText)s scans=\(odScanCount)")
        break
    }
    CFRunLoopRunInMode(.defaultMode, pollIntervalSeconds, true)
}

if !odReady {
    let elapsed = Date().timeIntervalSince(start)
    let elapsedText = String(format: "%.2f", elapsed)
    print("OD watcher: timeout waiting for dsAttrTypeNative:inputSources update after \(elapsedText)s scans=\(odScanCount)")
    exit(1)
}

while !hasTimeout || Date() < deadline {
    selectAttemptCount += 1

    guard let targetSource = resolveTargetSource() else {
        if !lastSourceMissing {
            print("OD watcher: target TIS source not found yet")
            lastSourceMissing = true
        }
        CFRunLoopRunInMode(.defaultMode, pollIntervalSeconds, true)
        continue
    }

    if lastSourceMissing {
        print("OD watcher: target TIS source found")
        lastSourceMissing = false
    }

    let status = TISSelectInputSource(targetSource)
    if status != lastSelectStatus {
        print("OD watcher: TISSelectInputSource status=\(status) attempt=\(selectAttemptCount)")
        lastSelectStatus = status
    }

    let currentId = currentInputSourceID()
    if currentId != lastCurrentSourceId {
        print("OD watcher: current selected source id=\(currentId)")
        lastCurrentSourceId = currentId
    }

    if status == noErr && isTargetSelected() {
        let elapsed = Date().timeIntervalSince(start)
        let elapsedText = String(format: "%.2f", elapsed)
        print("OD watcher: selection succeeded after \(elapsedText)s select-attempts=\(selectAttemptCount)")
        exit(0)
    }

    CFRunLoopRunInMode(.defaultMode, pollIntervalSeconds, true)
}

let elapsed = Date().timeIntervalSince(start)
let elapsedText = String(format: "%.2f", elapsed)
print("OD watcher: timeout during selection after \(elapsedText)s select-attempts=\(selectAttemptCount)")
exit(1)
