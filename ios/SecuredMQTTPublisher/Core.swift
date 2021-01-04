//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Combine

final class Core {
    enum PublishError: Error {
        case clientNotConnected(connectError: Error?)
    }
    
    static let shared = Core()
    
    let dataStore = DataStore.Keychained()
    
    private lazy var client: SMPMQTTClient = MQTTSessionManagerClient()
    
    @Published
    private(set) var connectError: Error?
    
    private var bag: Set<AnyCancellable> = []
    
    init() {
        connect()
        
        dataStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.disconnect { [weak self] _ in
                    guard let self = self else { return }
                    self.connect()
                }
            }
            .store(in: &bag)
    }
    
    func connect(completionHandler: ((Result<Void, Error>) -> Void)? = nil) {
        NSLog("SMP connect")
        connectError = nil
        client.connect(endpoint: dataStore.settings.endpoint,
                       clientID: dataStore.settings.clientID,
                       certificate: dataStore.settings.certificate,
                       privateKey: dataStore.settings.privateKey,
                       rootCA: dataStore.settings.rootCA) {
            do {
                let _ = try $0.get()
                NSLog("SMP connect Success")
            } catch {
                NSLog("SMP connect Failure: \(error)")
                self.connectError = error
            }
            completionHandler?($0)
        }
    }
    
    func disconnect(completionHandler: ((Result<Void, Error>) -> Void)? = nil) {
        NSLog("SMP disconnect")
        client.disconnect {
            do {
                let _ = try $0.get()
                NSLog("SMP disconnect Success")
            } catch {
                NSLog("SMP disconnect Failure: \(error)")
            }
            completionHandler?($0)
        }
    }
    
    func publish(message: String,
                 to topic: String,
                 completionHandler: @escaping (Result<Void, Error>) -> Void) {
        NSLog("SMP publish \"\(topic)\": \"\(message)\"")
        client.publish(message: message, to: topic) {
            do {
                let _ = try $0.get()
                NSLog("SMP publish \"\(topic)\": \"\(message)\" Success")
                completionHandler(.success)
            } catch {
                let newError: Error
                if let publishError = error as? MQTTSessionManagerClient.PublishError,
                   publishError == .clientNotConnected {
                    newError = PublishError.clientNotConnected(connectError: self.connectError)
                } else { newError = error }
                NSLog("SMP publish \"\(topic)\": \"\(message)\" Failure: \(newError)")
                completionHandler(.failure(newError))
            }
        }
    }
}
