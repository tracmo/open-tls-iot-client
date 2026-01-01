# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the `test_tools` subdirectory of the open-tls-iot-client project. It contains Go-based MQTT testing tools to simulate IoT device communication before building physical hardware. The tools connect to AWS IoT Core using TLS with X.509 client certificates.

## Running the Test Tools

Both tools are standalone Go programs:

```bash
# Run subscriber (start first)
cd subscriber
go run main.go

# Run publisher (in separate terminal)
cd publisher
go run main.go
```

The subscriber must be started before the publisher. Both connect to AWS IoT Core on port 8883 with TLS.

## Certificate Setup

Before running, you must:
1. Place your AWS IoT device certificate (`my-certificate.pem.crt`) and private key (`my-private.pem.key`) in the `test_tools/` directory
2. Update the `host` variable in both `main.go` files to your AWS IoT endpoint

The tools look for certificates at `../my-certificate.pem.crt` and `../my-private.pem.key` relative to their directories.

## Architecture

- **subscriber/main.go** - Subscribes to `securedios/demo` topic and logs received messages
- **publisher/main.go** - Publishes incrementing counter every second to `securedios/demo` topic
- **aws-root-ca.pem** - AWS IoT Root CA for TLS verification (optional - verification is skipped if missing)
- **gtsltsr.pem** - Google Cloud Root CA (for testing certificate mismatch behavior)

Both tools use the `github.com/eclipse/paho.mqtt.golang` MQTT library with identical TLS configuration patterns.

## Root CA Verification

Root CA verification is optional. If `aws-root-ca.pem` exists, TLS verification is performed. If removed, verification is skipped. You can swap in `gtsltsr.pem` (Google's CA) to test certificate rejection behavior.

## Parent Project Structure

This repository contains multiple components for a complete IoT solution:

| Directory | Purpose |
|-----------|---------|
| `ios/` | iOS MQTT client app with biometric auth and NFC triggers |
| `esp32/` | ESP32 firmware (ESP-IDF v3.3 and v4.2 variants) |
| `ifttt_webhook/` | AWS Lambda function for IoT Core Rule Engine → IFTTT |
| `test_tools/` | This directory - Go MQTT testing tools |

See the iOS app's CLAUDE.md at `../ios/CLAUDE.md` for detailed iOS architecture.
