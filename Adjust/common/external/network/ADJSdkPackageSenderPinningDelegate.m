//
//  ADJSdkPackageSenderPinningDelegate.m
//  Adjust
//
// adapted from:
//  https://github.com/datatheorem/TrustKit/blob/master/TrustKit/Pinning/TSKSPKIHashCache.m
//  https://www.bugsee.com/blog/ssl-certificate-pinning-in-mobile-applications/
//
//  Created by Pedro Silva on 26.07.22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJSdkPackageSenderPinningDelegate.h"

#import <CommonCrypto/CommonDigest.h>

#import "ADJUtilF.h"

#pragma mark Fields
#pragma mark - Private constants
static const unsigned char kRsa2048Asn1Header[] =
{
    0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
    0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
};

static const unsigned char kRsa4096Asn1Header[] =
{
    0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
    0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
};

static const unsigned char kEcDsaSecp256r1Asn1Header[] =
{
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
    0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
    0x42, 0x00
};

static const unsigned char kEcDsaSecp384r1Asn1Header[] =
{
    0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
    0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
};

@interface ADJSdkPackageSenderPinningDelegate ()
#pragma mark - Injected dependencies
@property (nonnull, readonly, strong, nonatomic) ADJNonEmptyString *publicKeyHash;
@end

@implementation ADJSdkPackageSenderPinningDelegate
#pragma mark Instantiation
- (nonnull instancetype) initWithLoggerFactory:(nonnull id<ADJLoggerFactory>)loggerFactory
                                 publicKeyHash:(nonnull ADJNonEmptyString *)publicKeyHash
{
    self = [super initWithLoggerFactory:loggerFactory
                             loggerName:@"SdkPackageSenderPinningDelegate"];
    _publicKeyHash = publicKeyHash;

    return self;
}

