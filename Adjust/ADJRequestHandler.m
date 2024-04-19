//
//  ADJRequestHandler.m
//  Adjust
//
//  Created by Christian Wellenbrock on 2013-07-04.
//  Copyright (c) 2013 adjust GmbH. All rights reserved.
//

#import "ADJUtil.h"
#import "ADJLogger.h"
#import "ADJActivityKind.h"
#import "ADJAdjustFactory.h"
#import "ADJPackageBuilder.h"
#import "ADJActivityPackage.h"
#import "NSString+ADJAdditions.h"
#include <stdlib.h>

static NSString * const ADJMethodGET = @"MethodGET";
static NSString * const ADJMethodPOST = @"MethodPOST";

@interface ADJRequestHandler()

@property (nonatomic, strong) ADJUrlStrategy *urlStrategy;
@property (nonatomic, assign) double requestTimeout;
@property (nonatomic, weak) id<ADJResponseCallback> responseCallback;

@property (nonatomic, weak) id<ADJLogger> logger;

@property (nonatomic, copy) NSURLSessionConfiguration *defaultSessionConfiguration;

@property (nonatomic, strong) NSHashTable<NSString *> *exceptionKeys;

@end

@implementation ADJRequestHandler

#pragma mark - Public methods

- (id)initWithResponseCallback:(id<ADJResponseCallback>)responseCallback
                   urlStrategy:(ADJUrlStrategy *)urlStrategy
                requestTimeout:(double)requestTimeout
{
    self = [super init];
    
    if (self == nil) {
        return nil;
    }
    self.urlStrategy = urlStrategy;
    self.requestTimeout = requestTimeout;
    self.responseCallback = responseCallback;

    self.logger = ADJAdjustFactory.logger;
    self.defaultSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];

    self.exceptionKeys = [NSHashTable hashTableWithOptions:NSHashTableStrongMemory];
    [self.exceptionKeys addObject:@"secret_id"];
    [self.exceptionKeys addObject:@"signature"];
    [self.exceptionKeys addObject:@"headers_id"];
    [self.exceptionKeys addObject:@"native_version"];
    [self.exceptionKeys addObject:@"algorithm"];
    [self.exceptionKeys addObject:@"adj_signing_id"];

    return self;
}

- (void)sendPackageByPOST:(ADJActivityPackage *)activityPackage
        sendingParameters:(NSDictionary *)sendingParameters
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc]
                                       initWithDictionary:activityPackage.parameters
                                       copyItems:YES];
    NSString *path = [activityPackage.path copy];
    NSString *clientSdk = [activityPackage.clientSdk copy];
    ADJActivityKind activityKind = activityPackage.activityKind;

    ADJResponseData *responseData =
        [ADJResponseData buildResponseData:activityPackage];

    NSString *urlHostString = [self urlWithParams:parameters
                                    sendingParams:sendingParameters
                                     responseData:responseData];

    NSMutableDictionary *parametersCopy = [[NSMutableDictionary alloc]
                                          initWithDictionary:parameters];
    [parametersCopy addEntriesFromDictionary:responseData.sendingParameters];

    [self signWithSigV2PluginWithParams:parametersCopy
                           activityKind:activityKind
                              clientSdk:clientSdk];
    NSString * authorizationHeader = [self buildAuthorizationHeader:parametersCopy
                                                       activityKind:activityKind];

    NSMutableURLRequest *urlRequest = [self requestForPostPackage:path
                                                        clientSdk:clientSdk
                                                       parameters:parameters
                                                    urlHostString:urlHostString
                                                sendingParameters:responseData.sendingParameters];

    [self sendRequest:urlRequest
  authorizationHeader:authorizationHeader
         responseData:responseData
       methodTypeInfo:ADJMethodPOST];
}
- (void)sendPackageByGET:(ADJActivityPackage *)activityPackage
       sendingParameters:(NSDictionary *)sendingParameters
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc]
                                       initWithDictionary:activityPackage.parameters
                                       copyItems:YES];
    NSString *path = [activityPackage.path copy];
    NSString *clientSdk = [activityPackage.clientSdk copy];
    ADJActivityKind activityKind = activityPackage.activityKind;

    ADJResponseData *responseData =
        [ADJResponseData buildResponseData:activityPackage];

    NSString *urlHostString = [self urlWithParams:parameters
                                    sendingParams:sendingParameters
                                     responseData:responseData];

    NSMutableDictionary *parametersCopy = [[NSMutableDictionary alloc]
                                          initWithDictionary:parameters];
    [parametersCopy addEntriesFromDictionary:responseData.sendingParameters];

    [self signWithSigV2PluginWithParams:parametersCopy
                           activityKind:activityKind
                              clientSdk:clientSdk];
    NSString * authorizationHeader = [self buildAuthorizationHeader:parametersCopy
                                                       activityKind:activityKind];

    NSMutableURLRequest *urlRequest = [self requestForGetPackage:path
                                                       clientSdk:clientSdk
                                                      parameters:parameters
                                                   urlHostString:urlHostString
                                               sendingParameters:responseData.sendingParameters];

    [self sendRequest:urlRequest
  authorizationHeader:authorizationHeader
         responseData:responseData
       methodTypeInfo:ADJMethodGET];
}

