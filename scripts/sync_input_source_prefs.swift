import Foundation

let bundleId = CommandLine.arguments[1]
let modeId = CommandLine.arguments[2]
typealias Entry = [String: Any]
let hasSeparateMode = modeId != bundleId

let keyboardEntry: Entry = [
    "Bundle ID": bundleId,
    "InputSourceKind": "Keyboard Input Method",
]
let modeEntry: Entry = [
    "Bundle ID": bundleId,
    "Input Mode": modeId,
    "InputSourceKind": "Input Mode",
]
let thirdPartyEntries: [Entry] = hasSeparateMode ? [keyboardEntry, modeEntry] : [keyboardEntry]
let enabledEntries: [Entry] = hasSeparateMode ? [modeEntry] : [keyboardEntry]
let historyEntries: [Entry] = hasSeparateMode ? [modeEntry] : [keyboardEntry]

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
    var removed = 0

    // Keep only the per-domain allowed Typut entries.
    current.removeAll { entry in
        guard (entry["Bundle ID"] as? String) == bundleId else { return false }
        if !entries.contains(where: { entryMatches(entry, $0) }) {
            removed += 1
            return true
        }
        return false
    }

    for entry in entries where !current.contains(where: { entryMatches($0, entry) }) {
        current.append(entry)
        inserted += 1
    }

    prefs[key] = current
    defaults.setPersistentDomain(prefs, forName: domain)
    defaults.synchronize()
    print("Updated \(domain) \(key): +\(inserted), -\(removed), total \(current.count)")
}

mergeEntries(
    domain: "com.apple.inputsources",
    key: "AppleEnabledThirdPartyInputSources",
    entries: thirdPartyEntries
)
mergeEntries(
    domain: "com.apple.HIToolbox",
    key: "AppleEnabledInputSources",
    entries: enabledEntries
)
mergeEntries(
    domain: "com.apple.HIToolbox",
    key: "AppleInputSourceHistory",
    entries: historyEntries
)
