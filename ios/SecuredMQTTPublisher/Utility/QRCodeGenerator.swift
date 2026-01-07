//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import UIKit
import CoreImage

/// Generates QR codes for sharing NFC secrets securely between trusted devices.
final class QRCodeGenerator {

    /// Generates a QR code image from an NFC secret.
    /// The QR code contains: actionIndex, secret, and optional label
    /// Format: smpshare://secret?idx={index}&key={secret}&label={label}
    /// - Parameters:
    ///   - secret: The NFCSecret to encode
    ///   - actionIndex: The action button index (0-3)
    /// - Returns: UIImage of the QR code, or nil if generation fails
    static func generateQRCode(for secret: NFCSecret, actionIndex: Int) -> UIImage? {
        // Create URL-encoded payload
        var components = URLComponents()
        components.scheme = "smpshare"
        components.host = "secret"

        var queryItems = [
            URLQueryItem(name: "idx", value: "\(actionIndex)"),
            URLQueryItem(name: "key", value: secret.secret)
        ]

        if let label = secret.label {
            queryItems.append(URLQueryItem(name: "label", value: label))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            NSLog("QR: Failed to create share URL")
            return nil
        }

        let dataString = url.absoluteString
        NSLog("QR: Generating QR code for: \(dataString)")

        return generateQRCode(from: dataString)
    }

    /// Generates a QR code image from a string.
    /// - Parameter string: The string to encode
    /// - Returns: UIImage of the QR code, or nil if generation fails
    private static func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            NSLog("QR: Failed to create QR code generator filter")
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let ciImage = filter.outputImage else {
            NSLog("QR: Failed to generate QR code image")
            return nil
        }

        // Scale up the QR code for better quality
        let scale: CGFloat = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledCIImage = ciImage.transformed(by: transform)

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else {
            NSLog("QR: Failed to create CGImage from CIImage")
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Parses a QR code share URL and extracts the secret information.
    /// - Parameter url: The URL from the QR code
    /// - Returns: Tuple of (actionIndex, secret, label) or nil if invalid
    static func parseShareURL(_ url: URL) -> (actionIndex: Int, secret: String, label: String?)? {
        NSLog("QR: Parsing share URL: \(url.absoluteString)")

        // Check scheme
        guard url.scheme == "smpshare", url.host == "secret" else {
            NSLog("QR: Invalid URL scheme or host")
            return nil
        }

        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            NSLog("QR: Failed to parse URL components")
            return nil
        }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        // Extract required parameters
        guard let idxString = params["idx"],
              let actionIndex = Int(idxString),
              let secret = params["key"],
              !secret.isEmpty else {
            NSLog("QR: Missing required parameters")
            return nil
        }

        // Validate secret format (64 hex characters)
        guard secret.count == 64,
              secret.allSatisfy({ $0.isHexDigit }) else {
            NSLog("QR: Invalid secret format")
            return nil
        }

        let label = params["label"]

        NSLog("QR: Successfully parsed - idx=\(actionIndex), secret=\(secret.prefix(16))..., label=\(label ?? "nil")")
        return (actionIndex, secret, label)
    }
}
