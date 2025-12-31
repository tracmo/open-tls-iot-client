//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation

/// Debug logging for NFC flow - only logs in DEBUG builds
@inline(__always)
func NFCDebugLog(_ message: String) {
    #if DEBUG
    NSLog("NFC-DEBUG: \(message)")
    #endif
}

/// Debug logging for SMP/MQTT - only logs in DEBUG builds
@inline(__always)
func SMPDebugLog(_ message: String) {
    #if DEBUG
    NSLog("SMP: \(message)")
    #endif
}
