//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import Combine

extension CertificateConverter {
    enum ConvertError: Error {
        case certificateFormatIncorrect
        case privateKeyFormatIncorrect
        case certificateAndPrivateKeyMismatch
        case p12CreateFailure
        case unknown
        
        fileprivate init(_ code: CertificateConverterErrorCode) {
            switch code {
            case .certificateFormatIncorrect: self = .certificateFormatIncorrect
            case .privateKeyFormatIncorrect: self = .privateKeyFormatIncorrect
            case .certificateAndPrivateKeyMismatch: self = .certificateAndPrivateKeyMismatch
            case .p12CreateFailure: self = .p12CreateFailure
            @unknown default: self = .unknown
            }
        }
    }
    
    static func makeP12Data(pemCertificate: String,
                            pemPrivateKey: String,
                            password: String) -> AnyPublisher<Data, ConvertError> {
        Future<Data, ConvertError> { promise in
            p12Data(fromPemCertificate: pemCertificate,
                    pemPrivateKey: pemPrivateKey,
                    password: password) { p12Data, error in
                if let p12Data = p12Data {
                    promise(.success(p12Data))
                    return
                }
                guard let error = error,
                      let code = CertificateConverterErrorCode(rawValue: UInt((error as NSError).code)) else {
                    promise(.failure(.unknown))
                    return
                }
                promise(.failure(.init(code)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    static func makeDERCertificateData(pemCertificate: String) -> AnyPublisher<Data, ConvertError> {
        Future<Data, ConvertError> { promise in
            derCertificateData(fromPemCertificate: pemCertificate) { derCertificateData, error in
                if let derCertificateData = derCertificateData {
                    promise(.success(derCertificateData))
                    return
                }
                guard let error = error,
                      let code = CertificateConverterErrorCode(rawValue: UInt((error as NSError).code)) else {
                    promise(.failure(.unknown))
                    return
                }
                promise(.failure(.init(code)))
            }
        }
        .eraseToAnyPublisher()
    }
}
