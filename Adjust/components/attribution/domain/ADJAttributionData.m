//
//  ADJAttributionData.m
//  Adjust
//
//  Created by Aditi Agrawal on 15/09/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJAttributionData.h"

#import "ADJUtilObj.h"
#import "ADJUtilMap.h"
#import "ADJConstants.h"
#import "ADJConstantsParam.h"
#import "ADJMoneyDoubleAmount.h"
#import "ADJAdjustInternal.h"
#import "ADJUtilF.h"
#import "ADJUtilJson.h"

#pragma mark Fields
#pragma mark - Public properties
/* .h
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *trackerToken;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *trackerName;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *network;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *campaign;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *adgroup;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *creative;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *clickLabel;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *deeplink;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *state;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *costType;
 @property (nullable, readonly, strong, nonatomic) ADJMoneyAmountBase *costAmount;
 @property (nullable, readonly, strong, nonatomic) ADJNonEmptyString *costCurrency;
 */

#pragma mark - Public constants
NSString *const ADJAttributionDataMetadataTypeValue = @"AttributionData";

#pragma mark - Private constants
static NSString *const kTrackerTokenKey = @"trackerToken";
static NSString *const kTrackerNameKey = @"trackerName";
static NSString *const kNetworkKey = @"network";
static NSString *const kCampaignKey = @"campaign";
static NSString *const kAdgroupKey = @"adgroup";
static NSString *const kCreativeKey = @"creative";
static NSString *const kClickLabelKey = @"clickLabel";
static NSString *const kDeeplinkKey = @"deeplink";
static NSString *const kStateKey = @"state";
static NSString *const kCostTypeKey = @"costType";
static NSString *const kCostAmountKey = @"costAmount";
static NSString *const kCostCurrencyKey = @"costCurrency";

@implementation ADJAttributionData
#pragma mark Instantiation
+ (nonnull ADJOptionalFails<ADJAttributionData *> *)
    instanceFromIoDataMap:(nonnull ADJStringMap *)ioDataMap
{
    ADJResult<ADJMoneyDoubleAmount *> *_Nonnull costAmountResult =
        [self extractCostAmountWithIoValue:[ioDataMap pairValueWithKey:kCostAmountKey]];

    return [[ADJOptionalFails alloc]
            initWithOptionalFails:
                costAmountResult.failNonNilInput != nil
                ? [NSArray arrayWithObject:costAmountResult.fail] : nil
            value:[[ADJAttributionData alloc]
                   initWithTrackerToken:[ioDataMap pairValueWithKey:kTrackerTokenKey]
                   trackerName:[ioDataMap pairValueWithKey:kTrackerNameKey]
                   network:[ioDataMap pairValueWithKey:kNetworkKey]
                   campaign:[ioDataMap pairValueWithKey:kCampaignKey]
                   adgroup:[ioDataMap pairValueWithKey:kAdgroupKey]
                   creative:[ioDataMap pairValueWithKey:kCreativeKey]
                   clickLabel:[ioDataMap pairValueWithKey:kClickLabelKey]
                   deeplink:[ioDataMap pairValueWithKey:kDeeplinkKey]
                   state:[ioDataMap pairValueWithKey:kStateKey]
                   costType:[ioDataMap pairValueWithKey:kCostTypeKey]
                   costAmount:costAmountResult.value
                   costCurrency:[ioDataMap pairValueWithKey:kCostCurrencyKey]]];
}

#define extrJsonCall(dictKey) \
    [ADJAttributionData extractStringWithDictionary:attributionJson     \
                                                key:(dictKey)           \
                                   optionalFailsMut:optionalFailsMut]   \