#pragma mark Internal methods
- (nonnull NSString *)urlWithParams:(nonnull NSMutableDictionary *)params
                      sendingParams:(NSDictionary *)sendingParams
                       responseData:(nonnull ADJResponseData *)responseData {
    NSMutableDictionary * sendingParamsCopy =  [NSMutableDictionary dictionaryWithDictionary:sendingParams];

    NSString *attStatusString = [responseData.sdkPackage.parameters objectForKey:@"att_status"];
    BOOL wasConsentWhenCreated = [ADJUtil shouldUseConsentParamsForActivityKind:responseData.activityKind
                                                                   andAttStatus:attStatusString];
    BOOL isConsentWhenSending = [ADJUtil shouldUseConsentParamsForActivityKind:responseData.activityKind];
    BOOL doesConsentDataExist = wasConsentWhenCreated && isConsentWhenSending;

    if (!doesConsentDataExist) {
        [ADJPackageBuilder removeConsentDataFromParameters:params];
    }

    // if att_status was part of the payload at all
    // make sure to have up to date value before sending
    if (attStatusString != nil) {
        [ADJPackageBuilder updateAttStatusInParameters:params];
    }

    NSString *urlHostString =  [self.urlStrategy urlForActivityKind:responseData.activityKind
                                                     isConsentGiven:isConsentWhenSending
                                                  withSendingParams:sendingParamsCopy];

    responseData.sendingParameters = [[NSDictionary alloc]
                                      initWithDictionary:sendingParamsCopy
                                      copyItems:YES];

    return urlHostString;
}

