//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/secured_mqtt_pub_ios
//  for the license and the contributors information.
//

import Foundation

final class Core {
    static let shared = Core()
    
    let dataStore = DataStore.Keychained()
    
    private lazy var client: SMPMQTTClient = MQTTSessionManagerClient()
    
    func connect(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        NSLog("SMP connect")
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
            }
            completionHandler($0)
        }
    }
    
    func disconnect(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        NSLog("SMP disconnect")
        client.disconnect {
            do {
                let _ = try $0.get()
                NSLog("SMP disconnect Success")
            } catch {
                NSLog("SMP disconnect Failure: \(error)")
            }
            completionHandler($0)
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
            } catch {
                NSLog("SMP publish \"\(topic)\": \"\(message)\" Failure: \(error)")
            }
            
            completionHandler($0)
        }
    }
}
