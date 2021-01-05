//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import MQTTClient
import Combine

final class SMPMQTTClient: NSObject, MQTTSessionManagerDelegate {
    enum State {
        case disconnected
        case connected
        case connecting
    }
    
    enum ConnectError: Error {
        case endpointEmpty
        case certificateEmpty
        case privateKeyEmpty
        case clientCertificatesCreateFailure
    }
    
    enum PublishError: Error {
        case messageEmpty
        case topicEmpty
        case clientNotConnected
        case timeout
    }
    
    @Published
    private(set) var state: State = .disconnected
    
    private lazy var manager: MQTTSessionManager = {
        let manager = MQTTSessionManager(persistence: false,
                                         maxWindowSize: 14,
                                         maxMessages: 1024,
                                         maxSize: 64 * 1024 * 1024,
                                         maxConnectionRetryInterval: 64,
                                         connectInForeground: false,
                                         streamSSLLevel: kCFStreamSocketSecurityLevelNegotiatedSSL as String,
                                         queue: .main)!
        manager.delegate = self
        return manager
    }()
    
    private var publishPromises: [UInt16: Future<Void, Error>.Promise] = [:]
    private let publishTimeout: TimeInterval = 5
    
    private var bag = Set<AnyCancellable>()
    
    func connect(endpoint: String,
                 clientID: String,
                 certificate: String,
                 privateKey: String,
                 rootCA: String?) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            
            guard !endpoint.isEmpty else {
                promise(.failure(ConnectError.endpointEmpty))
                return
            }
            guard !certificate.isEmpty else {
                promise(.failure(ConnectError.certificateEmpty))
                return
            }
            guard !privateKey.isEmpty else {
                promise(.failure(ConnectError.privateKeyEmpty))
                return
            }
            
            self.makeClientCertificates(certificate: certificate,
                                        privateKey: privateKey)
                .combineLatest(self.makePolicy(rootCA: rootCA))
                .sink(receiveCompletion: { 
                    guard let error = $0.getError() else { return }
                    promise(.failure(error))
                }, receiveValue: { [weak self] clientCertificates, policy in
                    guard let self = self else { return }
                    
                    self.manager.connect(to: endpoint,
                                         port: 8883,
                                         tls: true,
                                         keepalive: 60,
                                         clean: true,
                                         auth: false,
                                         user: nil,
                                         pass: nil,
                                         will: false,
                                         willTopic: nil,
                                         willMsg: nil,
                                         willQos: .atMostOnce,
                                         willRetainFlag: false,
                                         withClientId: clientID,
                                         securityPolicy: policy,
                                         certificates: clientCertificates,
                                         protocolLevel: .version311) {
                        promise($0 == nil ? .success : .failure($0!))
                    }
                })
                .store(in: &self.bag)
        }
        .eraseToAnyPublisher()
    }
    
    private func makeClientCertificates(certificate: String,
                                        privateKey: String) -> AnyPublisher<[Any], Error> {
        Future<[Any], Error> { promise in
            let p12Password = UUID().uuidString
            CertificateConverter.makeP12Data(pemCertificate: certificate,
                                             pemPrivateKey: privateKey,
                                             password: p12Password) {
                do {
                    let clientP12Data = try $0.get()
                    let clientCertificates = MQTTCFSocketTransport.clientCerts(fromP12Data: clientP12Data,
                                                                               passphrase: p12Password)
                    promise(clientCertificates == nil ?
                                .failure(ConnectError.clientCertificatesCreateFailure) :
                                .success(clientCertificates!))
                } catch { promise(.failure(error)) }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func makePolicy(rootCA: String?) -> AnyPublisher<MQTTSSLSecurityPolicy, Error> {
        Future<MQTTSSLSecurityPolicy, Error> { promise in
            guard let rootCA = rootCA else {
                promise(.success(.init(pinningMode: .none)))
                return
            }
            
            CertificateConverter.makeDERCertificateData(pemCertificate: rootCA) {
                do {
                    let rootCAData = try $0.get()
                    
                    let policy = MQTTSSLSecurityPolicy(pinningMode: .certificate)!
                    policy.pinnedCertificates = [rootCAData]
                    policy.allowInvalidCertificates = true
                    policy.validatesCertificateChain = false
                    
                    promise(.success(policy))
                } catch { promise(.failure(error))}
            }
        }
        .eraseToAnyPublisher()
    }
    
    func disconnect() -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            self.manager.disconnect { promise($0 == nil ? .success : .failure($0!)) }
        }
        .eraseToAnyPublisher()
    }
    
    func publish(message: String,
                 to topic: String) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self = self else { return }
            
            guard !message.isEmpty else {
                promise(.failure(PublishError.messageEmpty))
                return
            }
            guard !topic.isEmpty else {
                promise(.failure(PublishError.topicEmpty))
                return
            }
            guard self.manager.state == .connected else {
                promise(.failure(PublishError.clientNotConnected))
                return
            }
            let messageID = self.manager.send(message.data(using: .utf8),
                                              topic: topic,
                                              qos: .atLeastOnce,
                                              retain: false)
            self.publishPromises[messageID] = promise
            Timer.scheduledTimer(withTimeInterval: self.publishTimeout, repeats: false) { _ in
                guard let promise = self.publishPromises[messageID] else { return }
                self.publishPromises[messageID] = nil
                promise(.failure(PublishError.timeout))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK - MQTTSessionManagerDelegate
    
    func sessionManager(_ sessionManager: MQTTSessionManager!,
                        didDeliverMessage msgID: UInt16) {
        guard let promise = publishPromises[msgID] else { return }
        publishPromises[msgID] = nil
        promise(.success)
    }
    
    func sessionManager(_ sessionManager: MQTTSessionManager!,
                        didChange newState: MQTTSessionManagerState) {
        NSLog("SMP manager didChangeState state: \(newState)")
        state = .init(newState)
    }
}

extension SMPMQTTClient.State {
    init(_ state: MQTTSessionManagerState) {
        switch state {
        case .starting,
             .error,
             .closing,
             .closed: self = .disconnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        @unknown default: self = .disconnected
        }
    }
}

extension MQTTSessionManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .starting: return ".starting"
        case .connecting: return ".connecting"
        case .error: return ".error"
        case .connected: return ".connected"
        case .closing: return ".closing"
        case .closed: return ".closed"
        @unknown default: return "\(rawValue)"
        }
    }
}
