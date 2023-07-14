//
//  ADJPushTokenStateData.h
//  Adjust
//
//  Created by Aditi Agrawal on 13/02/23.
//  Copyright © 2023 Adjust GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADJIoDataSerializable.h"
#import "ADJIoData.h"
#import "ADJNonEmptyString.h"

// public constants
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const ADJPushTokenStateDataMetadataTypeValue;

NS_ASSUME_NONNULL_END

@interface ADJPushTokenStateData : NSObject<ADJIoDataSerializable>
// instantiation
+ (nonnull ADJResult<ADJPushTokenStateData *> *)instanceFromIoData:(nonnull ADJIoData *)ioData;

- (nonnull instancetype)initWithInitialState;

- (nonnull instancetype)initWithLastPushTokenString:(nullable ADJNonEmptyString *)lastPushToken;

- (nullable instancetype)init NS_UNAVAILABLE;

// public properties
@property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *lastPushToken;

@end