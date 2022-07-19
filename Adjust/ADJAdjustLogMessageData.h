//
//  ADJAdjustLogMessageData.h
//  Adjust
//
//  Created by Aditi Agrawal on 19/07/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const ADJAdjustLogLevelDebug;
FOUNDATION_EXPORT NSString *const ADJAdjustLogLevelInfo;
FOUNDATION_EXPORT NSString *const ADJAdjustLogLevelError;

NS_ASSUME_NONNULL_END

@interface ADJAdjustLogMessageData : NSObject
// instantiation
- (nonnull instancetype)initWithLogMessage:(nonnull NSString *)logMessage
                                    source:(nonnull NSString *)source
                            messageLogLevel:(nonnull NSString *)messageLogLevel
    NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)init NS_UNAVAILABLE;

// public properties
@property (nonnull, readonly, strong, nonatomic) NSString *logMessage;
@property (nonnull, readonly, strong, nonatomic) NSString *source;
@property (nonnull, readonly, strong, nonatomic) NSString *messageLogLevel;

// public api
- (nonnull NSString *)generateFullLog;

+ (nonnull NSString *)generateFullLogWithMessage:(nonnull NSString *)logMessage
                                          source:(nonnull NSString *)source
                                 messageLogLevel:(nonnull NSString *)messageLogLevel;

@end
