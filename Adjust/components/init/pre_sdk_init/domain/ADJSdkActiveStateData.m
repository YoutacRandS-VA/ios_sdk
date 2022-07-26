//
//  ADJSdkActiveStateData.m
//  AdjustV5
//
//  Created by Pedro S. on 21.01.21.
//  Copyright © 2021 adjust GmbH. All rights reserved.
//

#import "ADJSdkActiveStateData.h"

#import "ADJBooleanWrapper.h"
#import "ADJIoDataBuilder.h"
#import "ADJUtilMap.h"
#import "ADJUtilObj.h"
#import "ADJConstants.h"

#pragma mark Fields
#pragma mark - Public properties
/* .h
 @property (nonatomic, assign) BOOL isSdkActive;
 */
#pragma mark - Public constants
NSString *const ADJSdkActiveStateDataMetadataTypeValue = @"SdkActiveStateData";

#pragma mark - Private constants
static NSString *const kIsSdkActiveKey = @"isSdkActive";

@implementation ADJSdkActiveStateData
#pragma mark Instantiation
+ (nullable instancetype)instanceFromIoData:(nonnull ADJIoData *)ioData
                                     logger:(nonnull ADJLogger *)logger
{
    if (! [ioData
           isExpectedMetadataTypeValue:ADJSdkActiveStateDataMetadataTypeValue
           logger:logger])
    {
        return nil;
    }

    ADJBooleanWrapper *_Nullable isSdkActive =
        [ADJBooleanWrapper
            instanceFromIoValue:
                [ioData.propertiesMap pairValueWithKey:kIsSdkActiveKey]
            logger:logger];

    if (isSdkActive == nil) {
        [logger error:@"Cannot create instance from Io data without valid %@", kIsSdkActiveKey];
        return nil;
    }

    return [[self alloc] initWithIsActiveSdk:isSdkActive.boolValue];
}

- (nonnull instancetype)initWithInitialState {
    return [self initWithActiveSdk];
}

- (nonnull instancetype)initWithActiveSdk {
    return [self initWithIsActiveSdk:YES];
}

- (nonnull instancetype)initWithInactiveSdk {
    return [self initWithIsActiveSdk:NO];
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - Private constructors
- (nonnull instancetype)initWithIsActiveSdk:(BOOL)isSdkActive {
    self = [super init];

    _isSdkActive = isSdkActive;

    return self;
}

#pragma mark Public API
#pragma mark - ADJIoDataSerializable
- (nonnull ADJIoData *)toIoData {
    ADJIoDataBuilder *_Nonnull ioDataBuilder =
        [[ADJIoDataBuilder alloc]
            initWithMetadataTypeValue:ADJSdkActiveStateDataMetadataTypeValue];

    [ADJUtilMap
        injectIntoIoDataBuilderMap:ioDataBuilder.propertiesMapBuilder
        key:kIsSdkActiveKey
        ioValueSerializable:[ADJBooleanWrapper instanceFromBool:self.isSdkActive]];

    return [[ADJIoData alloc] initWithIoDataBuider:ioDataBuilder];
}

#pragma mark - NSObject
- (nonnull NSString *)description {
    return [ADJUtilObj formatInlineKeyValuesWithName:
                ADJSdkActiveStateDataMetadataTypeValue,
                    kIsSdkActiveKey, @(self.isSdkActive),
                nil];
}

- (NSUInteger)hash {
    NSUInteger hashCode = ADJInitialHashCode;

    hashCode = ADJHashCodeMultiplier * hashCode + [@(self.isSdkActive) hash];

    return hashCode;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[ADJSdkActiveStateData class]]) {
        return NO;
    }

    ADJSdkActiveStateData *other = (ADJSdkActiveStateData *)object;
    return self.isSdkActive == other.isSdkActive;
}

@end