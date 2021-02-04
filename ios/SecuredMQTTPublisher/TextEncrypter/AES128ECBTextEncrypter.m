//
//  Project Secured MQTT Publisher
//  Copyright 2021 Tracmo, Inc. ("Tracmo").
//  Open Source Project Licensed under MIT License.
//  Please refer to https://github.com/tracmo/open-tls-iot-client
//  for the license and the contributors information.
//

#import "AES128ECBTextEncrypter.h"
#import <openssl/evp.h>

@implementation AES128ECBTextEncrypter

+ (void)encryptedTimestampInHexWithKeyInHex:(nonnull NSString *)keyInHex
                          completionHandler:(nonnull void (^)(NSString * _Nullable, NSError * _Nullable error))completionHandler {
    NSInteger timestampToSeconds = (NSInteger)NSDate.now.timeIntervalSince1970;
    NSString *timestampInHex = [NSString stringWithFormat:@"%08lX", timestampToSeconds];
    
    NSMutableArray *timestrampBytes = NSMutableArray.array;
    for (int i = 0; i<timestampInHex.length; i += 2) {
        NSString *byte = [timestampInHex substringWithRange:NSMakeRange(i, 2)];
        [timestrampBytes addObject:byte];
    }
    // byte 4~7
    NSArray *littleEndianTimestampBytes = [[timestrampBytes reverseObjectEnumerator] allObjects];
    
    // byte 0~3 & byte 8~14 -> total 11 bytes
    NSMutableArray *randomBytes = NSMutableArray.array;
    for (int i = 0; i<11; i++) {
        unsigned int randomByteValue = arc4random() % 256;
        NSString *randomByte = [NSString stringWithFormat:@"%02X", randomByteValue];
        [randomBytes addObject:randomByte];
    }
    
    // byte 0~3: random
    // byte 4~7: little endian timestamp to seconds
    // byte 8~14: random
    NSMutableArray *byte0To14 = randomBytes;
    [byte0To14 insertObjects:littleEndianTimestampBytes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(4, 4)]];
    
    // for byte 15 calculating
    __block unsigned int sumOfByte0To14Value = 0;
    
    NSMutableString *textToEncryptInHex = NSMutableString.string;
    [byte0To14 enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger index, BOOL * _Nonnull stop) {
        NSString *byte = (NSString *)obj;
        
        [textToEncryptInHex appendString:byte];
        
        unsigned int byteValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:byte];
        [scanner scanHexInt:&byteValue];
        
        sumOfByte0To14Value += byteValue;
    }];
    
    // byte 15: (sum of byte 0~14) & 0xFF
    NSString *byte15 = [NSString stringWithFormat:@"%02X", sumOfByte0To14Value & 0xFF];
    [textToEncryptInHex appendString:byte15];
    
    [self encryptedTextInHexFromTextInHex:textToEncryptInHex
                             withKeyInHex:keyInHex
                        completionHandler:completionHandler];
}

+ (void)encryptedTextInHexFromTextInHex:(nonnull NSString *)textInHex
                           withKeyInHex:(nonnull NSString *)keyInHex
                      completionHandler:(nonnull void (^)(NSString * _Nullable, NSError * _Nullable error))completionHandler {
    NSString *textInPlainString = [self plainFromHex:textInHex];
    if (textInPlainString == nil) {
        completionHandler(nil, [self errorWithCode:TextEncrypterErrorCodeHexFormatIncorrect]);
        return;
    }
    
    if (keyInHex.length != 32) {
        completionHandler(nil, [self errorWithCode:TextEncrypterErrorCodeKeyFormatIncorrect]);
        return;
    }
    
    NSString *keyInPlainString = [self plainFromHex:keyInHex];
    if (keyInPlainString == nil) {
        completionHandler(nil, [self errorWithCode:TextEncrypterErrorCodeKeyFormatIncorrect]);
        return;
    }
    
    [self encryptedTextInHexFromTextInPlain:textInPlainString
                             withKeyInPlain:keyInPlainString
                          completionHandler:completionHandler];
}

+ (nullable NSString*)plainFromHex:(nonnull NSString *)hex {
    if ((hex.length % 2) != 0) {
        return nil;
    }
    
    NSMutableString * plain = NSMutableString.string;
    for (int i=0; i<hex.length; i+=2) {
        NSString * byte = [hex substringWithRange:NSMakeRange(i, 2)];
        int byteValue = 0;
        sscanf([byte cStringUsingEncoding:NSASCIIStringEncoding], "%X", &byteValue);
        [plain appendFormat:@"%c", (char)byteValue];
    }
    
    return [NSString stringWithString:plain];
}


+ (void)encryptedTextInHexFromTextInPlain:(nonnull NSString *)textInPlainString
                           withKeyInPlain:(nonnull NSString *)keyInPlainString
                        completionHandler:(nonnull void (^)(NSString * _Nullable, NSError * _Nullable error))completionHandler {
    const unsigned char *text = (const unsigned char *)[textInPlainString cStringUsingEncoding:NSISOLatin1StringEncoding];
    const unsigned char *key = (const unsigned char *)[keyInPlainString cStringUsingEncoding:NSISOLatin1StringEncoding];
    
    unsigned char encryptedTextBuffer[1024];
    int updateLength, finalLength;
    
    EVP_CIPHER_CTX *context;
    
    context = EVP_CIPHER_CTX_new();
    if (!EVP_EncryptInit_ex(context, EVP_aes_128_ecb(), NULL, key, NULL)) {
        EVP_CIPHER_CTX_free(context);
        completionHandler(nil, [self errorWithCode:TextEncrypterErrorCodeInitFailure]);
        return;
    }
    
    if (!EVP_EncryptUpdate(context, encryptedTextBuffer, &updateLength, text, (int)strlen((const char *)text))) {
        EVP_CIPHER_CTX_free(context);
        completionHandler(nil, [self errorWithCode:TextEncrypterErrorCodeUpdateFailure]);
        return;
    }
    
    if (!EVP_EncryptFinal_ex(context, encryptedTextBuffer + updateLength, &finalLength)) {
        EVP_CIPHER_CTX_free(context);
        completionHandler(nil, [self errorWithCode:TextEncrypterErrorCodeFinalFailure]);
        return;
    }
    
    EVP_CIPHER_CTX_free(context);
    
    NSMutableString * encryptedTextInHex = NSMutableString.string;
    for (int i=0; i<(updateLength+finalLength); i++) {
        [encryptedTextInHex appendString:[NSString stringWithFormat:@"%02X", encryptedTextBuffer[i]]];
    }
    
    completionHandler([NSString stringWithString:encryptedTextInHex], nil);
}

+ (nonnull NSError *)errorWithCode:(NSInteger)code {
    return [NSError errorWithDomain:NSStringFromClass(self.class) code:code userInfo:nil];
}

@end
