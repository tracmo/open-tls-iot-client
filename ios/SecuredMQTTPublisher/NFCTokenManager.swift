//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
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

/// Result of URL validation
enum NFCValidationResult {
    /// URL is valid - execute the action
    case valid(actionIndex: Int)
    /// URL signature matches a known secret - import not needed
    case alreadyConfigured(actionIndex: Int)
    /// URL contains a valid secret that can be imported
    case importAvailable(actionIndex: Int, secret: String)
    /// URL is invalid (bad signature, expired, missing params, etc.)
    case invalid(reason: String)
}

/// Manages NFC URL generation and validation for action triggers.
///
/// Security model:
/// - Each action button can have up to 3 secrets (32 random bytes each, hex encoded)
/// - URLs contain: action index, Unix timestamp, HMAC-SHA256 signature, and the secret key
/// - Including the secret in the URL enables cross-phone import functionality
/// - The HMAC signature ensures only tags written by the app are valid
/// - Removing a secret invalidates all tags written with that secret
///
/// Note: Timestamps are included in URLs but NOT validated for expiry. NFC tags are
/// permanent triggers and should work indefinitely. The HMAC signature provides security.
final class NFCTokenManager {

    /// URL scheme used for NFC triggers
    static let urlScheme = "smp"

    // MARK: - URL Generation

