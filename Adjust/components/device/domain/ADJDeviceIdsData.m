//
//  ADJDeviceIdsData.m
//  Adjust
//
//  Created by Pedro S. on 23.02.21.
//  Copyright © 2021 adjust GmbH. All rights reserved.
//

#import "ADJDeviceIdsData.h"

#import "ADJUtilMap.h"
#import "ADJUtilObj.h"
#import "ADJConstants.h"

#pragma mark Fields
#pragma mark - Public properties
/* .h
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *uuid;
 */
#pragma mark - Public constants
NSString *const ADJDeviceIdsDataMetadataTypeValue = @"DeviceIdsData";

#pragma mark - Private constants
static NSString *const kUuidKey = @"uuid";

@implementation ADJDeviceIdsData
#pragma mark Instantiation
+ (nonnull ADJResult<ADJDeviceIdsData *> *)instanceFromIoData:(nonnull ADJIoData *)ioData {
    ADJResultFail *_Nullable unexpectedMetadataTypeValueFail =
        [ioData isExpectedMetadataTypeValue:ADJDeviceIdsDataMetadataTypeValue];
    if (unexpectedMetadataTypeValueFail != nil) {
        return [ADJResult failWithMessage:@"Cannot create device ids data from io data"
                                      key:@"unexpected metadata type value fail"
                                otherFail:unexpectedMetadataTypeValueFail];
    }

    ADJNonEmptyString *_Nullable uuid = [ioData.propertiesMap pairValueWithKey:kUuidKey];

    return [ADJResult okWithValue:[[ADJDeviceIdsData alloc] initWithUuid:uuid]];
}

+ (nonnull ADJResult<ADJDeviceIdsData *> *)
    instanceFromV4WithActivityState:(nullable ADJV4ActivityState *)v4ActivityState
{
    if (v4ActivityState == nil) {
        return [ADJResult nilInputWithMessage:
                @"Cannot create Device Ids with nil v4 activity state"];
    }

    ADJResult<ADJNonEmptyString *> *_Nonnull v4UuidResult =
         [ADJNonEmptyString instanceFromString:v4ActivityState.uuid];
    if (v4UuidResult.wasInputNil) {
        return [ADJResult nilInputWithMessage:
                @"Cannot create Device Ids with nil uuid in v4 activity state"];
    }

    if (v4UuidResult.fail != nil) {
        return [ADJResult failWithMessage:@"Cannot parse uuid from v4 activity state"
                                      key:@"uuid parse fail"
                                otherFail:v4UuidResult.fail];
    }

    return [ADJResult okWithValue:v4UuidResult.value];
}


- (nonnull instancetype)initWithInitialState {
    return [self initWithUuid:nil];
}

- (nonnull instancetype)initWithUuid:(nullable ADJNonEmptyString *)uuid {
    self = [super init];

    _uuid = uuid;

    return self;
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark Public API
#pragma mark - ADJIoDataSerializable
- (nonnull ADJIoData *)toIoData {
    ADJIoDataBuilder *_Nonnull ioDataBuilder =
    [[ADJIoDataBuilder alloc]
     initWithMetadataTypeValue:ADJDeviceIdsDataMetadataTypeValue];

    [ADJUtilMap injectIntoIoDataBuilderMap:ioDataBuilder.propertiesMapBuilder
                                       key:kUuidKey
                       ioValueSerializable:self.uuid];

    return [[ADJIoData alloc] initWithIoDataBuilder:ioDataBuilder];
}

#pragma mark - NSObject
- (nonnull NSString *)description {
    return [ADJUtilObj formatInlineKeyValuesWithName:
            ADJDeviceIdsDataMetadataTypeValue,
            kUuidKey, self.uuid,
            nil];
}

- (NSUInteger)hash {
    NSUInteger hashCode = ADJInitialHashCode;

    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.uuid];

    return hashCode;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[ADJDeviceIdsData class]]) {
        return NO;
    }

    ADJDeviceIdsData *other = (ADJDeviceIdsData *)object;
    return [ADJUtilObj objectEquals:self.uuid other:other.uuid];
}

@end