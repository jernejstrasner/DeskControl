# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LinakDeskControl is a dual-platform (macOS + iOS) SwiftUI app that controls Ikea Idasen desks (with Linak controllers) via Bluetooth. It's a menu bar app on macOS and a standard app on iOS.

## Build Commands

Build macOS target:
```
xcodebuild clean build analyze -scheme "DeskControl" | xcpretty
```

Build iOS target:
```
xcodebuild clean build analyze -scheme "DeskControliOS" | xcpretty
```

There are no tests.

## Architecture

**Shared code** lives in `Shared/` and is used by both targets. Platform-specific resources (assets, plists, entitlements) live in `DeskControl/` (macOS) and `DeskControliOS/` (iOS). Platform differences are handled via `#if os(macOS)` / `#if os(iOS)` conditionals.

### Key Components

- **DeskConnect** (`Shared/DeskConnect.swift`) — Core Bluetooth manager. Implements `CBPeripheralDelegate` and `CBCentralManagerDelegate`. Handles scanning, connection, position reading, and movement commands. Observable object driving SwiftUI updates.
- **ContentView** (`Shared/ContentView.swift`) — Single shared UI for both platforms. Provides desk picker, position display, up/down/stop controls, and sit/stand presets with save/recall.
- **ParticlePeripheral** (`Shared/ParticlePeripheral.swift`) — Bluetooth service/characteristic UUIDs and movement command constants for the Linak protocol.
- **BinUtils** (`Shared/BinUtils.swift`) — Pure-Swift binary pack/unpack (port of Python's `struct` module). Used to decode desk position data in `<Hh` format (little-endian UInt16 position + Int16 speed).
- **AppDelegate** (`Shared/AppDelegate.swift`) — App entry point. Initializes Sentry and creates either MenuBarExtra (macOS) or WindowGroup (iOS).

### Bluetooth Protocol

The desk communicates via two BLE services: a control service (write commands) and a reference output service (read position). Movement commands are little-endian UInt16 values: up=71, down=70, stop=255, wakeup=254. Position base is 6000 (1/10th mm) with a range of 6500.

### Dependencies

Only external dependency is **Sentry** (sentry-cocoa via SPM) for crash/error reporting. Sentry DSN is injected at build time via `Constants.template.swift` → `Constants.generated.swift`.

## macOS Release Build (Signed & Notarized)

To produce a notarized `.dmg` for GitHub distribution:

```bash
# 1. Archive with Developer ID signing
xcodebuild archive -scheme "DeskControl" -archivePath /tmp/DeskControl.xcarchive \
  CODE_SIGN_IDENTITY="Developer ID Application: Jernej Strasner (286DN3SPR7)" \
  DEVELOPMENT_TEAM=286DN3SPR7 CODE_SIGN_STYLE=Manual

# 2. Create ExportOptions.plist
cat > /tmp/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>286DN3SPR7</string>
</dict>
</plist>
EOF

# 3. Export to .app
xcodebuild -exportArchive -archivePath /tmp/DeskControl.xcarchive \
  -exportPath /tmp/DeskControlExport -exportOptionsPlist /tmp/ExportOptions.plist

# 4. Create DMG
hdiutil create -volname "DeskControl" -srcfolder /tmp/DeskControlExport/DeskControl.app \
  -ov -format UDZO /tmp/DeskControl.dmg

# 5. Notarize (uses keychain profile "DeskControl-notary" stored via `xcrun notarytool store-credentials`)
xcrun notarytool submit /tmp/DeskControl.dmg --keychain-profile "DeskControl-notary" --wait

# 6. Staple
xcrun stapler staple /tmp/DeskControl.dmg

# 7. Upload to GitHub release
gh release upload <tag> /tmp/DeskControl.dmg --clobber
```

### Notarization credentials

Credentials are stored in the local keychain under profile `DeskControl-notary`. To set up on a new machine:
```bash
xcrun notarytool store-credentials "DeskControl-notary" --team-id "286DN3SPR7"
```
This prompts for Apple ID and an app-specific password (generated at appleid.apple.com).

### Signing identity

- **Developer ID Application: Jernej Strasner (286DN3SPR7)** — required for notarization
- Certificate must be in the keychain; create via Xcode > Settings > Accounts > Manage Certificates

### CI automation

A plan for a GitHub Actions workflow to automate this on release creation is saved at `~/.claude/plans/fizzy-snacking-shannon.md`.

## Code Style

- When adding comments, be concise and focus on the why, not what
- When something needs to still be done, add a TODO comment and briefly explain what and why
- When summarizing changes, always list any leftover TODO items
