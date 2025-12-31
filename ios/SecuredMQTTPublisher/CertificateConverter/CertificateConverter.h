//
//  Project Secured MQTT Publisher
//  Copyright 2026 Care Active Corp ("Care Active").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CertificateConverterErrorCode) {
    CertificateConverterErrorCodeCertificateFormatIncorrect,
    CertificateConverterErrorCodePrivateKeyFormatIncorrect,
    CertificateConverterErrorCodeCertificateAndPrivateKeyMismatch,
    CertificateConverterErrorCodeP12CreateFailure
};

@interface CertificateConverter : NSObject

+ (void)p12DataFromPemCertificate:(nonnull NSString *)pemCertificate
                    pemPrivateKey:(nonnull NSString *)pemPrivateKey
                         password:(nonnull NSString *)password
                completionHandler:(nonnull void (^)(NSData * _Nullable, NSError * _Nullable error))completionHandler;

+ (void)derCertificateDataFromPemCertificate:(nonnull NSString *)pemCertificate
                           completionHandler:(nonnull void (^)(NSData * _Nullable, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