+ (nonnull ADJOptionalFails<ADJAttributionData *> *)
    instanceFromJson:(nonnull NSDictionary *)attributionJson
{
    NSMutableArray<ADJResultFail *> *_Nonnull optionalFailsMut = [[NSMutableArray alloc] init];

    ADJResult<NSNumber *> *_Nonnull costAmountDoubleNumberResult =
        [ADJUtilMap extractDoubleNumberWithDictionary:attributionJson
                                                  key:ADJParamAttributionCostAmountKey];
    if (costAmountDoubleNumberResult.failNonNilInput != nil) {
        [optionalFailsMut addObject:
         [[ADJResultFail alloc]
          initWithMessage:@"Cannot parse double value for cost amount from number"
          key:@"double number fail"
          otherFail:costAmountDoubleNumberResult.fail]];
    }
    ADJResult<ADJMoneyDoubleAmount *> *_Nullable costAmountDoubleResult =
        [ADJMoneyDoubleAmount instanceFromDoubleNumberValue:costAmountDoubleNumberResult.value];
    if (costAmountDoubleResult.failNonNilInput != nil) {
        [optionalFailsMut addObject:
         [[ADJResultFail alloc]
          initWithMessage:@"Cannot parse money value for cost amount from double number"
          key:@"money amount fail"
          otherFail:costAmountDoubleResult.fail]];
    }

    return [[ADJOptionalFails alloc]
            initWithOptionalFails:optionalFailsMut
            value:[[ADJAttributionData alloc]
                   initWithTrackerToken:extrJsonCall(ADJParamAttributionTrackerTokenKey)
                   trackerName:extrJsonCall(ADJParamAttributionTrackerNameKey)
                   network:extrJsonCall(ADJParamAttributionNetworkKey)
                   campaign:extrJsonCall(ADJParamAttributionCampaignKey)
                   adgroup:extrJsonCall(ADJParamAttributionAdGroupKey)
                   creative:extrJsonCall(ADJParamAttributionCreativeKey)
                   clickLabel:extrJsonCall(ADJParamAttributionClickLableKey)
                   deeplink:extrJsonCall(ADJParamAttributionDeeplinkKey)
                   state:extrJsonCall(ADJParamAttributionStateKey)
                   costType:extrJsonCall(ADJParamAttributionCostTypeKey)
                   costAmount:costAmountDoubleResult.value
                   costCurrency:extrJsonCall(ADJParamAttributionCostCurrencyKey)]];
}

- (nonnull instancetype)initWithTrackerToken:(nullable ADJNonEmptyString *)trackerToken
                                 trackerName:(nullable ADJNonEmptyString *)trackerName
                                     network:(nullable ADJNonEmptyString *)network
                                    campaign:(nullable ADJNonEmptyString *)campaign
                                     adgroup:(nullable ADJNonEmptyString *)adgroup
                                    creative:(nullable ADJNonEmptyString *)creative
                                  clickLabel:(nullable ADJNonEmptyString *)clickLabel
                                    deeplink:(nullable ADJNonEmptyString *)deeplink
                                       state:(nullable ADJNonEmptyString *)state
                                    costType:(nullable ADJNonEmptyString *)costType
                                  costAmount:(nullable ADJMoneyDoubleAmount *)costAmount
                                costCurrency:(nullable ADJNonEmptyString *)costCurrency
{
    self = [super init];
    
    _trackerToken = trackerToken;
    _trackerName = trackerName;
    _network = network;
    _campaign = campaign;
    _adgroup = adgroup;
    _creative = creative;
    _clickLabel = clickLabel;
    _deeplink = deeplink;
    _state = state;
    _costType = costType;
    _costAmount = costAmount;
    _costCurrency = costCurrency;
    
    return self;
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark Public API
- (nonnull ADJAdjustAttribution *)toAdjustAttribution {
    ADJAdjustAttribution *_Nonnull adjustAttribution = [[ADJAdjustAttribution alloc] init];
    
    adjustAttribution.trackerToken = [ADJUtilF stringValueOrNil:self.trackerToken];
    adjustAttribution.trackerName = [ADJUtilF stringValueOrNil:self.trackerName];
    adjustAttribution.network = [ADJUtilF stringValueOrNil:self.network];
    adjustAttribution.campaign = [ADJUtilF stringValueOrNil:self.campaign];
    adjustAttribution.adgroup = [ADJUtilF stringValueOrNil:self.adgroup];
    adjustAttribution.creative = [ADJUtilF stringValueOrNil:self.creative];
    adjustAttribution.clickLabel = [ADJUtilF stringValueOrNil:self.clickLabel];
    adjustAttribution.deeplink = [ADJUtilF stringValueOrNil:self.deeplink];
    adjustAttribution.state = [ADJUtilF stringValueOrNil:self.state];
    adjustAttribution.costType = [ADJUtilF stringValueOrNil:self.costType];
    adjustAttribution.costAmount = self.costAmount != nil ? self.costAmount.doubleNumberValue : nil;
    adjustAttribution.costCurrency = [ADJUtilF stringValueOrNil:self.costCurrency];
    
    return adjustAttribution;
}

- (nonnull ADJOptionalFails<NSDictionary<NSString *, id> *> *)
    buildInternalCallbackDataWithMethodName:(nonnull NSString *)methodName
{
    NSMutableDictionary<NSString *, id> *_Nonnull callbackDataMut =
        [[NSMutableDictionary alloc] init];

    ADJAdjustAttribution *_Nonnull adjustAttribution = [self toAdjustAttribution];
    [callbackDataMut setObject:adjustAttribution
                        forKey:[NSString stringWithFormat:@"%@%@",
                                methodName, ADJInternalCallbackAdjustDataSuffix]];

    NSDictionary<NSString *, id> *_Nonnull jsonDictionary =
        [ADJAttributionData toJsonDictionaryWithAdjustAttribution:adjustAttribution];
    [callbackDataMut setObject:jsonDictionary
                        forKey:[NSString stringWithFormat:@"%@%@",
                                methodName, ADJInternalCallbackNsDictionarySuffix]];

    ADJOptionalFails<NSString *> *_Nonnull jsonStringOptFails =
        [ADJUtilJson toStringFromDictionary:jsonDictionary];
    [callbackDataMut setObject:jsonStringOptFails.value
                        forKey:[NSString stringWithFormat:@"%@%@",
                                methodName, ADJInternalCallbackJsonStringSuffix]];

    return [[ADJOptionalFails alloc] initWithOptionalFails:jsonStringOptFails.optionalFails
                                                       value:callbackDataMut];
}

+ (nonnull NSDictionary<NSString *, id> *)toJsonDictionaryWithAdjustAttribution:
    (nonnull ADJAdjustAttribution *)adjustAttribution
{
    NSMutableDictionary<NSString *, id> *_Nonnull jsonDictionaryMut =
        [[NSMutableDictionary alloc] initWithCapacity:13];

    // keys in ioData match the AdjustAttribution names, so might just well use them
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.trackerToken]
                          forKey:kTrackerTokenKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.trackerName]
                          forKey:kTrackerNameKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.network]
                          forKey:kNetworkKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.campaign]
                          forKey:kCampaignKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.adgroup]
                          forKey:kAdgroupKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.creative]
                          forKey:kCreativeKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.clickLabel]
                          forKey:kClickLabelKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.deeplink]
                          forKey:kDeeplinkKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.state]
                          forKey:kStateKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.costType]
                          forKey:kCostTypeKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.costAmount]
                          forKey:kCostAmountKey];
    [jsonDictionaryMut setObject:[ADJUtilObj idOrNsNull:adjustAttribution.costCurrency]
                          forKey:kCostCurrencyKey];

    return jsonDictionaryMut;
}

