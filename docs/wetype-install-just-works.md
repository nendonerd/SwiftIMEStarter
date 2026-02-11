# WeType "Install And Just Works" Flow (Reverse-Engineered)

## Purpose
This document records how WeType achieves a post-install experience where the new input method becomes usable immediately, including in already-running apps, without requiring logout/reboot.

The goal is future reference for Typut and other macOS IME installers.

## Scope And Method
This analysis is from static reverse engineering of:

- `WeTypeInstaller.app/Contents/Resources/install.sh`
- `WeTypeInstaller.app/Contents/MacOS/WeTypeInstaller` (Swift Mach-O, arm64 path shown below)

Primary techniques:

- `strings`
- `nm | xcrun swift-demangle`
- `lldb` disassembly by symbol/address
- `otool` symbol/literal cross-check

No source code was available; behavior was inferred from function names, call graph, strings, and API calls.

## High-Level Conclusion
WeType does not rely on one single "magic" API. It combines multiple actions in a strict order:

1. Register and resolve input sources via Carbon TIS.
2. Explicitly deselect+disable old source IDs.
3. Switch current source to `ABC`.
4. Enable/select its own source.
5. Subscribe to `kTISNotifyEnabledKeyboardInputSourcesChanged`.
6. On notification, run a second enable/select pass on main queue.
7. Restart text-input menu/switcher agents (`TextInputMenuAgent`, `TextInputSwitcher`) near termination.
8. In some flows, kill `pboard` and optionally launch `WeTypeSettings.app`.

That combination is what makes already-running apps pick up the new IME more reliably.

## Layered Architecture

### Layer 1: Resource Install Script (Simple Bundle Deployment)
`WeTypeInstaller.app/Contents/Resources/install.sh` mainly does packaging and file operations:

- unzip payload to `/tmp/wetype`
- install `WeType.app` into `/Library/Input Methods`
- set ownership/perms
- clear quarantine xattr
- kill `SystemUIServer`

Evidence: `WeTypeInstaller.app/Contents/Resources/install.sh:1`

Important: this script alone is not enough to explain the "already running apps can switch" behavior.

### Layer 2: Main Installer Binary (Real Activation Logic)
The real behavior is in `WeTypeInstaller` binary functions under:

- `InstallerMainWindowViewController`
- `InstallerMainWindowViewModel`
- `InstallerInputSourceHandler`

The call chain links UI step flow to TIS activation internals and agent refresh timing.

### Layer 3: Input Source Handler (Core of "Just Works")
Key recovered methods:

- `activateInputSource()` closure (controller side orchestration)
- `disableAll()`
- `disableInputSource(id:property:)`
- `changeToSystemInputMode()`
- `registerInputSource()`
- `enableInputSource()`
- `registerNotification()`
- `handleEnabledNotification(_:)`
- `enableAndSelectInputMode(needCallback:)`

## Recovered Call Graph (Core Path)
From disassembly/symbol resolution:

1. `activateInputSource()` closure
2. `disableAll()`
3. `registerInputSource()`
4. `enableInputSource()`
5. `registerNotification()` (if needed)
6. `enableAndSelectInputMode(needCallback: ...)`
7. notification callback -> `handleEnabledNotification(_:)`
8. callback closure -> `enableAndSelectInputMode(needCallback: true)` again

Evidence:

- `activateInputSource` closure calls:
  - `disableAll` at `0x10001c230`
  - `registerInputSource` at `0x10001c23c`
  - `enableInputSource` at `0x10001c254`
  - Source: `/tmp/wetype_activate_closure.txt`
- `enableInputSource` entry `0x10001f3f0`
  - calls `registerNotification` (`0x10001f518`)
  - calls `enableAndSelectInputMode` (`0x10001f4f4`, `0x10001f658`)
  - Source: `/tmp/wetype_enable_input_source.txt`

## Detailed Sequence

### 1) Disable Existing WeType Sources First
`disableAll()` invokes `disableInputSource` for at least:

- input mode ID: `com.tencent.inputmethod.wetype.pinyin`
- bundle/input method ID: `com.tencent.inputmethod.wetype`

`disableInputSource(id:property:)` performs:

1. Build TIS source list by filter
2. For each match:
   - `TISDeselectInputSource`
   - `TISDisableInputSource`

Evidence:

