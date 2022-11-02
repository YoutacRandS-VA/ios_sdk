//
//  ADJLogMessageData.m
//  Adjust
//
//  Created by Pedro Silva on 27.10.22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJLogMessageData.h"

#import "ADJUtilConv.h"
#import "ADJUtilF.h"

#pragma mark Fields
#pragma mark - Public constants
NSString *const ADJLogMessageKey = @"message";
NSString *const ADJLogLevelKey = @"level";
NSString *const ADJLogIssueKey = @"issue";
NSString *const ADJLogErrorKey = @"error";
NSString *const ADJLogParamsKey = @"params";
NSString *const ADJLogSourceKey = @"source";
NSString *const ADJLogCallerThreadIdKey = @"callerId";
NSString *const ADJLogRunningThreadIdKey = @"runningId";
NSString *const ADJLogInstanceIdKey = @"instanceId";
NSString *const ADJLogIsPreSdkInitKey = @"isPreSdkInit";

#pragma mark - Public properties
/* .h
 @property (nonnull, readonly, strong, nonatomic) ADJInputLogMessageData *inputData;
 @property (nonnull, readonly, strong, nonatomic) NSString *sourceDescription;
 @property (nullable, readonly, strong, nonatomic) NSNumber *callerThreadId;
 @property (nullable, readonly, strong, nonatomic) NSNumber *runningThreadId;
 @property (nullable, readonly, strong, nonatomic) NSString *instanceId;
 */

@implementation ADJLogMessageData
// instantiation
- (nonnull instancetype)
    initWithInputData:(nonnull ADJInputLogMessageData *)inputData
    sourceDescription:(nonnull NSString *)sourceDescription
    callerThreadId:(nullable NSNumber *)callerThreadId
    runningThreadId:(nullable NSNumber *)runningThreadId
    instanceId:(nullable NSString *)instanceId
{
    self = [super init];

    _inputData = inputData;
    _sourceDescription = sourceDescription;
    _callerThreadId = callerThreadId;
    _runningThreadId = runningThreadId;
    _instanceId = instanceId;

    return self;
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (nonnull NSMutableDictionary <NSString *, id>*)generateFoundationDictionary {
    NSMutableDictionary *_Nonnull foundationDictionary =
        [[NSMutableDictionary alloc] initWithObjectsAndKeys:
            self.inputData.message, ADJLogMessageKey,
            self.inputData.level, ADJLogLevelKey,
            self.sourceDescription, ADJLogSourceKey, nil];
    
    if (self.inputData.issueType != nil) {
        [foundationDictionary setObject:self.inputData.issueType
                                 forKey:ADJLogIssueKey];
    }
    
    if (self.inputData.nsError != nil) {
        NSMutableDictionary *_Nonnull errorDictionary =
            [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                self.inputData.nsError.domain, @"domain",
                @(self.inputData.nsError.code),@"code",  nil];
        
        if (self.inputData.nsError.userInfo != nil) {
            [errorDictionary
                setObject:[ADJUtilConv convertToFoundationObject:self.inputData.nsError.userInfo]
                forKey:@"userInfo"];
        }
        
        [foundationDictionary setObject:errorDictionary forKey:ADJLogErrorKey];
    }
    
    if (self.inputData.messageParams != nil) {
        [foundationDictionary setObject:self.inputData.messageParams forKey:ADJLogParamsKey];
    }
    
    if (self.callerThreadId != nil) {
        [foundationDictionary setObject:self.callerThreadId forKey:ADJLogCallerThreadIdKey];
    }
    
    if (self.runningThreadId != nil) {
        [foundationDictionary setObject:self.runningThreadId forKey:ADJLogRunningThreadIdKey];
    }
    
    if (self.instanceId != nil) {
        [foundationDictionary setObject:self.instanceId forKey:ADJLogInstanceIdKey];
    } else {
        [foundationDictionary setObject:[NSNull null] forKey:ADJLogInstanceIdKey];
    }
    
    return foundationDictionary;
}

+ (nonnull NSString *)generateJsonFromFoundationDictionary:
    (nonnull NSDictionary<NSString *, id> *)foundationDictionary
{
    NSError *error;

    NSData *_Nullable jsonData =
        [ADJUtilConv convertToJsonDataWithJsonFoundationValue:foundationDictionary
                                                     errorPtr:&error];
    
    if (error != nil) {
        return [NSString stringWithFormat:@"{\"errorJsonConv\": \"%@\", \"originalDictionary\": \"%@\"}",
                error, foundationDictionary];
    }
    
    if (jsonData == nil) {
        return [NSString stringWithFormat:@"{\"nullJsonData\": true, \"originalDictionary\": \"%@\"}",
                foundationDictionary];
    }
    
    NSString *_Nullable jsonString = [ADJUtilF jsonDataFormat:jsonData];
    
    if (jsonString == nil) {
        return [NSString stringWithFormat:@"{\"nullJsonString\": true, \"originalDictionary\": \"%@\"}",
                foundationDictionary];

    }

    return jsonString;
}

@end