    /// Generates a signed NFC URL for an action using an existing secret.
    /// - Parameters:
    ///   - actionIndex: The index of the action (0-3)
    ///   - secret: The NFCSecret to use for signing
    /// - Returns: The complete URL string, or nil if generation fails
    static func generateURL(for actionIndex: Int, using secret: NFCSecret) -> String? {
        let actions = Core.shared.dataStore.settings.actions
        guard actionIndex >= 0 && actionIndex < actions.count else {
            NSLog("NFC: Invalid action index \(actionIndex) for URL generation")
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = "idx=\(actionIndex)&ts=\(timestamp)"

        guard let signature = computeSignature(payload: payload, secretHex: secret.secret) else {
            NSLog("NFC: Failed to compute signature for action \(actionIndex)")
            return nil
        }

        // Include secret in URL for cross-phone import capability
        return "\(urlScheme)://action?idx=\(actionIndex)&ts=\(timestamp)&sig=\(signature)&key=\(secret.secret)"
    }

    /// Generates a new NFCSecret and creates a URL for an action.
    /// - Parameters:
    ///   - actionIndex: The index of the action (0-3)
    ///   - label: Optional label for the new secret (e.g., "Kitchen", "Bedroom")
    /// - Returns: Tuple of (URL string, new NFCSecret), or nil if generation fails
    static func generateURLWithNewSecret(for actionIndex: Int, label: String? = nil) -> (url: String, secret: NFCSecret)? {
        let actions = Core.shared.dataStore.settings.actions
        guard actionIndex >= 0 && actionIndex < actions.count else {
            NSLog("NFC: Invalid action index \(actionIndex) for new secret generation")
            return nil
        }

        let newSecretString = generateRandomSecret()
        let newSecret = NFCSecret(secret: newSecretString, label: label)

        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = "idx=\(actionIndex)&ts=\(timestamp)"

        guard let signature = computeSignature(payload: payload, secretHex: newSecretString) else {
            NSLog("NFC: Failed to compute signature with new secret for action \(actionIndex)")
            return nil
        }

        // Include secret in URL for cross-phone import capability
        let url = "\(urlScheme)://action?idx=\(actionIndex)&ts=\(timestamp)&sig=\(signature)&key=\(newSecretString)"
        return (url, newSecret)
    }

    // MARK: - URL Validation

    /// Validates an NFC URL and returns a validation result.
    /// - Parameter url: The URL to validate
    /// - Returns: NFCValidationResult indicating success, import availability, or failure
    static func validateURL(_ url: URL) -> NFCValidationResult {
        NFCDebugLog("========== VALIDATION START ==========")
        NFCDebugLog("URL: \(url.absoluteString)")

        // Check scheme
        guard url.scheme == urlScheme else {
            NFCDebugLog("❌ Invalid scheme: \(url.scheme ?? "nil"), expected: \(urlScheme)")
            return .invalid(reason: "Invalid URL scheme")
        }
        NFCDebugLog("✓ Scheme OK: \(urlScheme)")

        // Check host
        guard url.host == "action" else {
            NFCDebugLog("❌ Invalid host: \(url.host ?? "nil"), expected: action")
            return .invalid(reason: "Invalid URL host")
        }
        NFCDebugLog("✓ Host OK: action")

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            NFCDebugLog("❌ Failed to parse URL components")
            return .invalid(reason: "Failed to parse URL")
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        NFCDebugLog("Parsed params: \(params.keys.joined(separator: ", "))")

        // Extract required parameters
        guard let idxString = params["idx"],
              let actionIndex = Int(idxString),
              let tsString = params["ts"],
              let timestamp = Int(tsString),
              let signature = params["sig"] else {
            NFCDebugLog("❌ Missing required parameters. Have: idx=\(params["idx"] ?? "nil"), ts=\(params["ts"] ?? "nil"), sig=\(params["sig"] != nil ? "present" : "nil")")
            return .invalid(reason: "Missing required parameters")
        }
        NFCDebugLog("✓ Params OK: idx=\(actionIndex), ts=\(timestamp), sig=\(signature.prefix(16))...")

        // Extract optional key parameter (for cross-phone import)
        let keyFromURL = params["key"]
        NFCDebugLog("Key param: \(keyFromURL != nil ? "present (\(keyFromURL!.prefix(16))...)" : "nil")")

        // Validate action index bounds
        let actions = Core.shared.dataStore.settings.actions
        NFCDebugLog("Total actions in DataStore: \(actions.count)")
        guard actionIndex >= 0 && actionIndex < actions.count else {
            NFCDebugLog("❌ Action index \(actionIndex) out of bounds (0..<\(actions.count))")
            return .invalid(reason: "Invalid action index")
        }
        NFCDebugLog("✓ Action index OK: \(actionIndex)")

        let action = actions[actionIndex]
        NFCDebugLog("Action[\(actionIndex)]: title='\(action.title)', topic='\(action.topic)'")
        NFCDebugLog("Action[\(actionIndex)] has \(action.nfcSecrets.count) NFC secrets configured")

        let payload = "idx=\(actionIndex)&ts=\(timestamp)"
        NFCDebugLog("Payload for signature: \(payload)")

        // Try to validate against all configured secrets for this action
        for (i, nfcSecret) in action.nfcSecrets.enumerated() {
            NFCDebugLog("Checking secret[\(i)]: id=\(nfcSecret.id), label=\(nfcSecret.label ?? "nil"), secret=\(nfcSecret.secret.prefix(16))...")
            if let expectedSignature = computeSignature(payload: payload, secretHex: nfcSecret.secret) {
                NFCDebugLog("Expected sig: \(expectedSignature.prefix(16))...")
                NFCDebugLog("Received sig: \(signature.lowercased().prefix(16))...")
                if signature.lowercased() == expectedSignature.lowercased() {
                    NFCDebugLog("✓✓✓ SIGNATURE MATCH! Validation SUCCESS")
                    return .valid(actionIndex: actionIndex)
                } else {
                    NFCDebugLog("✗ Signature mismatch for this secret")
                }
            } else {
                NFCDebugLog("✗ Failed to compute signature for this secret")
            }
        }

        // No local secret matched - check if URL contains a key we can use/import
        if let key = keyFromURL, !key.isEmpty {
            NFCDebugLog("No local secret matched, trying key from URL...")
            // Verify the signature using the key from URL
            if let expectedSignature = computeSignature(payload: payload, secretHex: key) {
                NFCDebugLog("Expected sig from URL key: \(expectedSignature.prefix(16))...")
                if signature.lowercased() == expectedSignature.lowercased() {
                    // Check if this key is already in our secrets
                    if action.nfcSecrets.contains(where: { $0.secret == key }) {
                        NFCDebugLog("✓ URL key matches and already configured")
                        return .alreadyConfigured(actionIndex: actionIndex)
                    }
                    NFCDebugLog("✓ URL key valid, available for import")
                    return .importAvailable(actionIndex: actionIndex, secret: key)
                }
            }
            NFCDebugLog("✗ URL key signature also doesn't match")
        }

        // No valid secret found
        if action.nfcSecrets.isEmpty {
            NFCDebugLog("❌ VALIDATION FAILED: No secrets configured for action \(actionIndex)")
            return .invalid(reason: "No NFC configured for this button")
        } else {
            NFCDebugLog("❌ VALIDATION FAILED: Signature mismatch (tried \(action.nfcSecrets.count) secrets)")
            return .invalid(reason: "Invalid signature")
        }
    }

    /// Simple validation that returns just the action index (for backward compatibility).
    /// Use this when you only need to check if the URL is valid for execution.
    /// - Parameter url: The URL to validate
    /// - Returns: The action index if valid, nil if invalid
    static func validateURLSimple(_ url: URL) -> Int? {
        switch validateURL(url) {
        case .valid(let actionIndex):
            return actionIndex
        case .alreadyConfigured(let actionIndex):
            return actionIndex
        case .importAvailable(let actionIndex, _):
            // Import available means the URL is technically valid, allow execution
            return actionIndex
        case .invalid:
            return nil
        }
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