- `disableAll` specialization entry `0x100020ed4`
- repeated calls to `disableInputSource` at `0x100020f28`, `0x100020f58`
- `disableInputSource` tail shows deselect then disable
- Sources: `/tmp/wetype_disable_change_system.txt`, `/tmp/wetype_disable_input_tail.txt`

### 2) Change Active Input To ABC
`changeToSystemInputMode()` scans sources and selects:

- `com.apple.keylayout.ABC`

Then performs `TISSelectInputSource(ABC)`.

Evidence:

- `changeToSystemInputMode` specialization `0x100020f9c`
- literal `com.apple.keylayout.ABC`
- `TISSelectInputSource` call around `0x100021164`
- Source: `/tmp/wetype_disable_change_system.txt`

### 3) Register Source, Then Enable
`registerInputSource()` (specialized at `0x100020880`) is called before activation.

`enableInputSource()` then:

- checks source state (`isInputSourceEnabled`)
- may attempt re-register if not found
- calls into wrapper to enable source
- enters `enableAndSelectInputMode(...)`

Evidence:

- Source: `/tmp/wetype_enable_input_source.txt`
- Demangled symbol list confirms both functions.

### 4) Subscribe To TIS Enabled-Source Notification
`registerNotification()` registers distributed observer for:

- `kTISNotifyEnabledKeyboardInputSourcesChanged`

Implementation details recovered:

- `CFNotificationCenterGetDistributedCenter`
- `CFNotificationCenterAddObserver`
- internal bridge via `InputSourceEnabledChangedNotification`

Evidence:

- `registerNotification()` entry `0x10001fb3c`
- `CFNotificationCenterAddObserver` call at `0x10001fba4`
- literals:
  - `kTISNotifyEnabledKeyboardInputSourcesChanged`
  - `InputSourceEnabledChangedNotification`
- Source: `/tmp/wetype_notification.txt`

### 5) Notification-Driven Second Pass On Main Queue
On enabled-source notification:

- `handleEnabledNotification(_:)` runs
- dispatches closure on main queue
- closure calls `enableAndSelectInputMode(needCallback: true)` again

This second pass is likely critical: it retries select after TIS state propagation, not just immediately after register/enable.

Evidence:

- `handleEnabledNotification` entry `0x10001fc50`
- closure entry `0x10001feb8`
- call to `enableAndSelectInputMode` at `0x10001fefc`
- Source: `/tmp/wetype_notification.txt`

### 6) Refresh Input Menu Agents Near Termination
`terminateSelf(needReloadInputMenu:)` uses a closure that runs:

- `killall -9 TextInputMenuAgent`
- `killall -9 TextInputSwitcher`

Evidence:

- closure entry `0x100021b24`
- literals at:
  - `0x100021b80`: `killall -9 TextInputMenuAgent`
  - `0x100021bb4`: `killall -9 TextInputSwitcher`
- Source: `/tmp/wetype_terminate_closure.txt`

This timing matters: it refreshes menu/switcher after activation work, not only before.

### 7) Pasteboard Refresh Path
Separate `reloadPasteBoard()` path includes:

- `killall -9 pboard`

Evidence:

- `reloadPasteBoard` specialization `0x100023c78`
- literal at `0x100023e50`: `killall -9 pboard`
- Source: `/tmp/wetype_reload_pboard.txt`

### 8) Optional Step-Two Settings Launch
Installer can open:

- `/Library/Input Methods/WeType.app/Contents/MacOS/WeTypeSettings.app`

with tracking key `StepTwo_openSettings`, and checks `com.tencent.WeTypeSettings` running state.

Evidence:

- `openWeTypeSettings(...)` specialization `0x100023f78`
- literals in `/tmp/wetype_open_settings_long.txt`

## Why Already-Running Apps Start Working
Most probable mechanism is the combination below, not one API:

1. Hard reset of old source state (`deselect + disable`).
2. Force session source away to ABC first.
3. Enable/select target.
4. Wait for TIS enabled-source notification.
5. Re-run enable/select on notification (main queue).
6. Restart menu/switcher agents after activation.

This sequence improves synchronization among:

- TIS registry
- HIToolbox input source list
- per-session UI components (input menu/switcher)
- existing app input contexts

## Practical Guidance For Typut

