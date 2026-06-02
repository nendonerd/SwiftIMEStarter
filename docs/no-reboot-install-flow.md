# No-Reboot IME Install Flow

This document describes the install flow used by SwiftIMEStarter to make a macOS input method available without requiring logout or reboot.

The flow is intended as a reusable starting point for future InputMethodKit projects, including AI-assisted input methods that need a reliable local development and installation loop.

The template app, Xcode project, build target, bundle ID, and input source identity are named `SwiftIMEStarter`.

## Problem

Traditional macOS input method installation is usually:

1. Build the `.app`.
2. Copy it into `~/Library/Input Methods` or `/Library/Input Methods`.
3. Log out or reboot.
4. Add/select the input method from System Settings.

That flow is slow for development and painful for projects that need frequent iteration. The goal of SwiftIMEStarter is to make the install step refresh the relevant macOS input source state in the current login session.

## Current Flow

The install script performs these steps:

1. Copies `SwiftIMEStarter.app` into `/Library/Input Methods/SwiftIMEStarter.app`.
2. Clears quarantine attributes and sets ownership/permissions.
3. Registers the app with Launch Services.
4. Registers the input source using Carbon TIS APIs.
5. Enables and selects the input source in the current GUI user session.
6. Synchronizes the relevant input source preference domains.
7. Watches for the macOS input source readiness signal after permission is granted.

The script is intentionally run as root for installation, then switches back into the active GUI user session for user-scoped registration:

```bash
sudo ./install.sh
```

## Scripts

`compile.sh`

Builds the Xcode project into `./build/Build/Products/<Configuration>/SwiftIMEStarter.app`. By default it disables code signing for local development:

```bash
./compile.sh
./compile.sh Release
```

`install.sh`

Installs the built app, registers the input source, syncs preference domains, and waits for readiness:

```bash
sudo ./install.sh
sudo ./install.sh ./build/Build/Products/Release/SwiftIMEStarter.app
```

`scripts/register_input_source.swift`

Handles Carbon TIS registration, enable/disable sequencing, and input source selection.

`scripts/sync_input_source_prefs.swift`

Updates the user preference domains that macOS uses to remember enabled input methods.

`scripts/watch_input_source_ready.swift`

Waits for the current user session to observe the input source after the system permission flow completes, then retries selection until the source is active.

## Permission Flow

macOS may open a privacy/permission page the first time a new input method is installed. Grant the permission when prompted. The watcher keeps the install command alive so the input method can become active in the same login session after permission is granted.

If the watcher is interrupted, rerun:

```bash
sudo ./install.sh
```

## Why This Is Useful As A Template

SwiftIMEStarter keeps the input method small and understandable while solving a practical install problem. It can be used as a base for:

- AI-assisted text input prototypes.
- Local LLM-powered composition tools.
- Domain-specific completion or typography input methods.
- IME experiments that need a fast build/install/test loop.

The main extension points are:

- `SwiftIMEStarter/SwiftIMEStarterInputController.swift` for input handling and composition behavior.
- `SwiftIMEStarter/Typography/Typography.swift` for candidate generation logic.
- `SwiftIMEStarter/Info.plist` for input source IDs, visible mode configuration, and IMKit metadata.
- `scripts/` for installation and current-session registration behavior.

## Known Limitations

The installer targets local development and template use. It is not yet a production-grade signed/notarized installer.

Current limitations:

- The install script requires `sudo` because it installs into `/Library/Input Methods`.
- First install may require macOS privacy permission before the source becomes selectable.
- Behavior may vary across macOS versions because input source registration is partly session-scoped.
- A production app should add signing, notarization, packaging, and clearer permission UX.

## Recommended Development Loop

```bash
./compile.sh
sudo ./install.sh
```

Then test in both a newly opened app and an already-running app. The second case is important because it validates current-session refresh behavior.