#pragma mark - NSURLSessionDelegate
- (void)URLSession:(nonnull NSURLSession *)session
didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^_Nonnull)
                    (NSURLSessionAuthChallengeDisposition disposition,
                     NSURLCredential * _Nullable credential))completionHandler
{
    if (! [challenge.protectionSpace.authenticationMethod
           isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        // TODO: should perform default handling or cancel challange?
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        //completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
        return;
    }

    // Get remote certificate
    SecTrustRef _Nonnull serverTrust = challenge.protectionSpace.serverTrust;
    //CFRetain(serverTrust);

    BOOL useCredential = [self useCredentialWithServerTrust:serverTrust];

    //CFRelease(serverTrust);

    if (useCredential) {
        NSURLCredential *_Nonnull serverCredential =
        [NSURLCredential credentialForTrust:serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, serverCredential);
    } else {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}

#pragma mark Internal Methods
- (BOOL)useCredentialWithServerTrust:(nonnull SecTrustRef)serverTrust {
    if (! [self canEvaluateWithTrust:serverTrust]) {
        return NO;
    }

    [self.logger debugDev:@"Server trust validated certificates"
                      key:@"certificates count"
              stringValue:[ADJUtilF intFormat:(int)SecTrustGetCertificateCount(serverTrust)]];

    SecCertificateRef _Nullable serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0);

    if (! serverCertificate) {
        [self.logger debugDev:@"Cannot retrieve first server certificate"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    // TODO: see how it is done before iOS 10.3
    SecKeyRef _Nullable serverPublicKey = SecCertificateCopyPublicKey(serverCertificate);

    if (! serverPublicKey) {
        [self.logger debugDev:@"Cannot retrieve public key from first server certificate"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    BOOL useCredential = [self useCredentialWithServerPublicKey:serverPublicKey];

    CFRelease(serverPublicKey);

    return useCredential;
}

- (BOOL)useCredentialWithServerPublicKey:(SecKeyRef _Nonnull)serverPublicKey {
    CFErrorRef errorRef;

    // TODO: maybe use __bridge_transfer / CFBridgingRelease instead of CFRelease
    // TODO: see how it is done before iOS 10.0
    CFDataRef _Nullable serverPublicKeyData =
        SecKeyCopyExternalRepresentation(serverPublicKey, &errorRef);

    if (serverPublicKeyData) {
        BOOL useCredential =
            [self useCredentialWithServerPublicKeyData:(__bridge NSData *)serverPublicKeyData
                                       serverPublicKey:serverPublicKey];

        CFRelease(serverPublicKeyData);

        return useCredential;
    }

    NSError *_Nonnull error = nil;

    if (errorRef) {
        // according to https://stackoverflow.com/a/40885964
        //  __bridge_transfer should mean that ARC now "owns" the reference/object and that
        //  we can retain it and not worry about freeing CFErrorRef errorRef
        error = (__bridge_transfer NSError *)errorRef;
    }

    [self.logger debugDev:@"Could not convert public key into data"
               resultFail:[[ADJResultFail alloc]
                           initWithMessage:@"from SecKeyCopyExternalRepresentation"
                           params:nil
                           error:error
                           exception:nil]
                issueType:ADJIssueNetworkRequest];
    return NO;
}

- (BOOL)useCredentialWithServerPublicKeyData:(nonnull NSData *)serverPublicKeyNSData
                             serverPublicKey:(SecKeyRef _Nonnull)serverPublicKey {
    // TODO: maybe use __bridge_transfer / CFBridgingRelease instead of CFRelease
    // Obtain the SPKI header based on the key's algorithm
    CFDictionaryRef _Nullable publicKeyAttributes = SecKeyCopyAttributes(serverPublicKey);

    if (! publicKeyAttributes) {
        [self.logger debugDev:@"Cannot retrieve keychain attributes of the server public key"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    BOOL useCredential = [self useCredentialWithPublicKeyAttributes:publicKeyAttributes
                                                serverPublicKeyData:serverPublicKeyNSData];

    CFRelease(publicKeyAttributes);

    return useCredential;
}

- (BOOL)useCredentialWithPublicKeyAttributes:(CFDictionaryRef _Nonnull)publicKeyAttributes
                         serverPublicKeyData:(nonnull NSData *)serverPublicKeyNSData {
    CFTypeRef _Nullable publicKeyTypeRef =
    CFDictionaryGetValue(publicKeyAttributes, kSecAttrKeyType);

    if (publicKeyTypeRef == nil) {
        [self.logger debugDev:@"Cannot retrieve public key type from keychain attributes"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    if (CFGetTypeID(publicKeyTypeRef) != CFStringGetTypeID()) {
        [self.logger debugDev:
         @"Retrieved public key type from keychain attributes is not of string type"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    NSString *_Nonnull publicKeyType = (__bridge NSString *)((CFStringRef)publicKeyTypeRef);

    CFTypeRef _Nullable publicKeySizeRef =
    CFDictionaryGetValue(publicKeyAttributes, kSecAttrKeySizeInBits);

    if (publicKeySizeRef == nil) {
        [self.logger debugDev:@"Cannot retrieve public key size from keychain attributes"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    if (CFGetTypeID(publicKeySizeRef) != CFNumberGetTypeID()) {
        [self.logger debugDev:
         @"Retrieved public key size from keychain attributes is not of number type"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    NSNumber *_Nonnull publicKeySize = (__bridge NSNumber *)((CFNumberRef)publicKeySizeRef);

    char *_Nullable asn1HeaderBytes = NULL;
    unsigned int asn1HeaderSize = 0;

    if ([publicKeyType isEqualToString:(NSString *)kSecAttrKeyTypeRSA]
        && publicKeySize.integerValue == 2048)
    {
        asn1HeaderBytes = (char *)kRsa2048Asn1Header;
        asn1HeaderSize = sizeof(kRsa2048Asn1Header);
    }
    else if ([publicKeyType isEqualToString:(NSString *)kSecAttrKeyTypeRSA]
             && publicKeySize.integerValue == 4096)
    {
        asn1HeaderBytes = (char *)kRsa4096Asn1Header;
        asn1HeaderSize = sizeof(kRsa4096Asn1Header);
    }
    else if ([publicKeyType isEqualToString:(NSString *)kSecAttrKeyTypeECSECPrimeRandom]
             && publicKeySize.integerValue == 256)
    {
        asn1HeaderBytes = (char *)kEcDsaSecp256r1Asn1Header;
        asn1HeaderSize = sizeof(kEcDsaSecp256r1Asn1Header);
    }
    else if ([publicKeyType isEqualToString:(NSString *)kSecAttrKeyTypeECSECPrimeRandom]
             && publicKeySize.integerValue == 384)
    {
        asn1HeaderBytes = (char *)kEcDsaSecp384r1Asn1Header;
        asn1HeaderSize = sizeof(kEcDsaSecp384r1Asn1Header);
    }

    if (asn1HeaderSize == 0 || ! asn1HeaderBytes) {
        [self.logger debugDev:@"Public key algorithm or length is not supported"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    NSString *_Nonnull serverPublicKeyHash =
    [self sha256WithServerPublicKeyData:serverPublicKeyNSData
                        asn1HeaderBytes:asn1HeaderBytes
                         asn1HeaderSize:asn1HeaderSize];

    if (! [serverPublicKeyHash isEqualToString:self.publicKeyHash.stringValue]) {
        [self.logger debugDev:@"Server certificate public key hash does not match expected"
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }

    return YES;
}

- (nonnull NSString *)sha256WithServerPublicKeyData:(nonnull NSData *)serverPublicKeyNSData
                                    asn1HeaderBytes:(char *_Nonnull)asn1HeaderBytes
                                     asn1HeaderSize:(unsigned int)asn1HeaderSize {
    // Generate a hash of the subject public key info
    NSMutableData *_Nonnull subjectPublicKeyInfoHash =
    [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_CTX shaCtx;
    CC_SHA256_Init(&shaCtx);

    // Add the missing ASN1 header for public keys to re-create the subject public key info
    CC_SHA256_Update(&shaCtx, asn1HeaderBytes, asn1HeaderSize);

    // Add the public key
    CC_SHA256_Update(&shaCtx,
                     [serverPublicKeyNSData bytes],
                     (unsigned int)[serverPublicKeyNSData length]);
    CC_SHA256_Final((unsigned char *)[subjectPublicKeyInfoHash bytes], &shaCtx);

    return [subjectPublicKeyInfoHash base64EncodedStringWithOptions:
            NSDataBase64Encoding64CharacterLineLength];
}

- (BOOL)canEvaluateWithTrust:(nonnull SecTrustRef)trust {
    if (@available(iOS 12.0, macOS 10.14, tvOS 12.0, watchOS 5.0, macCatalyst 13.0, *)) {
        CFErrorRef errorRef;
        if (SecTrustEvaluateWithError(trust, &errorRef)) {
            return YES;
        }

        NSError *_Nonnull error = nil;
        if (errorRef) {
            error = (__bridge_transfer NSError *)errorRef;
        }

        [self.logger debugDev:@"Could not trust"
                   resultFail:[[ADJResultFail alloc]
                               initWithMessage:@"from SecTrustEvaluateWithError"
                               params:nil
                               error:error
                               exception:nil]
                    issueType:ADJIssueNetworkRequest];

        return NO;
    } else {
        SecTrustResultType resultType = kSecTrustResultInvalid;
        OSStatus evaluateReturn = SecTrustEvaluate(trust, &resultType);
        if (evaluateReturn == errSecSuccess) {
            return YES;
        }

        [self.logger debugDev:@"Cannot evaluate trust from SecTrustEvaluate"
                         key1:@"OSStatus"
                 stringValue1:[ADJUtilF intFormat:(int)evaluateReturn]
                         key2:@"SecTrustResultType"
                 stringValue2:[ADJUtilF uIntFormat:(unsigned int)resultType]
                    issueType:ADJIssueNetworkRequest];
        return NO;
    }
}

@end
