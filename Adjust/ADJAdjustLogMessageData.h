//
//  ADJAdjustLogMessageData.h
//  Adjust
//
//  Created by Aditi Agrawal on 19/07/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *ADJAdjustLogLevel NS_TYPED_ENUM;
FOUNDATION_EXPORT ADJAdjustLogLevel const ADJAdjustLogLevelTrace;
FOUNDATION_EXPORT ADJAdjustLogLevel const ADJAdjustLogLevelDebug;
FOUNDATION_EXPORT ADJAdjustLogLevel const ADJAdjustLogLevelInfo;
FOUNDATION_EXPORT ADJAdjustLogLevel const ADJAdjustLogLevelNotice;
FOUNDATION_EXPORT ADJAdjustLogLevel const ADJAdjustLogLevelError;

NS_ASSUME_NONNULL_END

@interface ADJAdjustLogMessageData : NSObject
// instantiation
- (nonnull instancetype)initWithLogMessage:(nonnull NSString *)logMessage
                           messageLogLevel:(nonnull ADJAdjustLogLevel)messageLogLevel
NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)init NS_UNAVAILABLE;

// public properties
@property (nonnull, readonly, strong, nonatomic) NSString *logMessage;
@property (nonnull, readonly, strong, nonatomic) ADJAdjustLogLevel messageLogLevel;

@end