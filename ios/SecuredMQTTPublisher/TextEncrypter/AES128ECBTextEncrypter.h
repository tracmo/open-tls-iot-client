//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, TextEncrypterErrorCode) {
    TextEncrypterErrorCodeKeyFormatIncorrect,
    TextEncrypterErrorCodeHexFormatIncorrect,
    TextEncrypterErrorCodeInitFailure,
    TextEncrypterErrorCodeUpdateFailure,
    TextEncrypterErrorCodeFinalFailure
};

@interface AES128ECBTextEncrypter : NSObject

+ (void)encryptedTimestampInHexWithKeyInHex:(nonnull NSString *)keyInHex
                          completionHandler:(nonnull void (^)(NSString * _Nullable, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
