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
    
    @discardableResult
    private func disconnectThenConnect() -> AnyPublisher<Void, Error> {
        disconnect().flatMap { self.connect() }.eraseToAnyPublisher()
    }
    
    @discardableResult
    func connect() -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            NSLog("SMP connect")
            self.connectError = nil
            let settings = self.dataStore.settings
            self.client.connect(endpoint: settings.endpoint,
                                clientID: settings.clientID,
                                certificate: settings.certificate,
                                privateKey: settings.privateKey,
                                rootCA: settings.rootCA) { [weak self] in
                guard let self = self else { return }
                do {
                    let _ = try $0.get()
                    NSLog("SMP connect Success")
                } catch {
                    NSLog("SMP connect Failure: \(error)")
                    self.connectError = error
                }
                promise($0)
            }
        }
        .eraseToAnyPublisher()
    }
    
    @discardableResult
    func disconnect() -> AnyPublisher<Void, Error> {
        Future<Void,Error> { [weak self] promise in
            guard let self = self else { return }
            NSLog("SMP disconnect")
            self.client.disconnect {
                do {
                    let _ = try $0.get()
                    NSLog("SMP disconnect Success")
                } catch {
                    NSLog("SMP disconnect Failure: \(error)")
                }
                promise($0)
            }
        }
        .eraseToAnyPublisher()
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
                if let publishError = error as? SMPMQTTClient.PublishError,
                   publishError == .clientNotConnected {
                    newError = PublishError.clientNotConnected(connectError: self.connectError)
                } else { newError = error }
                NSLog("SMP publish \"\(topic)\": \"\(message)\" Failure: \(newError)")
                completionHandler(.failure(newError))
            }
        }
    }
}