- (void)sendRequest:(NSMutableURLRequest *)request
authorizationHeader:(NSString *)authorizationHeader
       responseData:(ADJResponseData *)responseData
     methodTypeInfo:(NSString *)methodTypeInfo
{
    if (authorizationHeader != nil) {
        [ADJAdjustFactory.logger debug:@"Authorization header content: %@", authorizationHeader];
        [request setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
    }

    Class NSURLSessionClass = NSClassFromString(@"NSURLSession");
    if (NSURLSessionClass != nil) {
        [self sendNSURLSessionRequest:request
                      responseData:responseData
                       methodTypeInfo:methodTypeInfo];
    } else {
        [self sendNSURLConnectionRequest:request
                         responseData:responseData
                          methodTypeInfo:methodTypeInfo];
    }
}

- (void)sendNSURLSessionRequest:(NSMutableURLRequest *)request
                   responseData:(ADJResponseData *)responseData
                 methodTypeInfo:(NSString *)methodTypeInfo

{
    NSURLSession *session =
        [NSURLSession sessionWithConfiguration:self.defaultSessionConfiguration];

    NSURLSessionDataTask *task =
        [session dataTaskWithRequest:request
                   completionHandler:
         ^(NSData *data, NSURLResponse *response, NSError *error)
         {
            [self handleResponseWithData:data
                                response:(NSHTTPURLResponse *)response
                                   error:error
                            responseData:responseData];
            if (responseData.jsonResponse != nil) {
                [self.logger debug:@"Request succeeded with current URL strategy"];
                [self.urlStrategy resetAfterSuccess];
                [self.responseCallback responseCallback:responseData];
            } else if ([self.urlStrategy shouldRetryAfterFailure:responseData.activityKind]) {
                [self.logger debug:@"Request failed with current URL strategy, but it will be retried with new one"];
                [self retryWithResponseData:responseData
                             methodTypeInfo:methodTypeInfo];
            } else {
                [self.logger debug:@"Request failed with current URL strategy and it will not be retried"];
                //  Stop retrying with different type and return to caller
                [self.responseCallback responseCallback:responseData];
            }
        }];

    [task resume];
    [session finishTasksAndInvalidate];
}

/* Manual testing code to fail certain percentage of requests
 // needs .h to comply with NSURLSessionDelegate
- (void)
    URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:
        (void (^)
            (NSURLSessionAuthChallengeDisposition disposition,
             NSURLCredential * _Nullable credential))completionHandler
{
    uint32_t randomNumber = arc4random_uniform(2);
    NSLog(@"URLSession:didReceiveChallenge:completionHandler: random number %d", randomNumber);
    if (randomNumber != 0) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    //if (self.urlStrategy.usingIpAddress) {
    //    completionHandler(NSURLSessionAuthChallengeUseCredential,
    //                  [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    //} else {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    //}
}

 - (void)connection:(NSURLConnection *)connection
 willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
 {
     if (challenge.previousFailureCount > 0) {
         [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
     } else {
         NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
         [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
     }
 }
 */

- (void)sendNSURLConnectionRequest:(NSMutableURLRequest *)request
                responseData:(ADJResponseData *)responseData
                    methodTypeInfo:(NSString *)methodTypeInfo
{
    dispatch_async
        (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
         ^{
            NSError *error = nil;
            NSURLResponse *response = nil;
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSData *data = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&response
                                                             error:&error];
            #pragma clang diagnostic pop

            [self handleResponseWithData:data
                                response:(NSHTTPURLResponse *)response
                                   error:error
                            responseData:responseData];

            if (responseData.jsonResponse != nil) {
                [self.logger debug:@"succeeded with current url strategy"];
                [self.urlStrategy resetAfterSuccess];
                [self.responseCallback responseCallback:responseData];
            } else if ([self.urlStrategy shouldRetryAfterFailure:responseData.activityKind]) {
                [self.logger debug:@"failed with current url strategy, but it will retry with new"];
                [self retryWithResponseData:responseData
                             methodTypeInfo:methodTypeInfo];
            } else {
                [self.logger debug:@"failed with current url strategy and it will not retry"];
                //  Stop retrying with different type and return to caller
                [self.responseCallback responseCallback:responseData];
            }
        });
}

- (void)retryWithResponseData:(ADJResponseData *)responseData
               methodTypeInfo:(NSString *)methodTypeInfo
{
    ADJActivityPackage *activityPackage = responseData.sdkPackage;
    NSDictionary *sendingParameters = responseData.sendingParameters;

    if (methodTypeInfo == ADJMethodGET) {
        [self sendPackageByGET:activityPackage
             sendingParameters:sendingParameters];
    } else {
        [self sendPackageByPOST:activityPackage
              sendingParameters:sendingParameters];
    }
}

