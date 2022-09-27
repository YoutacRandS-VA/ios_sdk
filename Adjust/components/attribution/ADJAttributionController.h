//
//  ADJAttributionController.h
//  Adjust
//
//  Created by Aditi Agrawal on 15/09/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ADJCommonBase.h"
#import "ADJSdkPackageSenderFactory.h"
#import "ADJPublishingGateSubscriber.h"
#import "ADJMeasurementSessionStartSubscriber.h"
#import "ADJSdkResponseSubscriber.h"
#import "ADJPausingSubscriber.h"
#import "ADJAttributionStateStorage.h"
#import "ADJClock.h"
#import "ADJSdkPackageBuilder.h"
#import "ADJThreadController.h"
#import "ADJAttributionSubscriber.h"
#import "ADJBackoffStrategy.h"
#import "ADJNetworkEndpointData.h"
#import "ADJClientConfigData.h"
#import "ADJMainQueueController.h"

@interface ADJAttributionController : ADJCommonBase<
    ADJSdkResponseCallbackSubscriber,
    // subscriptions
    ADJPublishingGateSubscriber,
    ADJMeasurementSessionStartSubscriber,
    ADJSdkResponseSubscriber,
    ADJPausingSubscriber
>
- (void)ccSubscribeToPublishersWithPublishingGatePublisher:(nonnull ADJPublishingGatePublisher *)publishingGatePublisher
                          measurementSessionStartPublisher:(nonnull ADJMeasurementSessionStartPublisher *)measurementSessionStartPublisher
                                      sdkResponsePublisher:(nonnull ADJSdkResponsePublisher *)sdkResponsePublisher
                                          pausingPublisher:(nonnull ADJPausingPublisher *)pausingPublisher;

// publishers
@property (nonnull, readonly, strong, nonatomic) ADJAttributionPublisher *attributionPublisher;

// instantiation
- (nonnull instancetype)initWithLoggerFactory:(nonnull id<ADJLoggerFactory>)loggerFactory
                      attributionStateStorage:(nonnull ADJAttributionStateStorage *)attributionStateStorage
                                        clock:(nonnull ADJClock *)clock
                            sdkPackageBuilder:(nonnull ADJSdkPackageBuilder *)sdkPackageBuilder
                             threadController:(nonnull ADJThreadController *)threadController
                   attributionBackoffStrategy:(nonnull ADJBackoffStrategy *)attributionBackoffStrategy
                      sdkPackageSenderFactory:(nonnull id<ADJSdkPackageSenderFactory>)sdkPackageSenderFactory
                          mainQueueController:(nonnull ADJMainQueueController *)mainQueueController
              doNotInitiateAttributionFromSdk:(BOOL)doNotInitiateAttributionFromSdk;

@end

