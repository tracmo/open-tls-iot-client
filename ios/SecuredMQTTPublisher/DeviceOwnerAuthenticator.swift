//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import LocalAuthentication
import Combine

enum DeviceOwnerAuthenticator {
    enum EvaluateError: Error {
        case unknown
    }
    
    static func getBiometryType() -> LABiometryType {
        let context = LAContext()
        context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }
    
    static func auth() -> AnyPublisher<Void, Error> {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        
        var canEvaluateError: NSError? = nil
        let canEvaluate = context.canEvaluatePolicy(policy,
                                                    error: &canEvaluateError)
        
        guard canEvaluate else {
            return Fail(error: canEvaluateError ?? EvaluateError.unknown as Error)
                .eraseToAnyPublisher()
        }
        
        return Future<Void, Error> { promise in
            context.evaluatePolicy(policy,
                                   localizedReason: "Authentication with Face ID") { isSucceeded, error in
                promise(isSucceeded ?
                            .success :
                            .failure(error ?? EvaluateError.unknown))
            }
        }
        .eraseToAnyPublisher()
    }
}
