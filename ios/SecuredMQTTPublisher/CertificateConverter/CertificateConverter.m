//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/secured_mqtt_pub_ios
//  for the license and the contributors information.
//

#import "CertificateConverter.h"

#import <openssl/pem.h>
#import <openssl/pkcs12.h>
#import <openssl/x509.h>

@implementation CertificateConverter

+ (void)p12DataFromPemCertificate:(nonnull NSString *)pemCertificate
                    pemPrivateKey:(nonnull NSString *)pemPrivateKey
                         password:(nonnull NSString *)password
                completionHandler:(nonnull void (^)(NSData * _Nullable, NSError * _Nullable error))completionHandler {
    
    // Read certificate
    
    BIO *certificateBuffer = BIO_new(BIO_s_mem());
    const char *certificateChars = [pemCertificate cStringUsingEncoding:NSUTF8StringEncoding];
    BIO_puts(certificateBuffer, certificateChars);
    
    X509 *certificate;
    certificate = PEM_read_bio_X509(certificateBuffer, NULL, 0, NULL);
    BIO_free(certificateBuffer);
    
    if (certificate == NULL) {
        completionHandler(nil, [self errorWithCode:CertificateConverterErrorCodeCertificateFormatIncorrect]);
        return;
    }
    
    // Read private key
    
    BIO *privateKeyBuffer = BIO_new(BIO_s_mem());
    const char *privateKeyChars = [pemPrivateKey cStringUsingEncoding:NSUTF8StringEncoding];
    BIO_puts(privateKeyBuffer, privateKeyChars);
    
    EVP_PKEY *privateKey;
    privateKey = PEM_read_bio_PrivateKey(privateKeyBuffer, NULL, 0, NULL);
    BIO_free(privateKeyBuffer);
    
    if (privateKey == NULL) {
        completionHandler(nil, [self errorWithCode:CertificateConverterErrorCodePrivateKeyFormatIncorrect]);
        return;
    }
    
    // Check certificate and private key is matching
    
    if (!X509_check_private_key(certificate, privateKey)) {
        completionHandler(nil, [self errorWithCode:CertificateConverterErrorCodeCertificateAndPrivateKeyMismatch]);
        return;
    }
    
    // Make P12
    
    // Setup algorithms
    SSLeay_add_all_algorithms();
    
    PKCS12 *p12;
    const char *constPasswordChars = [password cStringUsingEncoding:NSUTF8StringEncoding];
    char *passwordChars = strdup(constPasswordChars);
    p12 = PKCS12_create(passwordChars, "SMPCertificate", privateKey, certificate, NULL, 0,0,0,0,0);
    
    // Cleanup algorithms
    EVP_cleanup();
    
    if (!p12) {
        completionHandler(nil, [self errorWithCode:CertificateConverterErrorCodeP12CreateFailure]);
        return;
    }
    
    // Convert P12 to NSData
    
    BIO *p12Buffer = BIO_new(BIO_s_mem());
    i2d_PKCS12_bio(p12Buffer, p12);
    PKCS12_free(p12);
    
    BUF_MEM* p12MEM;
    BIO_get_mem_ptr(p12Buffer, &p12MEM);
    
    NSData* p12Data = [[NSData alloc] initWithBytes:p12MEM->data length:p12MEM->length];
    BIO_free(p12Buffer);
    
    completionHandler(p12Data, nil);
}

+ (void)derCertificateDataFromPemCertificate:(nonnull NSString *)pemCertificate
                           completionHandler:(nonnull void (^)(NSData * _Nullable, NSError * _Nullable error))completionHandler {
    
    // Read certificate
    
    BIO *certificateBuffer = BIO_new(BIO_s_mem());
    const char *certificateChars = [pemCertificate cStringUsingEncoding:NSUTF8StringEncoding];
    BIO_puts(certificateBuffer, certificateChars);
    
    X509 *certificate;
    certificate = PEM_read_bio_X509(certificateBuffer, NULL, 0, NULL);
    BIO_free(certificateBuffer);
    
    if (certificate == NULL) {
        completionHandler(nil, [self errorWithCode:CertificateConverterErrorCodeCertificateFormatIncorrect]);
        return;
    }
    
    // Convert PEM to DER
    
    BIO *derCertificateBuffer = BIO_new(BIO_s_mem());
    i2d_X509_bio(derCertificateBuffer, certificate);
    
    // Convert DER to NSData
    
    BUF_MEM* derCertificateMEM;
    BIO_get_mem_ptr(derCertificateBuffer, &derCertificateMEM);
    
    NSData* derCertificateData = [[NSData alloc] initWithBytes:derCertificateMEM->data length:derCertificateMEM->length];
    BIO_free(derCertificateBuffer);
    
    completionHandler(derCertificateData, nil);
}

+ (nonnull NSError *)errorWithCode:(NSInteger)code {
    return [NSError errorWithDomain:NSStringFromClass(self.class) code:code userInfo:nil];
}

@end
