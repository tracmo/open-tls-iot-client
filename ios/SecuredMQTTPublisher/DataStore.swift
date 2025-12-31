//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import Combine

/// Represents a single NFC secret configuration for an action
struct NFCSecret: Equatable, Codable, Hashable {
    var id: String          // UUID for identifying this secret
    var secret: String      // 32-byte hex string
    var createdAt: Date     // When this tag was configured
    var label: String?      // Optional user label (e.g., "Kitchen", "Bedroom")

    init(id: String = UUID().uuidString, secret: String, createdAt: Date = Date(), label: String? = nil) {
        self.id = id
        self.secret = secret
        self.createdAt = createdAt
        self.label = label
    }
}

struct Action: Equatable, Hashable {
    var title: String
    var topic: String
    var message: String
    var nfcSecrets: [NFCSecret]  // Up to 3 NFC secrets per action

    /// Maximum number of NFC tags per action
    static let maxNFCSecrets = 3

    /// Convenience check if any NFC is configured
    var hasNFCConfigured: Bool {
        !nfcSecrets.isEmpty
    }
}

// MARK: - Action Codable with Backward Compatibility

extension Action: Codable {
    enum CodingKeys: String, CodingKey {
        case title, topic, message
        case nfcSecret      // Legacy single secret
        case nfcSecrets     // New array of secrets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        topic = try container.decode(String.self, forKey: .topic)
        message = try container.decode(String.self, forKey: .message)

        // Try new format first
        if let secrets = try container.decodeIfPresent([NFCSecret].self, forKey: .nfcSecrets) {
            nfcSecrets = secrets
        }
        // Fall back to legacy single secret format
        else if let legacySecret = try container.decodeIfPresent(String.self, forKey: .nfcSecret),
                !legacySecret.isEmpty {
            // Migrate legacy secret to new format
            nfcSecrets = [NFCSecret(secret: legacySecret, label: "Migrated")]
        }
        // No NFC configured
        else {
            nfcSecrets = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(title, forKey: .title)
        try container.encode(topic, forKey: .topic)
        try container.encode(message, forKey: .message)

        // Always encode in new format
        try container.encode(nfcSecrets, forKey: .nfcSecrets)
    }
}

struct Settings: Equatable, Codable {
    var homeTitle: String
    var endpoint: String
    var clientID: String
    var certificate: String
    var privateKey: String
    var rootCA: String?
    var isBiometricAuthEnabled: Bool
    var isUnusedButtonHidden: Bool
    var timestampKey: String?
    var actions: [Action]
}

final class DataStore {
    @Published
    var settings: Settings
    
    init(settings: Settings) { self.settings = settings }
}

extension DataStore {
    final class Keychained {
        @Published
        var settings: Settings
        
        private var dataStore: DataStore
        
        private var bag = Set<AnyCancellable>()
        
        init() {
            let initialSettings = Settings.getFromKeychain() ?? .default
            settings = initialSettings
            dataStore = DataStore(settings: initialSettings)
            
            $settings
                .sink { [weak self] in
                    guard let self = self else { return }
                    self.dataStore.settings = $0
                }
                .store(in: &bag)
            dataStore.$settings
                .sink { $0.setToKeychain() }
                .store(in: &bag)
        }
    }
}

fileprivate extension Settings {
    static let `default` = Settings(homeTitle: "MQTT PUBS",
                                    endpoint: "",
                                    clientID: "SMP Client-\(UUID().uuidString)",
                                    certificate: "",
                                    privateKey: "",
                                    rootCA: nil,
                                    isBiometricAuthEnabled: false,
                                    isUnusedButtonHidden: false,
                                    timestampKey: nil,
                                    actions: [.init(title: "", topic: "", message: "", nfcSecrets: []),
                                              .init(title: "", topic: "", message: "", nfcSecrets: []),
                                              .init(title: "", topic: "", message: "", nfcSecrets: []),
                                              .init(title: "", topic: "", message: "", nfcSecrets: [])])
    
    static private let keychain = KeychainSwift()
    static private let keychainKey = "settings"
    
    static func getFromKeychain() -> Settings? {
        guard let data = keychain.getData(keychainKey) else { return nil }
        return try? JSONDecoder().decode(Settings.self, from: data)
    }
    
    func setToKeychain() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Settings.keychain.set(data, forKey: Settings.keychainKey)
    }
}
