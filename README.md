# SwiftIMEStarter

SwiftIMEStarter is a fork of the original [Typut](https://github.com/ensan-hcl/Typut) project. It keeps the original small Swift/InputMethodKit demo structure and adds a practical installer flow for macOS input methods.

The main problem solved here is the usual "install the input method, then log out or reboot before it works" loop. This project builds and installs SwiftIMEStarter, registers the input source in the current GUI session, syncs macOS input-source preferences, and waits for the permission flow so the IME can become available without a mandatory logout or reboot.

It is intended as a base template for future AI-assisted input methods: local LLM writing tools, specialized completion engines, typography helpers, command-driven text transforms, or other IME experiments that need a fast build/install/test loop.

## Features

- Minimal macOS IME built with Swift and InputMethodKit.
- Local build script with unsigned development builds by default.
- Current-session install script for `/Library/Input Methods`.
- Carbon TIS registration and selection flow.
- Preference synchronization for enabled input sources.
- Readiness watcher for the macOS permission/grant flow.
- Small codebase suitable for AI-assisted IME prototypes.

## Requirements

- macOS
- Xcode
- Swift toolchain from Xcode command line tools
- `sudo` access for installing into `/Library/Input Methods`

The original Typut sample was checked against macOS 14.3, Swift 5.10, and Xcode 15.3. This fork is structured for local development on modern macOS versions.

## Build

Build a debug app:

```bash
./compile.sh
```

Build a release app:

```bash
./compile.sh Release
```

By default `compile.sh` disables code signing for local development. Set `NO_CODESIGN=0` if you want Xcode's normal signing behavior:

```bash
NO_CODESIGN=0 ./compile.sh Release
```

## Install Without Logout/Reboot

After building, run:

```bash
sudo ./install.sh
```

The installer defaults to `./build/Build/Products/Debug/SwiftIMEStarter.app` when present. You can also pass an explicit app path:

```bash
sudo ./install.sh ./build/Build/Products/Release/SwiftIMEStarter.app
```

On first install, macOS may open a privacy/permission page for the input method. Grant the permission when prompted. The installer includes a readiness watcher so the current session can pick up the IME after permission is granted.

## Development Loop

```bash
./compile.sh
sudo ./install.sh
```

Then verify SwiftIMEStarter in:

- a newly opened app
- an already-running app

Testing both cases matters because already-running apps are the hard case for no-reboot IME registration.

## Project Layout

- `SwiftIMEStarter/SwiftIMEStarterInputController.swift`: input event handling, composition state, and candidate behavior.
- `SwiftIMEStarter/Typography/Typography.swift`: typography candidate generation.
- `SwiftIMEStarter/Info.plist`: IMKit metadata, input source ID, and visible input mode configuration.
- `compile.sh`: local Xcode build helper.
- `install.sh`: no-reboot install/register helper.
- `scripts/register_input_source.swift`: Carbon TIS registration and selection logic.
- `scripts/sync_input_source_prefs.swift`: input source preference synchronization.
- `scripts/watch_input_source_ready.swift`: current-session readiness watcher.
- `docs/no-reboot-install-flow.md`: detailed install flow notes.

## Using This As A Template

Use SwiftIMEStarter when you want an IME project that is small enough to modify quickly, but already has the installation loop needed for real macOS testing.

Good starting points:

- Replace `Typography/Typography.swift` with your own candidate generation.
- Extend `SwiftIMEStarterInputController.swift` to call a local model, rules engine, or completion service.
- Change bundle IDs and visible input mode IDs in `SwiftIMEStarter/Info.plist`.
- Keep the install scripts in place while prototyping so you can iterate without logout/reboot.

## Uninstall

Remove the installed demo app:

```bash
sudo rm -rf "/Library/Input Methods/SwiftIMEStarter.app"
```

Then remove SwiftIMEStarter from macOS Keyboard/Input Sources settings if it is still listed.

## Notes

This project is a development template, not a production installer. A production input method should add signing, notarization, packaging, user-facing permission guidance, and versioned release artifacts.

## Credits

This fork is based on the original [Typut](https://github.com/ensan-hcl/Typut) sample implementation.

References from the upstream project:

- https://mzp.hatenablog.com/entry/2017/09/17/220320
- https://www.logcg.com/en/archives/2078.html
- https://stackoverflow.com/questions/27813151/how-to-develop-a-simple-input-method-for-mac-os-x-in-swift
- [日本語入力を作るときに必要だった本](https://mzp.booth.pm/items/809262)
