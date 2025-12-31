# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SecuredMQTTPublisher is an iOS app that publishes MQTT messages over TLS using client certificates. It's part of the open-tls-iot-client project by Tracmo, licensed under MIT.

## Build and Run

Open `SecuredMQTTPublisher.xcworkspace` (not the xcodeproj) in Xcode. The project uses CocoaPods for dependency management.

**Simulator:**
- Select scheme 'SecuredMQTTPublisher' and a simulator, then run

**Device:**
- Set a development team under target > Signing & Capabilities before running

**Install dependencies:**
```bash
pod install
```

## Architecture

### Core Components

- **Core.swift** - Singleton (`Core.shared`) that manages app-wide MQTT connection state and publishing. Handles auto-connect/disconnect on app lifecycle events and triggers biometric auth after 60 seconds of inactivity.

- **SMPMQTTClient** (MQTTClient.swift) - Wraps MQTTClient framework. Handles TLS certificate authentication by converting PEM certificates to P12 format for the MQTT connection. Connects on port 8883 with MQTT 3.1.1.

- **DataStore.swift** - Stores all settings and actions in Keychain via `DataStore.Keychained`. Contains the `Settings` struct (endpoint, certificates, actions) and `Action` struct (title, topic, message).

### Certificate Handling

- **CertificateConverter** (Objective-C with Swift wrapper) - Converts PEM certificates/keys to P12 format for TLS client authentication. The Objective-C implementation uses OpenSSL (via Dependencies/OpenSSL-for-iPhone).

### UI Architecture

Uses a Coordinator pattern for navigation:

- **AppCoordinator** - Root coordinator managing two windows: home (main UI) and auth (biometric authentication overlay)
- **HomeCoordinator** - Manages Home, About, ActionEdit, and Settings flows
- **Flow/** - Each screen has a Coordinator and ViewController pair

The `Coordinator` protocol is minimal (`protocol Coordinator: AnyObject {}`). Coordinators manage child coordinators and navigation controllers.

### Reactive Pattern

Uses Combine throughout:
- `@Published` properties for state observation
- Publishers chain for async operations (connect, publish, certificate conversion)
- `AnyCancellable` stored in `bag` sets

### Key Data Flow

1. Settings changes in `DataStore` trigger automatic reconnection via Combine subscription in `Core`
2. MQTT state changes propagate from `SMPMQTTClient.$state` -> `Core.$state` -> UI
3. Publishing supports timestamp injection: `%T` in messages gets replaced with AES-128-ECB encrypted timestamp

### NFC Tag Triggers

The app supports triggering actions via NFC tags, bypassing biometric authentication:

**Security Model:**
- Each action button has its own 32-byte secret (`nfcSecret` in `Action` struct)
- NFC tags contain a signed URL: `smp://action?idx={index}&ts={timestamp}&sig={hmac}`
- HMAC-SHA256 signature using the button's secret
- 2-minute validity window (±120 seconds) to prevent replay attacks
- Regenerating a secret invalidates all previously written tags for that button

**Key Files:**
- **NFCTokenManager.swift** - URL generation and validation with HMAC signatures
- **NFCTagWriter.swift** - CoreNFC wrapper for writing NDEF URLs to tags
- **SceneDelegate.swift** - Handles `smp://` URL scheme for cold/warm launch
- **AppCoordinator.swift** - `executeActionFromNFC(index:)` bypasses auth and publishes

**Flow:**
1. User edits action → taps "Write NFC Tag" → new secret generated → URL written to tag
2. User taps NFC tag → iOS opens app with URL → app validates signature/timestamp → executes MQTT publish
3. Double haptic vibration confirms successful NFC action (distinct from normal button feedback)

## Dependencies

- **MQTTClient** - MQTT framework (custom fork at tracmo/MQTT-Client-Framework)
- **CryptoSwift** - AES encryption for timestamp feature
- **KeychainSwift** - Keychain access (in Dependencies/keychain-swift)
- **OpenSSL** - Certificate conversion (in Dependencies/OpenSSL-for-iPhone)

## Target Platform

iOS 14.0+