### Recommended Activation Pattern
Implement in this order:

1. Register app with TIS.
2. Resolve both bundle source and mode source.
3. Select ABC.
4. Deselect+disable old Typut source entries.
5. Enable bundle + mode.
6. Select mode.
7. Observe `kTISNotifyEnabledKeyboardInputSourcesChanged`.
8. On notification (or short timeout), re-resolve and re-enable/re-select.
9. Restart only necessary agents (`TextInputMenuAgent`, `TextInputSwitcher`).

### Avoid These Pitfalls

- Over-killing unrelated agents can stall Settings/UI.
- Writing both `Keyboard Input Method` and `Input Mode` for same IME into `AppleEnabledInputSources` can cause duplicate menu entries.
- Depending on a single immediate `TISSelectInputSource` without notification-driven second pass is less reliable for already-running apps.

## Evidence Index

### Files Used
- `/tmp/wetype_activate_closure.txt`
- `/tmp/wetype_enable_input_source.txt`
- `/tmp/wetype_enable_and_select.txt`
- `/tmp/wetype_notification.txt`
- `/tmp/wetype_disable_change_system.txt`
- `/tmp/wetype_disable_input_tail.txt`
- `/tmp/wetype_terminate_closure.txt`
- `/tmp/wetype_reload_pboard.txt`
- `/tmp/wetype_open_settings_long.txt`
- `WeTypeInstaller.app/Contents/Resources/install.sh`

### Key Addresses
- `activateInputSource` closure: `0x10001c09c`
- `enableInputSource`: `0x10001f3f0`
- `enableAndSelectInputMode`: `0x10001f66c`
- `registerNotification`: `0x10001fb3c`
- `handleEnabledNotification`: `0x10001fc50`
- `disableAll`: `0x100020ed4`
- `disableInputSource`: `0x100020b20`
- `changeToSystemInputMode`: `0x100020f9c`
- `terminateSelf`: `0x10002138c`
- `terminateSelf` closure (kill input agents): `0x100021b24`
- `reloadPasteBoard`: `0x100023c78`
- `openWeTypeSettings`: `0x100023f78`

## Confidence And Unknowns
Confidence is high on call ordering and API use (based on symbol names + concrete callsites).

Still unknown without dynamic tracing:

- Exact race timing thresholds used internally across OS versions.
- Whether additional private framework behavior is triggered indirectly by WeTypeSettings.
- Which subset of refresh actions is strictly necessary vs defensive.

## Minimal Reproduction Commands (For Future Audits)
Examples used during this analysis:

```bash
nm WeTypeInstaller.app/Contents/MacOS/WeTypeInstaller | xcrun swift-demangle | rg 'InstallerInputSourceHandler|terminateSelf|openWeTypeSettings'
strings -a WeTypeInstaller.app/Contents/MacOS/WeTypeInstaller | rg 'TIS|InputSource|TextInput|pboard|WeTypeSettings|kTISNotify'
lldb -b -o 'target create WeTypeInstaller.app/Contents/MacOS/WeTypeInstaller' -o 'disassemble -s 0x10001f3f0 -c 220' -o quit
lldb -b -o 'target create WeTypeInstaller.app/Contents/MacOS/WeTypeInstaller' -o 'disassemble -s 0x10001fb3c -c 260' -o quit
lldb -b -o 'target create WeTypeInstaller.app/Contents/MacOS/WeTypeInstaller' -o 'disassemble -s 0x100021b24 -c 220' -o quit
```

## Known Problems In Typut Baseline Installer (Commit `b1da442`)
The Typut installer version restored to `b1da442` is the most reliable version we found for immediate post-install activation in already-running apps, but it has known UX defects:

1. Duplicate Typut entries may appear in the IME picker/list.
2. One duplicate entry can behave differently (one works for already-running apps, the other may not).
3. During install, macOS may open the IME permission/privacy page and that page can briefly stall/unresponsive.
4. In some runs, user timing around permission grant still affects whether Typut appears immediately without re-login.

Reason these issues remain in that baseline:

- It aggressively refreshes multiple session/UI agents to force propagation.
- It writes both keyboard-method and input-mode entries into enabled-source preference domains.
- Those two choices improve activation reliability but create UI consistency side effects.

This section is intentionally retained as a reference tradeoff record until a cleaner flow is implemented.
