//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation

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
                            password: String,
                            completionHandler: @escaping (Result<Data, ConvertError>) -> Void) {
        p12Data(fromPemCertificate: pemCertificate,
                                   pemPrivateKey: pemPrivateKey,
                                   password: password) { p12Data, error in
            if let p12Data = p12Data {
                completionHandler(.success(p12Data))
                return
            }
            guard let error = error,
                  let code = CertificateConverterErrorCode(rawValue: UInt((error as NSError).code)) else {
                completionHandler(.failure(.unknown))
                return
            }
            completionHandler(.failure(.init(code)))
        }
    }
    
    static func makeDERCertificateData(pemCertificate: String,
                                       completionHandler: @escaping (Result<Data, ConvertError>) -> Void) {
        derCertificateData(fromPemCertificate: pemCertificate) { derCertificateData, error in
            if let derCertificateData = derCertificateData {
                completionHandler(.success(derCertificateData))
                return
            }
            guard let error = error,
                  let code = CertificateConverterErrorCode(rawValue: UInt((error as NSError).code)) else {
                completionHandler(.failure(.unknown))
                return
            }
            completionHandler(.failure(.init(code)))
        }
    }
}
