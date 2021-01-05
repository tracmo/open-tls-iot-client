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
    
    @Published
    private(set) var state: SMPMQTTClient.State = .disconnected
    
    private lazy var client = SMPMQTTClient()
    
    @Published
    private(set) var connectError: Error?
    
    private var bag: Set<AnyCancellable> = []
    
    init() {
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
    
    func connect() -> AnyPublisher<Void, Error> {
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
    
    func disconnect() -> AnyPublisher<Void, Error> {
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
        NSLog("SMP publish \"\(topic)\": \"\(message)\"")
        return client.publish(message: message, to: topic)
            .mapError {
                guard let publishError = $0 as? SMPMQTTClient.PublishError,
                      publishError == .clientNotConnected else { return $0 }
                return PublishError.clientNotConnected(connectError: self.connectError) as Error
            }
            .handleEvents(receiveCompletion: {
                if let error = $0.getError() {
                    NSLog("SMP publish \"\(topic)\": \"\(message)\" Failure: \(error)")
                } else {
                    NSLog("SMP publish \"\(topic)\": \"\(message)\" Success")
                }
            })
            .eraseToAnyPublisher()
    }
}
