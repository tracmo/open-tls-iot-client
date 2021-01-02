//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/secured_mqtt_pub_ios
//  for the license and the contributors information.
//

import Foundation

struct Action: Equatable, Codable, Hashable {
    var title: String
    var topic: String
    var message: String
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
    lazy var settings: Settings = { getSettingsFromKeychain() ?? defaultSettings }() {
        didSet {
            guard oldValue != settings else { return }
            setSettingsToKeychain()
        }
    }
    
    private lazy var defaultSettings: Settings = {
        .init(homeTitle: "MQTT PUBS",
              endpoint: "",
              clientID: "SMP Client-\(UUID().uuidString)",
              certificate: "",
              privateKey: "",
              rootCA: nil,
              isBiometricAuthEnabled: false,
              isUnusedButtonHidden: false,
              timestampKey: nil,
              actions: [.init(title: "", topic: "", message: ""),
                        .init(title: "", topic: "", message: ""),
                        .init(title: "", topic: "", message: ""),
                        .init(title: "", topic: "", message: "")])
    }()
    
    private lazy var keychain = KeychainSwift()
    
    private let keychainKeySettings = "settings"
    
    private func getSettingsFromKeychain() -> Settings? {
        guard let settingsData = keychain.getData(keychainKeySettings) else { return nil }
        return try? JSONDecoder().decode(Settings.self, from: settingsData)
    }
    
    private func setSettingsToKeychain() {
        guard let settingsData = try? JSONEncoder().encode(settings) else { return }
        keychain.set(settingsData, forKey: keychainKeySettings)
    }
}
