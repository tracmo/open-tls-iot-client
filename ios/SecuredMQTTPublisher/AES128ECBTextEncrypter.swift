//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

import Foundation
import Combine
import CryptoSwift

enum AES128ECBTextEncrypter {
    enum EncrypterError: Error {
        case keyFormatIncorrect
    }
    
    static func encryptedTimestampInHex(keyInHex: String) -> AnyPublisher<String, Error> {
        // byte 4~7
        let timestampToSeconds = Int(Date().timeIntervalSince1970)
        let littleEndianTimestampByteValues = [0, 8, 16, 24].map { UInt8((timestampToSeconds >> $0) & 0xFF) }
        
        // byte 0~3 & byte 8~14 -> total 11 bytes
        let randomByteValues: [UInt8] = (0..<11).map { _ in UInt8((0..<256).randomElement()!) }
        
        // byte 0~3: random
        // byte 4~7: little endian timestamp to seconds
        // byte 8~14: random
        let byte0To14Values = randomByteValues.inserted(contentsOf: littleEndianTimestampByteValues, at: 4)
        
        // byte 15: (sum of byte 0~14) & 0xFF
        let byte0To14ValuesTotal: Int = byte0To14Values.reduce(0) { $0 + Int($1) }
        let byte15Value = UInt8(byte0To14ValuesTotal & 0xFF)
        
        let textToEncryptInHex =
            byte0To14Values.appended(byte15Value)
            .map { String($0, radix: 16) }
            .joined()
        
        return encryptedTextInHex(textInHex: textToEncryptInHex, keyInHex: keyInHex)
    }
    
    static private func encryptedTextInHex(textInHex: String, keyInHex: String) -> AnyPublisher<String, Error> {
        Future<String, Error> { promise in
            do {
                let aes = try AES(key: .init(hex: keyInHex),
                                  blockMode: ECB(),
                                  padding: .noPadding)
                let encryptedText = try aes.encrypt(.init(hex: textInHex))
                let encryptedTextInHex = encryptedText.toHexString()
                
                promise(.success(encryptedTextInHex))
                
            } catch AES.Error.invalidKeySize {
                promise(.failure(EncrypterError.keyFormatIncorrect))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}
