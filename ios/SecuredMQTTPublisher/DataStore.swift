//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Combine

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
                                    actions: [.init(title: "", topic: "", message: ""),
                                              .init(title: "", topic: "", message: ""),
                                              .init(title: "", topic: "", message: ""),
                                              .init(title: "", topic: "", message: "")])
    
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