#pragma mark - ADJIoDataMapBuilderInjectable

#define injectIoData(keyValue, ioValue)                         \
     [ADJUtilMap injectIntoIoDataBuilderMap:ioDataMapBuilder    \
                                        key:keyValue            \
                        ioValueSerializable:ioValue]            \

- (void)injectIntoIoDataMapBuilder:(nonnull ADJStringMapBuilder *)ioDataMapBuilder {
    injectIoData(kTrackerTokenKey, self.trackerToken);
    injectIoData(kTrackerNameKey, self.trackerName);
    injectIoData(kNetworkKey, self.network);
    injectIoData(kCampaignKey, self.campaign);
    injectIoData(kAdgroupKey, self.adgroup);
    injectIoData(kCreativeKey, self.creative);
    injectIoData(kClickLabelKey, self.clickLabel);
    injectIoData(kDeeplinkKey, self.deeplink);
    injectIoData(kStateKey, self.state);
    injectIoData(kCostTypeKey, self.costType);
    injectIoData(kCostAmountKey, self.costAmount);
    injectIoData(kCostCurrencyKey, self.costCurrency);
}

#pragma mark - NSObject
- (nonnull NSString *)description {
    return [ADJUtilObj formatInlineKeyValuesWithName:
            ADJAttributionDataMetadataTypeValue,
            kTrackerTokenKey, self.trackerToken,
            kTrackerNameKey, self.trackerName,
            kNetworkKey, self.network,
            kCampaignKey, self.campaign,
            kAdgroupKey, self.adgroup,
            kCreativeKey, self.creative,
            kClickLabelKey, self.clickLabel,
            kDeeplinkKey, self.deeplink,
            kStateKey, self.state,
            kCostTypeKey, self.costType,
            kCostAmountKey, self.costAmount,
            kCostCurrencyKey, self.costCurrency,
            nil];
}

