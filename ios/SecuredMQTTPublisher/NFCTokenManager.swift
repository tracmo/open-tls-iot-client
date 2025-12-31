//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import CryptoKit

// MARK: - Data Extension for Hex String Conversion

extension Data {
    /// Initialize Data from a hex string
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }

    /// Convert Data to lowercase hex string
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - NFCTokenManager

/// Manages NFC URL generation and validation for action triggers.
///
/// Security model:
/// - Each action button has its own secret (32 random bytes, hex encoded)
/// - URLs contain: action index, Unix timestamp, HMAC-SHA256 signature
/// - Signatures are valid for ±2 minutes to account for clock drift
/// - Regenerating a secret invalidates all previously written tags for that button
final class NFCTokenManager {

    /// URL scheme used for NFC triggers
    static let urlScheme = "smp"

    /// Validity window for timestamps (±120 seconds)
    static let validityWindowSeconds: TimeInterval = 120

    // MARK: - URL Generation

    /// Generates a signed NFC URL for an action.
    /// - Parameter actionIndex: The index of the action (0-3)
    /// - Returns: The complete URL string, or nil if the action doesn't exist or has no secret
    static func generateURL(for actionIndex: Int) -> String? {
        let actions = Core.shared.dataStore.settings.actions
        guard actionIndex >= 0 && actionIndex < actions.count else {
            NSLog("NFC: Invalid action index \(actionIndex) for URL generation")
            return nil
        }

        guard let secret = actions[actionIndex].nfcSecret, !secret.isEmpty else {
            NSLog("NFC: No secret configured for action \(actionIndex)")
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = "idx=\(actionIndex)&ts=\(timestamp)"

        guard let signature = computeSignature(payload: payload, secretHex: secret) else {
            NSLog("NFC: Failed to compute signature for action \(actionIndex)")
            return nil
        }

        return "\(urlScheme)://action?idx=\(actionIndex)&ts=\(timestamp)&sig=\(signature)"
    }

    /// Generates a new random secret and creates a URL for an action.
    /// - Parameter actionIndex: The index of the action (0-3)
    /// - Returns: Tuple of (URL string, new secret), or nil if generation fails
    static func generateURLWithNewSecret(for actionIndex: Int) -> (url: String, secret: String)? {
        let actions = Core.shared.dataStore.settings.actions
        guard actionIndex >= 0 && actionIndex < actions.count else {
            NSLog("NFC: Invalid action index \(actionIndex) for new secret generation")
            return nil
        }

        let newSecret = generateRandomSecret()
        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = "idx=\(actionIndex)&ts=\(timestamp)"

        guard let signature = computeSignature(payload: payload, secretHex: newSecret) else {
            NSLog("NFC: Failed to compute signature with new secret for action \(actionIndex)")
            return nil
        }

        let url = "\(urlScheme)://action?idx=\(actionIndex)&ts=\(timestamp)&sig=\(signature)"
        return (url, newSecret)
    }

    // MARK: - URL Validation

    /// Validates an NFC URL and returns the action index if valid.
    /// - Parameter url: The URL to validate
    /// - Returns: The action index if valid, nil if invalid
    static func validateURL(_ url: URL) -> Int? {
        NSLog("NFC: Validating URL: \(url.absoluteString)")

        // Check scheme
        guard url.scheme == urlScheme else {
            NSLog("NFC: Invalid scheme: \(url.scheme ?? "nil")")
            return nil
        }

        // Check host
        guard url.host == "action" else {
            NSLog("NFC: Invalid host: \(url.host ?? "nil")")
            return nil
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            NSLog("NFC: Failed to parse URL components")
            return nil
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        // Extract required parameters
        guard let idxString = params["idx"],
              let actionIndex = Int(idxString),
              let tsString = params["ts"],
              let timestamp = Int(tsString),
              let signature = params["sig"] else {
            NSLog("NFC: Missing required parameters (idx, ts, sig)")
            return nil
        }

        // Validate action index bounds
        let actions = Core.shared.dataStore.settings.actions
        guard actionIndex >= 0 && actionIndex < actions.count else {
            NSLog("NFC: Action index \(actionIndex) out of bounds")
            return nil
        }

        // Get secret for this action
        guard let secret = actions[actionIndex].nfcSecret, !secret.isEmpty else {
            NSLog("NFC: No secret configured for action \(actionIndex)")
            return nil
        }

        // Validate timestamp (within ±2 minutes)
        let currentTime = Int(Date().timeIntervalSince1970)
        let timeDifference = abs(currentTime - timestamp)
        guard timeDifference <= Int(validityWindowSeconds) else {
            NSLog("NFC: Timestamp expired. Tag time: \(timestamp), current: \(currentTime), diff: \(timeDifference)s")
            return nil
        }

        // Verify signature
        let payload = "idx=\(actionIndex)&ts=\(timestamp)"
        guard let expectedSignature = computeSignature(payload: payload, secretHex: secret) else {
            NSLog("NFC: Failed to compute expected signature")
            return nil
        }

        guard signature.lowercased() == expectedSignature.lowercased() else {
            NSLog("NFC: Signature mismatch")
            return nil
        }

        NSLog("NFC: URL validated successfully for action \(actionIndex)")
        return actionIndex
    }

    // MARK: - Secret Generation

    /// Generates a new random 32-byte secret as a hex string.
    /// - Returns: 64-character lowercase hex string
    static func generateRandomSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).hexString
    }

    // MARK: - Private Helpers

    /// Computes HMAC-SHA256 signature for a payload.
    /// - Parameters:
    ///   - payload: The string payload to sign
    ///   - secretHex: The secret key as a hex string
    /// - Returns: The signature as a lowercase hex string, or nil if computation fails
    private static func computeSignature(payload: String, secretHex: String) -> String? {
        guard let secretData = Data(hexString: secretHex) else {
            NSLog("NFC: Invalid hex secret")
            return nil
        }

        guard let payloadData = payload.data(using: .utf8) else {
            NSLog("NFC: Failed to encode payload")
            return nil
        }

        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)

        return Data(signature).hexString
    }
}
