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
    
    private var publishCompletionHandlers: [UInt16: (Result<Void, Error>) -> Void] = [:]
    private let publishTimeout: TimeInterval = 5
    
    func connect(endpoint: String,
                 clientID: String,
                 certificate: String,
                 privateKey: String,
                 rootCA: String?,
                 completionHandler: @escaping (Result<Void, Error>) -> Void) {
        guard !endpoint.isEmpty else {
            completionHandler(.failure(ConnectError.endpointEmpty))
            return
        }
        guard !certificate.isEmpty else {
            completionHandler(.failure(ConnectError.certificateEmpty))
            return
        }
        guard !privateKey.isEmpty else {
            completionHandler(.failure(ConnectError.privateKeyEmpty))
            return
        }
        
        makeClientCertificates(certificate: certificate,
                               privateKey: privateKey) {
            do {
                let clientCertificates = try $0.get()
                self.makePolicy(rootCA: rootCA) {
                    do {
                        let policy = try $0.get()
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
                            completionHandler($0 == nil ? .success : .failure($0!))
                        }
                    } catch { completionHandler(.failure(error)) }
                }
            } catch { completionHandler(.failure(error)) }
        }
    }
    
    private func makeClientCertificates(certificate: String,
                                        privateKey: String,
                                        completionHandler: @escaping (Result<[Any], Error>) -> Void) {
        let p12Password = UUID().uuidString
        CertificateConverter.makeP12Data(pemCertificate: certificate,
                                         pemPrivateKey: privateKey,
                                         password: p12Password) {
            do {
                let clientP12Data = try $0.get()
                let clientCertificates = MQTTCFSocketTransport.clientCerts(fromP12Data: clientP12Data,
                                                                           passphrase: p12Password)
                completionHandler(clientCertificates == nil ?
                                    .failure(ConnectError.clientCertificatesCreateFailure) :
                                    .success(clientCertificates!))
            } catch { completionHandler(.failure(error)) }
        }
    }
    
    private func makePolicy(rootCA: String?,
                            completionHandler: @escaping (Result<MQTTSSLSecurityPolicy, Error>) -> Void) {
        guard let rootCA = rootCA else {
            completionHandler(.success(.init(pinningMode: .none)))
            return
        }
        
        CertificateConverter.makeDERCertificateData(pemCertificate: rootCA) {
            do {
                let rootCAData = try $0.get()
                
                let policy = MQTTSSLSecurityPolicy(pinningMode: .certificate)!
                policy.pinnedCertificates = [rootCAData]
                policy.allowInvalidCertificates = true
                policy.validatesCertificateChain = false
                
                completionHandler(.success(policy))
            } catch { completionHandler(.failure(error))}
        }
    }
    
    func disconnect(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        manager.disconnect { completionHandler($0 == nil ? .success : .failure($0!)) }
    }
    
    func publish(message: String,
                 to topic: String,
                 completionHandler: @escaping (Result<Void, Error>) -> Void) {
        guard !message.isEmpty else {
            completionHandler(.failure(PublishError.messageEmpty))
            return
        }
        guard !topic.isEmpty else {
            completionHandler(.failure(PublishError.topicEmpty))
            return
        }
        guard manager.state == .connected else {
            completionHandler(.failure(PublishError.clientNotConnected))
            return
        }
        let messageID = manager.send(message.data(using: .utf8),
                                     topic: topic,
                                     qos: .atLeastOnce,
                                     retain: false)
        publishCompletionHandlers[messageID] = completionHandler
        Timer.scheduledTimer(withTimeInterval: publishTimeout, repeats: false) { _ in
            guard let completionHandler = self.publishCompletionHandlers[messageID] else { return }
            self.publishCompletionHandlers[messageID] = nil
            completionHandler(.failure(PublishError.timeout))
        }
    }
    
    // MARK - MQTTSessionManagerDelegate
    
    func sessionManager(_ sessionManager: MQTTSessionManager!,
                        didDeliverMessage msgID: UInt16) {
        guard let completionHandler = publishCompletionHandlers[msgID] else { return }
        publishCompletionHandlers[msgID] = nil
        completionHandler(.success)
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