- (void)handleResponseWithData:(NSData *)data
                      response:(NSHTTPURLResponse *)urlResponse
                         error:(NSError *)responseError
                       responseData:(ADJResponseData *)responseData
{
    // Connection error
    if (responseError != nil) {
        responseData.message = responseError.description;
        return;
    }
    if ([ADJUtil isNull:data]) {
        responseData.message = @"nil response data";
        return;
    }

    NSString *responseString = [[[NSString alloc]
                                 initWithData:data encoding:NSUTF8StringEncoding] adjTrim];
    NSInteger statusCode = urlResponse.statusCode;
    [self.logger verbose:@"Response: %@", responseString];

    if (statusCode == 429) {
        responseData.message = @"Too frequent requests to the endpoint (429)";
        return;
    }

    [self saveJsonResponse:data responseData:responseData];
    if (responseData.jsonResponse == nil) {
        return;
    }

    NSString *messageResponse = [responseData.jsonResponse objectForKey:@"message"];
    responseData.message = messageResponse;
    responseData.timeStamp = [responseData.jsonResponse objectForKey:@"timestamp"];
    responseData.adid = [responseData.jsonResponse objectForKey:@"adid"];
    responseData.retryInMilli = [responseData.jsonResponse objectForKey:@"retry_in"];

    NSString *trackingState = [responseData.jsonResponse objectForKey:@"tracking_state"];
    if (trackingState != nil) {
        if ([trackingState isEqualToString:@"opted_out"]) {
            responseData.trackingState = ADJTrackingStateOptedOut;
        }
    }

    if (statusCode == 200) {
        responseData.success = YES;
    }
}
#pragma mark - URL Request
- (NSMutableURLRequest *)
    requestForPostPackage:(NSString *)path
    clientSdk:(NSString *)clientSdk
    parameters:(NSDictionary *)parameters
    urlHostString:(NSString *)urlHostString
    sendingParameters:
        (NSDictionary<NSString *, NSString *> *)sendingParameters
{
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@",
                           urlHostString, self.urlStrategy.extraPath, path];

    [self.logger verbose:@"Sending request to endpoint: %@", urlString];

    NSURL *url = [NSURL URLWithString:urlString];
    //NSURL *url = [baseUrl URLByAppendingPathComponent:path];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = self.requestTimeout;
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:clientSdk forHTTPHeaderField:@"Client-Sdk"];

    NSUInteger sendingParametersCount = sendingParameters? sendingParameters.count : 0;
    NSMutableArray<NSString *> *kvParameters =
        [NSMutableArray arrayWithCapacity:
            parameters.count + sendingParametersCount];

    [self injectParameters:parameters
        kvArray:kvParameters];
    [self injectParameters:sendingParameters
        kvArray:kvParameters];

    NSString *bodyString = [kvParameters componentsJoinedByString:@"&"];
    NSData *body = [NSData dataWithBytes:bodyString.UTF8String length:bodyString.length];
    [request setHTTPBody:body];
    return request;
}

- (NSMutableURLRequest *)
    requestForGetPackage:(NSString *)path
    clientSdk:(NSString *)clientSdk
    parameters:(NSDictionary *)parameters
    urlHostString:(NSString *)urlHostString
    sendingParameters:(NSDictionary *)sendingParameters
{
    NSUInteger sendingParametersCount = sendingParameters? sendingParameters.count : 0;
    NSMutableArray<NSString *> *kvParameters =
        [NSMutableArray arrayWithCapacity:
            parameters.count + sendingParametersCount];

    [self injectParameters:parameters
        kvArray:kvParameters];
    [self injectParameters:sendingParameters
        kvArray:kvParameters];

    NSString *queryStringParameters = [kvParameters componentsJoinedByString:@"&"];

    NSString *urlString =
        [NSString stringWithFormat:@"%@%@%@?%@",
         urlHostString, self.urlStrategy.extraPath, path, queryStringParameters];
    
    [self.logger verbose:@"Sending request to endpoint: %@",
     [NSString stringWithFormat:@"%@%@%@", urlHostString, self.urlStrategy.extraPath, path]];

    // [self.logger verbose:@"requestForGetPackage with urlString: %@", urlString];

    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = self.requestTimeout;
    request.HTTPMethod = @"GET";
    [request setValue:clientSdk forHTTPHeaderField:@"Client-Sdk"];
    return request;
}

