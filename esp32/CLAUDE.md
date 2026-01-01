# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ESP32-based IoT client that connects securely to AWS IoT Core via MQTT over TLS. The device receives encrypted commands (using AES OTP authentication) and controls physical outputs (door open/stop/close actions). The project name is "open_tls_device".

## SDK Versions

Two separate builds exist for different ESP-IDF versions:
- **esp32.sdk33**: Uses ESP-IDF v3.3 (legacy Makefile-based build)
- **esp32.sdk42**: Uses ESP-IDF v4.2.1 (CMake-based build, preferred)

## Build Commands

Requires ESP-IDF toolchain to be installed and sourced.

```bash
# For esp32.sdk42 (recommended)
cd esp32.sdk42
idf.py build                    # Build the project
idf.py flash                    # Flash to device
idf.py monitor                  # View serial output
idf.py flash monitor            # Flash and monitor combined

# For esp32.sdk33 (legacy)
cd esp32.sdk33
make                            # Build the project
make flash                      # Flash to device
make monitor                    # View serial output
```

## Configuration Before Building

1. **WiFi and MQTT settings** in `main/open_tls.h`:
   - `OPEN_TLS_WIFI_SSID` / `OPEN_TLS_WIFI_PASSWORD`
   - `OPEN_TLS_MQTT_BROKER` (AWS IoT endpoint)
   - `OPEN_TLS_MQTT_TOPIC`
   - `OPEN_TLS_OTP_AES_KEY` (32-char hex key for command authentication)

2. **TLS Certificates** in `main/certs/`:
   - `aws-root-ca.pem` (included)
   - `my-tls-certificate.pem.crt` (user must provide, gitignored)
   - `my-tls-private.pem.key` (user must provide, gitignored)

3. **Hardware GPIO pins** in `main/open_tls.h` for LEDs, button, and door controls.

## Architecture

The main application flow (`open_tls_main.c`):
1. Initialize NVS, GPIO, button handling
2. Create GPIO task with watchdog monitoring
3. Connect to WiFi and sync time via NTP
4. Initialize command queue (`cmd.c`)
5. Connect to MQTT broker with mTLS (`mqtt.c`)
6. Subscribe to control topic and process incoming commands

Key modules:
- **mqtt.c**: MQTT client with embedded TLS certificates, handles connection and message routing
- **cmd.c**: Command queue with OTP-based authentication for physical actions
- **app_wifi.c**: WiFi connection and NTP time sync
- **t_gpio.c**: GPIO control for LEDs and door relay outputs
- **button.c**: Physical button input handling
- **periodical.c**: Periodic tasks and device status reporting

## Command Protocol

Commands are JSON messages with structure:
```json
{"command": <action_id>, "otp-auth": "<32-char-hex>"}
```
Action IDs: 1=open, 2=stop, 3=close, 4=open-stop-close, 5=force_report

The OTP is AES-encrypted timestamp validated within `OPEN_TLS_CMD_OTP_TOLERANCE` seconds.

## Target Hardware

ESP32-PICO-MINI-02 (ESP32-PICO-DevKitM-2). Custom partition table in `partitions.csv` allocates space for NVS, PHY init, FAT filesystem, and main application.
