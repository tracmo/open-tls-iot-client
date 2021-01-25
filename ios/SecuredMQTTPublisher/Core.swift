//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Combine
import UIKit

final class Core {
    enum PublishError: Error {
        case clientNotConnected(connectError: Error?)
    }
    
    static let shared = Core()
    
    let dataStore = DataStore.Keychained()
    
    @Published
    private(set) var state: SMPMQTTClient.State = .disconnected
    
    private lazy var client = SMPMQTTClient()
    
    @Published
    private(set) var connectError: Error?
    
    private var bag: Set<AnyCancellable> = []
    
    init() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.disconnect()
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in })
                .store(in: &self.bag)
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.connect()
                .sink(receiveCompletion: { _ in },
                      receiveValue: { _ in })
                .store(in: &self.bag)
        }
        
        connect()
            .sink(receiveCompletion: { _ in },
                  receiveValue: { _ in })
            .store(in: &bag)
        
        client.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.state = $0
            }
            .store(in: &bag)
        
        dataStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.disconnectThenConnect()
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { _ in },
                          receiveValue: { _ in })
                    .store(in: &self.bag)
            }
            .store(in: &bag)
    }
    
    private func disconnectThenConnect() -> AnyPublisher<Void, Error> {
        disconnect()
            .flatMap { self.connect() }
            .eraseToAnyPublisher()
    }
    
    private func connect() -> AnyPublisher<Void, Error> {
        NSLog("SMP connect")
        connectError = nil
        let settings = self.dataStore.settings
        return client.connect(endpoint: settings.endpoint,
                              clientID: settings.clientID,
                              certificate: settings.certificate,
                              privateKey: settings.privateKey,
                              rootCA: settings.rootCA)
            .handleEvents(receiveCompletion: { [weak self] in
                guard let self = self else { return }
                if let error = $0.getError() {
                    NSLog("SMP connect Failure: \(error)")
                    self.connectError = error
                } else {
                    NSLog("SMP connect Success")
                }
            })
            .eraseToAnyPublisher()
    }
    
    private func disconnect() -> AnyPublisher<Void, Error> {
        NSLog("SMP disconnect")
        return client.disconnect()
            .handleEvents(receiveCompletion: {
                if let error = $0.getError() {
                    NSLog("SMP disconnect Failure: \(error)")
                } else {
                    NSLog("SMP disconnect Success")
                }
            })
            .eraseToAnyPublisher()
    }
    
    func publish(message: String,
                 to topic: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            
            guard let timestampKey = self.dataStore.settings.timestampKey,
                  let rangeToReplace = message.range(of: "%T") else {
                self._publish(message: message, to: topic, promise: promise)
                return
            }
            
            AES128ECBTextEncrypter.encryptedTimestampInHex(keyInHex: timestampKey)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: {
                    guard let error = $0.getError() else { return }
                    promise(.failure(error))
                }, receiveValue: { [weak self] encryptedTimestampInHex in
                    guard let self = self else { return }
                    
                    var newMessage = message
                    newMessage.replaceSubrange(rangeToReplace, with: encryptedTimestampInHex)
                    
                    self._publish(message: newMessage, to: topic, promise: promise)
                })
                .store(in: &self.bag)
            
        }
        .eraseToAnyPublisher()
    }
    
    private func _publish(message: String,
                          to topic: String,
                          promise: @escaping Future<Void, Error>.Promise) {
        NSLog("SMP publish \"\(topic)\": \"\(message)\"")
        client.publish(message: message, to: topic)
            .mapError { error -> Error in
                guard let publishError = error as? SMPMQTTClient.PublishError,
                      publishError == .clientNotConnected else { return error }
                return PublishError.clientNotConnected(connectError: self.connectError) as Error
            }
            .sink(receiveCompletion: {
                if let error = $0.getError() {
                    NSLog("SMP publish \"\(topic)\": \"\(message)\" Failure: \(error)")
                    promise(.failure(error))
                } else {
                    NSLog("SMP publish \"\(topic)\": \"\(message)\" Success")
                }
            }, receiveValue: {
                promise(.success)
            })
            .store(in: &bag)
    }
}
