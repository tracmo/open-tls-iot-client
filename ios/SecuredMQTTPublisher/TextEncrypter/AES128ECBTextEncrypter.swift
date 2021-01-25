//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import Combine

extension AES128ECBTextEncrypter {
    enum EncrypterError: Error {
        case keyFormatIncorrect
        case hexFormatIncorrect
        case initFailure
        case updateFailure
        case finalFailure
        case unknown
        
        fileprivate init(_ code: TextEncrypterErrorCode) {
            switch code {
            case .keyFormatIncorrect: self = .keyFormatIncorrect
            case .hexFormatIncorrect: self = .hexFormatIncorrect
            case .initFailure: self = .initFailure
            case .updateFailure: self = .updateFailure
            case .finalFailure: self = .finalFailure
            @unknown default: self = .unknown
            }
        }
    }
    
    static func encryptedTimestampInHex(keyInHex: String) -> AnyPublisher<String, EncrypterError> {
        Future<String, EncrypterError> { promise in
            encryptedTimestampInHexWithKey(inHex: keyInHex) { encryptedTimestampInHex, error in
                if let encryptedTimestampInHex = encryptedTimestampInHex {
                    promise(.success(encryptedTimestampInHex))
                    return
                }
                guard let error = error,
                      let code = TextEncrypterErrorCode(rawValue: UInt((error as NSError).code)) else {
                    promise(.failure(.unknown))
                    return
                }
                promise(.failure(.init(code)))
            }
        }
        .eraseToAnyPublisher()
    }
}
