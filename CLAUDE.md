# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

open-tls-iot-client is an end-to-end secure IoT control system using MQTT over TLS with X.509 client certificates. The system enables a mobile app to securely control physical devices (e.g., garage doors) via AWS IoT Core, with no NAT port forwarding required.

**Key security features:** X.509 mutual TLS authentication, Root CA verification, biometric authentication (Face ID/Touch ID), AES-encrypted OTP commands, NFC tag triggers with HMAC-signed URLs.

## Repository Structure

| Directory | Description | Build System |
|-----------|-------------|--------------|
| `ios/` | iOS app (Swift) with MQTT client | Xcode + CocoaPods |
| `esp32/esp32.sdk42/` | ESP32 firmware (ESP-IDF v4.2, recommended) | CMake + idf.py |
| `esp32/esp32.sdk33/` | ESP32 firmware (ESP-IDF v3.3, legacy) | Makefile |
| `test_tools/` | Go MQTT testing tools | go run/build |
| `ifttt_webhook/` | AWS Lambda for IoT notifications | Go + Lambda |

Each subdirectory has its own CLAUDE.md with detailed component-specific guidance.

## Build Commands

### iOS App
```bash
cd ios
pod install
# Open SecuredMQTTPublisher.xcworkspace (not .xcodeproj) in Xcode
```

### ESP32 Firmware (recommended: sdk42)
```bash
cd esp32/esp32.sdk42
idf.py build              # Build
idf.py flash monitor      # Flash and monitor
```
Before building, configure `main/open_tls.h` (WiFi, MQTT endpoint, AES key) and place TLS certificates in `main/certs/`.

### Go Test Tools
```bash
cd test_tools/subscriber && go run main.go   # Start subscriber first
cd test_tools/publisher && go run main.go    # Then start publisher
```
Configure AWS IoT endpoint in both `main.go` files and place certificates in `test_tools/`.

### IFTTT Lambda
```bash
cd ifttt_webhook
GOARCH=amd64 GOOS=linux go build -tags lambda.norpc -o bootstrap main.go
```
Uses `provided.al2` runtime.

## Architecture Overview

```
┌─────────────┐       TLS/X.509        ┌─────────────────┐       TLS/X.509        ┌─────────────────┐
│   iOS App   │ ─────────────────────► │  AWS IoT Core   │ ─────────────────────► │  ESP32 Device   │
│ (publisher) │       MQTT:8883        │   (broker)      │       MQTT:8883        │  (subscriber)   │
└─────────────┘                        └────────┬────────┘                        └─────────────────┘
                                                │
                                                │ Rule Engine
                                                ▼
                                        ┌─────────────────┐
                                        │  Lambda → IFTTT │
                                        └─────────────────┘
```

### iOS App (`ios/`)
- **Core.swift**: Singleton managing MQTT connection state and app lifecycle
- **SMPMQTTClient**: MQTT client with TLS using PEM→P12 certificate conversion
- **DataStore**: Keychain-based storage for settings and action configurations
- Uses Coordinator pattern for navigation and Combine for reactive data flow
- NFC tags trigger actions via HMAC-signed URLs (`smp://action?...`)

### ESP32 Firmware (`esp32/`)
- Receives JSON commands: `{"command": <action_id>, "otp-auth": "<hex>"}`
- OTP is AES-128-encrypted timestamp validated within tolerance window
- Action IDs: 1=open, 2=stop, 3=close, 4=open-stop-close, 5=force_report
- Key modules: `mqtt.c` (TLS client), `cmd.c` (command auth), `t_gpio.c` (relay control)

### Command Security
1. iOS app encrypts current timestamp with AES-128-ECB using shared key
2. Command sent as JSON over MQTT with encrypted OTP
3. ESP32 decrypts OTP, validates timestamp within tolerance
4. If valid, executes physical action (relay control)

## Certificate Setup

All components require AWS IoT device certificates (gitignored for security):
- **iOS**: Configured in app Settings screen, stored in Keychain
- **ESP32**: Place in `main/certs/my-tls-certificate.pem.crt` and `my-tls-private.pem.key`
- **test_tools**: Place in `test_tools/` directory

AWS Root CA (`aws-root-ca.pem`) is included in the repository.

## Target Hardware

- **iOS**: iOS 14.0+ (iPhone with Face ID/Touch ID recommended)
- **ESP32**: ESP32-PICO-MINI-02 (ESP32-PICO-DevKitM-2)

## Related Documentation

- [Project Wiki](https://github.com/tracmo/open-tls-iot-client/wiki)
- [Adding Mobile Notifications](https://github.com/tracmo/open-tls-iot-client/wiki/Adding-mobile-notifications)