- (void)
    injectParameters:(NSDictionary<NSString *, NSString *> *)parameters
    kvArray:(NSMutableArray<NSString *> *)kvArray
{
    if (parameters == nil || parameters.count == 0) {
        return;
    }

    for (NSString *key in parameters) {
        if ([self.exceptionKeys containsObject:key]) {
            continue;
        }
        NSString *value = [parameters objectForKey:key];
        NSString *escapedValue = [value  adjUrlEncode];
        NSString *escapedKey = [key  adjUrlEncode];
        NSString *pair = [NSString stringWithFormat:@"%@=%@", escapedKey, escapedValue];
        [kvArray addObject:pair];
    }
}

#pragma mark - Authorization Header
- (NSString *)buildAuthorizationHeader:(NSDictionary *)parameters
                          activityKind:(ADJActivityKind)activityKind {
    NSString *adjSigningId = [parameters objectForKey:@"adj_signing_id"];
    NSString *signature = [parameters objectForKey:@"signature"];
    NSString *headersId = [parameters objectForKey:@"headers_id"];
    NSString *nativeVersion = [parameters objectForKey:@"native_version"];
    NSString *algorithm = [parameters objectForKey:@"algorithm"];
    NSString *authorizationHeaderWithAdjSigningId = [self buildAuthorizationHeaderV2:signature
                                                                        adjSigningId:adjSigningId
                                                                           headersId:headersId
                                                                       nativeVersion:nativeVersion
                                                                           algorithm:algorithm];
    if (authorizationHeaderWithAdjSigningId != nil) {
        return authorizationHeaderWithAdjSigningId;
    }

    NSString *secretId = [parameters objectForKey:@"secret_id"];
    return [self buildAuthorizationHeaderV2:signature
                                   secretId:secretId
                                  headersId:headersId
                              nativeVersion:nativeVersion
                                  algorithm:algorithm];
}

- (NSString *)buildAuthorizationHeaderV2:(NSString *)signature
                            adjSigningId:(NSString *)adjSigningId
                               headersId:(NSString *)headersId
                           nativeVersion:(NSString *)nativeVersion
                               algorithm:(NSString *)algorithm
{
    if (adjSigningId == nil || signature == nil || headersId == nil) {
        return nil;
    }

    NSString * signatureHeader = [NSString stringWithFormat:@"signature=\"%@\"", signature];
    NSString * adjSigningIdHeader = [NSString stringWithFormat:@"adj_signing_id=\"%@\"", adjSigningId];
    NSString * idHeader        = [NSString stringWithFormat:@"headers_id=\"%@\"", headersId];
    NSString * algorithmHeader = [NSString stringWithFormat:@"algorithm=\"%@\"", algorithm != nil ? algorithm : @"adj1"];

    NSString * authorizationHeader = [NSString stringWithFormat:@"Signature %@,%@,%@,%@",
            signatureHeader, adjSigningIdHeader, algorithmHeader, idHeader];

    if (nativeVersion == nil) {
        return [authorizationHeader stringByAppendingFormat:@",native_version=\"\""];
    }
    return [authorizationHeader stringByAppendingFormat:@",native_version=\"%@\"", nativeVersion];
}


- (NSString *)buildAuthorizationHeaderV2:(NSString *)signature
                                secretId:(NSString *)secretId
                                headersId:(NSString *)headersId
                           nativeVersion:(NSString *)nativeVersion
                               algorithm:(NSString *)algorithm
{
    if (secretId == nil || signature == nil || headersId == nil) {
        return nil;
    }

    NSString * signatureHeader = [NSString stringWithFormat:@"signature=\"%@\"", signature];
    NSString * secretIdHeader  = [NSString stringWithFormat:@"secret_id=\"%@\"", secretId];
    NSString * idHeader        = [NSString stringWithFormat:@"headers_id=\"%@\"", headersId];
    NSString * algorithmHeader = [NSString stringWithFormat:@"algorithm=\"%@\"", algorithm != nil ? algorithm : @"adj1"];

    NSString * authorizationHeader = [NSString stringWithFormat:@"Signature %@,%@,%@,%@",
            signatureHeader, secretIdHeader, algorithmHeader, idHeader];

    if (nativeVersion == nil) {
        return [authorizationHeader stringByAppendingFormat:@",native_version=\"\""];
    }
    return [authorizationHeader stringByAppendingFormat:@",native_version=\"%@\"", nativeVersion];
}