- (NSUInteger)hash {
    NSUInteger hashCode = ADJInitialHashCode;
    
    hashCode = ADJHashCodeMultiplier * hashCode +
        [ADJUtilObj objecNullableHash:self.trackerToken];
    hashCode = ADJHashCodeMultiplier * hashCode +
        [ADJUtilObj objecNullableHash:self.trackerName];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.network];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.campaign];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.adgroup];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.creative];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.clickLabel];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.deeplink];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.state];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.costType];
    hashCode = ADJHashCodeMultiplier * hashCode + [ADJUtilObj objecNullableHash:self.costAmount];
    hashCode = ADJHashCodeMultiplier * hashCode +
        [ADJUtilObj objecNullableHash:self.costCurrency];
    
    return hashCode;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[ADJAttributionData class]]) {
        return NO;
    }
    
    ADJAttributionData *other = (ADJAttributionData *)object;
    return [ADJUtilObj objectEquals:self.trackerToken other:other.trackerToken]
        && [ADJUtilObj objectEquals:self.trackerName other:other.trackerName]
        && [ADJUtilObj objectEquals:self.network other:other.network]
        && [ADJUtilObj objectEquals:self.campaign other:other.campaign]
        && [ADJUtilObj objectEquals:self.adgroup other:other.adgroup]
        && [ADJUtilObj objectEquals:self.creative other:other.creative]
        && [ADJUtilObj objectEquals:self.clickLabel other:other.clickLabel]
        && [ADJUtilObj objectEquals:self.deeplink other:other.deeplink]
        && [ADJUtilObj objectEquals:self.state other:other.state]
        && [ADJUtilObj objectEquals:self.costType other:other.costType]
        && [ADJUtilObj objectEquals:self.costAmount other:other.costAmount]
        && [ADJUtilObj objectEquals:self.costCurrency other:other.costCurrency];
}

#pragma mark Internal Methods
+ (nonnull NSString *)stringValueOrNil:(nullable ADJNonEmptyString *)value {
    return value != nil ? value.stringValue : nil;
}

+ (nullable ADJNonEmptyString *)
    extractStringWithDictionary:(nonnull NSDictionary *)jsonDictionary
    key:(nonnull NSString *)key
    optionalFailsMut:(nonnull NSMutableArray<ADJResultFail *> *)optionalFailsMut
{
    ADJResult<NSString *> *_Nonnull extractedNsStringResult =
        [ADJUtilMap extractStringValueWithDictionary:jsonDictionary
                                                 key:key];

    if (extractedNsStringResult.failNonNilInput != nil) {
        ADJResultFailBuilder *_Nonnull failBuilder =
            [[ADJResultFailBuilder alloc] initWithMessage:
             @"Cannot extract string value from json"];

        [failBuilder withKey:@"extraction fail" otherFail:extractedNsStringResult.fail];
        [failBuilder withKey:@"json key" stringValue:key];

        [optionalFailsMut addObject:[failBuilder build]];
    }

    ADJResult<ADJNonEmptyString *> *_Nonnull stringResult =
        [ADJNonEmptyString instanceFromString:extractedNsStringResult.value];
    if (stringResult.failNonNilInput != nil) {
        ADJResultFailBuilder *_Nonnull failBuilder =
            [[ADJResultFailBuilder alloc] initWithMessage:
             @"Cannot parse string from extracted json value"];

        [failBuilder withKey:@"string parsing fail" otherFail:stringResult.fail];
        [failBuilder withKey:@"json key" stringValue:key];

        [optionalFailsMut addObject:[failBuilder build]];
    }

    return stringResult.value;
}

+ (nonnull ADJResult<ADJMoneyDoubleAmount *> *)
    extractCostAmountWithIoValue:(nullable ADJNonEmptyString *)ioValue
{
    if (ioValue == nil) {
        return [ADJResult nilInputWithMessage:@"Cannot extract cost amount from nil io value"];
    }

    NSString *_Nullable ioMoneyDoubleAmountSubValue =
        [ADJMoneyDoubleAmount ioMoneyDoubleAmountSubValueWithIoValue:ioValue];

    if (ioMoneyDoubleAmountSubValue == nil) {
        return [ADJResult failWithMessage:@"Cost amount did not match expected double sub type"
                                      key:ADJLogActualKey
                              stringValue:ioValue.stringValue];
    }

    return [ADJMoneyDoubleAmount
            instanceFromIoMoneyDoubleAmountSubValue:ioMoneyDoubleAmountSubValue];;
}

@end