#pragma mark - JSON
- (void)saveJsonResponse:(NSData *)jsonData responseData:(ADJResponseData *)responseData {
    NSError *error = nil;
    NSException *exception = nil;
    NSDictionary *jsonDict =
        [self buildJsonDict:jsonData exceptionPtr:&exception errorPtr:&error];

    if (exception != nil) {
        responseData.message =
            [NSString stringWithFormat:
                @"Failed to parse json response. (%@)", exception.description];
    } else if (error != nil) {
        responseData.message =
            [NSString stringWithFormat:
                @"Failed to parse json response. (%@)", error.localizedDescription];
    } else if ([ADJUtil isNull:jsonDict]) {
        responseData.message = [NSString stringWithFormat:@"Failed to parse json response "];
    } else {
        responseData.jsonResponse = jsonDict;
    }
}

- (NSDictionary *)buildJsonDict:(NSData *)jsonData
                   exceptionPtr:(NSException **)exceptionPtr
                       errorPtr:(NSError **)error {
    if (jsonData == nil) {
        return nil;
    }

    NSDictionary *jsonDict = nil;
    @try {
        jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    } @catch (NSException *ex) {
        *exceptionPtr = ex;
        return nil;
    }
    return jsonDict;
}

- (void)signWithSigV2PluginWithParams:(NSMutableDictionary *)params
                         activityKind:(ADJActivityKind)activityKind
                            clientSdk:(NSString *)clientSdk
{
    Class signerClass = NSClassFromString(@"ADJSigner");
    if (signerClass == nil) {
        return;
    }
    SEL signSEL = NSSelectorFromString(@"sign:withActivityKind:withSdkVersion:");
    if (![signerClass respondsToSelector:signSEL]) {
        return;
    }

    const char *activityKindChar = [[ADJActivityKindUtil activityKindToString:activityKind] UTF8String];
    const char *sdkVersionChar = [clientSdk UTF8String];

    // Stack allocated strings to ensure their lifetime stays until the next iteration
    static char packageActivityKind[64], sdkVersion[64];
    strncpy(packageActivityKind, activityKindChar, strlen(activityKindChar) + 1);
    strncpy(sdkVersion, sdkVersionChar, strlen(sdkVersionChar) + 1);

    // NSInvocation setArgument requires lvalue references with exact matching types to the executed function signature.
    // With this usage we ensure that the lifetime of the object remains until the next iteration, as it points to the
    // stack allocated string where we copied the buffer.
    const char *lvalActivityKind = packageActivityKind;
    const char *lvalSdkVersion = sdkVersion;

    /*
     [ADJSigner sign:parameters
    withActivityKind:activityKindChar
      withSdkVersion:sdkVersionChar];
     */

    NSMethodSignature *signMethodSignature = [signerClass methodSignatureForSelector:signSEL];
    NSInvocation *signInvocation = [NSInvocation invocationWithMethodSignature:signMethodSignature];
    [signInvocation setSelector:signSEL];
    [signInvocation setTarget:signerClass];

    [signInvocation setArgument:&params atIndex:2];
    [signInvocation setArgument:&lvalActivityKind atIndex:3];
    [signInvocation setArgument:&lvalSdkVersion atIndex:4];

    [signInvocation invoke];

    SEL getVersionSEL = NSSelectorFromString(@"getVersion");
    if (![signerClass respondsToSelector:getVersionSEL]) {
        return;
    }
    /*
     NSString *signerVersion = [ADJSigner getVersion];
     */
    IMP getVersionIMP = [signerClass methodForSelector:getVersionSEL];
    if (!getVersionIMP) {
        return;
    }
    id (*getVersionFunc)(id, SEL) = (void *)getVersionIMP;
    id signerVersion = getVersionFunc(signerClass, getVersionSEL);
    if (![signerVersion isKindOfClass:[NSString class]]) {
        return;
    }

    NSString *signerVersionString = (NSString *)signerVersion;
    [ADJPackageBuilder parameters:params
                           setString:signerVersionString
                           forKey:@"native_version"];
}

@end
