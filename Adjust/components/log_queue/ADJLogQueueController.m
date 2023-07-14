//
//  ADJLogQueueController.m
//  Adjust
//
//  Created by Aditi Agrawal on 20/09/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJLogQueueController.h"

#import "ADJLogQueueStateAndTracker.h"
#import "ADJSdkPackageBuilder.h"
#import "ADJConstants.h"

#pragma mark Fields
@interface ADJLogQueueController ()
#pragma mark - Injected dependencies
@property (nullable, readonly, weak, nonatomic) ADJLogQueueStorage *storageWeak;
@property (nullable, readonly, weak, nonatomic) ADJClock *clockWeak;

#pragma mark - Internal variables
@property (nonnull, readonly, strong, nonatomic) ADJSingleThreadExecutor *executor;
@property (nonnull, readonly, strong, nonatomic) ADJSdkPackageSender *sender;
@property (nonnull, readonly, strong, nonatomic) ADJLogQueueStateAndTracker *logQueueStateAndTracker;

@end

@implementation ADJLogQueueController
#pragma mark Instantiation
- (nonnull instancetype)
    initWithLoggerFactory:(nonnull id<ADJLoggerFactory>)loggerFactory
    storage:(nonnull ADJLogQueueStorage *)storage
    threadController:(nonnull ADJThreadController *)threadController
    clock:(nonnull ADJClock *)clock
    backoffStrategy:(nonnull ADJBackoffStrategy *)backoffStrategy
    sdkPackageSenderFactory:(nonnull id<ADJSdkPackageSenderFactory>)sdkPackageSenderFactory
{
    self = [super initWithLoggerFactory:loggerFactory loggerName:@"LogQueueController"];
    _storageWeak = storage;
    _clockWeak = clock;

    _executor = [threadController createSingleThreadExecutorWithLoggerFactory:loggerFactory
                                                             sourceLoggerName:self.logger.name];

    _sender = [sdkPackageSenderFactory createSdkPackageSenderWithLoggerFactory:loggerFactory
                                                              sourceLoggerName:self.logger.name
                                                         threadExecutorFactory:threadController];

    _logQueueStateAndTracker =
    [[ADJLogQueueStateAndTracker alloc] initWithLoggerFactory:loggerFactory
                                              backoffStrategy:backoffStrategy];

    return self;

}

#pragma mark Public API
- (void)addLogPackageDataToSendWithData:(nonnull ADJLogPackageData *)logPackageData {
    __typeof(self) __weak weakSelf = self;
    [self.executor executeInSequenceWithLogger:self.logger
                                              from:@"add log package"
                                             block:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        [strongSelf handleLogPackageAddedToSendWithData:logPackageData];
    }];
}

#pragma mark - ADJSdkResponseCallbackSubscriber
- (void)sdkResponseCallbackWithResponseData:(nonnull id<ADJSdkResponseData>)sdkResponseData {
    __typeof(self) __weak weakSelf = self;
    [self.executor executeInSequenceWithLogger:self.logger
                                              from:@"received sdk response"
                                             block:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        [strongSelf handleResponseWithData:sdkResponseData];
    }];
}

- (void)ccOnSdkInitWithClientConfigData:(nonnull ADJClientConfigData *)clientConfigData {
    __typeof(self) __weak weakSelf = self;
    [self.executor executeInSequenceWithLogger:self.logger
                                              from:@"sdk init"
                                             block:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        [strongSelf handleSdkInit];
    }];
}

#pragma mark - ADJPausingSubscriber
- (void)didResumeSendingWithSource:(nonnull NSString *)source {
    __typeof(self) __weak weakSelf = self;
    [self.executor executeInSequenceWithLogger:self.logger
                                              from:@"resume sending"
                                             block:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        [strongSelf handleResumeSending];
    }];
}

- (void)didPauseSendingWithSource:(nonnull NSString *)source {
    __typeof(self) __weak weakSelf = self;
    [self.executor executeInSequenceWithLogger:self.logger
                                              from:@"pause sending"
                                             block:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        [strongSelf.logQueueStateAndTracker pauseSending];
    }];
}

#pragma mark Internal Methods
- (void)handleLogPackageAddedToSendWithData:(nonnull ADJLogPackageData *)logPackageDataToAdd {
    ADJLogQueueStorage *_Nullable storage = self.storageWeak;
    if (storage == nil) {
        [self.logger debugDev:
         @"Cannot add log package to send without a reference to the storage"
                    issueType:ADJIssueWeakReference];
        return;
    }

    [storage enqueueElementToLast:logPackageDataToAdd sqliteStorageAction:nil];

    ADJLogPackageData *_Nullable packageAtFront = [storage elementAtFront];

    BOOL sendPackageAtFront =
    [self.logQueueStateAndTracker sendWhenLogPackageAddedWithData:logPackageDataToAdd
                                                packageQueueCount:[storage count]
                                                hasPackageAtFront:packageAtFront != nil];
    if (sendPackageAtFront) {
        NSString *_Nonnull from =
        [NSString stringWithFormat:@"%@ added",
         [logPackageDataToAdd generateShortDescription]];

        [self sendPackageWithData:packageAtFront
                          storage:storage
                           from:from];
    }
}

- (void)handleSdkInit {
    ADJLogQueueStorage *_Nullable storage = self.storageWeak;
    if (storage == nil) {
        [self.logger debugDev:@"Cannot handle sdk init without a reference to the storage"
                    issueType:ADJIssueWeakReference];
        return;
    }

    ADJLogPackageData *_Nullable packageAtFront = [storage elementAtFront];

    BOOL sendPackageAtFront =
    [self.logQueueStateAndTracker sendWhenSdkInitWithHasPackageAtFront:packageAtFront != nil];

    if (sendPackageAtFront) {
        [self sendPackageWithData:packageAtFront
                          storage:storage
                           from:@"sdk init"];
    }
}

- (void)handleResumeSending {
    ADJLogQueueStorage *_Nullable storage = self.storageWeak;
    if (storage == nil) {
        [self.logger debugDev:
         @"Cannot handle resuming sending without a reference to the storage"
                    issueType:ADJIssueWeakReference];
        return;
    }

    ADJLogPackageData *_Nullable packageAtFront = [storage elementAtFront];

    BOOL sendPackageAtFront =
    [self.logQueueStateAndTracker
     sendWhenResumeSendingWithHasPackageAtFront:packageAtFront != nil];

    if (sendPackageAtFront) {
        [self sendPackageWithData:packageAtFront
                          storage:storage
                           from:@"resume sending"];
    }
}

- (void)handleResponseWithData:(nonnull id<ADJSdkResponseData>)sdkResponseData {
    ADJLogQueueStorage *_Nullable storage = self.storageWeak;
    if (storage == nil) {
        [self.logger debugDev:@"Cannot handle response without a reference to the storage"
                    issueType:ADJIssueWeakReference];
        return;
    }

    ADJQueueResponseProcessingData *_Nonnull responseProcessingData =
    [self.logQueueStateAndTracker processReceivedSdkResponseWithData:sdkResponseData];

    if (responseProcessingData.removePackageAtFront) {
        [self removePackageAtFrontWithStorage:storage];
    }

    if (responseProcessingData.delayData != nil) {
        [self delaySendWithData:responseProcessingData.delayData];
        return;
    }

    ADJLogPackageData *_Nullable packageAtFront = [storage elementAtFront];

    BOOL sendPackageAtFront =
    [self.logQueueStateAndTracker
     sendAfterProcessingSdkResponseWithHasPackageAtFront:packageAtFront != nil];

    if (sendPackageAtFront) {
        [self sendPackageWithData:packageAtFront
                          storage:storage
                           from:@"handle response"];
    }
}

- (void)removePackageAtFrontWithStorage:(nonnull ADJLogQueueStorage *)storage {
    ADJLogPackageData *_Nullable removedSdkPackage = [storage removeElementAtFront];

    if (removedSdkPackage == nil) {
        [self.logger debugDev:@"Should not be empty when removing package at front"
                    issueType:ADJIssueLogicError];
    } else {
        [self.logger debugDev:@"Package at front removed"];
    }
}

- (void)delaySendWithData:(nonnull ADJDelayData *)delayData {
    __typeof(self) __weak weakSelf = self;
    [self.executor scheduleInSequenceWithLogger:self.logger
                                           from:@"delay end"
                                 delayTimeMilli:delayData.delay
                                          block:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        [strongSelf handleDelayEndFrom:delayData.from];
    }];
}

- (void)handleDelayEndFrom:(nonnull NSString *)from {
    [self.logger debugDev:@"Delay ended" from:from];

    ADJLogQueueStorage *_Nullable storage = self.storageWeak;
    if (storage == nil) {
        [self.logger debugDev:@"Cannot handle delay end without a reference to the storage"
                    issueType:ADJIssueWeakReference];
        return;
    }

    ADJLogPackageData *_Nullable packageAtFront = [storage elementAtFront];

    BOOL sendPackageAtFront =
    [self.logQueueStateAndTracker
     sendWhenDelayEndedWithHasPackageAtFront:packageAtFront != nil];

    if (sendPackageAtFront) {
        [self sendPackageWithData:packageAtFront
                          storage:storage
                           from:@"handle delay end"];
    }
}

- (void)sendPackageWithData:(nullable id<ADJSdkPackageData>)packageToSend
                    storage:(nonnull ADJLogQueueStorage *)storage
                       from:(nonnull NSString *)from
{
    if (packageToSend == nil) {
        [self.logger debugDev:@"Cannot send package when it is nil"
                          key:ADJLogFromKey
                  stringValue:from
                    issueType:ADJIssueInvalidInput];
        return;
    }

    [self.logger debugDev:@"To send sdk package"
                     from:from
                      key:@"package"
              stringValue:[packageToSend generateShortDescription].stringValue];

    ADJStringMapBuilder *_Nonnull sendingParameters =
    [self generateSendingParametersWithStorage:storage];

    [self.sender sendSdkPackageWithData:packageToSend
                      sendingParameters:sendingParameters
                       responseCallback:self];
}

- (nonnull ADJStringMapBuilder *)generateSendingParametersWithStorage:
(nonnull ADJLogQueueStorage *)storage {
    ADJStringMapBuilder *_Nonnull sendingParameters =
    [[ADJStringMapBuilder alloc] initWithEmptyMap];

    [ADJSdkPackageBuilder
     injectAttemptsWithParametersBuilder:sendingParameters
     attempts:[self.logQueueStateAndTracker retriesSinceLastSuccessSend]];

    ADJNonNegativeInt *_Nonnull currentQueueSize = [storage count];

    if (currentQueueSize.uIntegerValue > 0) {
        ADJNonNegativeInt *_Nonnull remaingQueueSize =
        [[ADJNonNegativeInt alloc] initWithUIntegerValue:
         currentQueueSize.uIntegerValue - 1];

        [ADJSdkPackageBuilder
         injectRemainingQueuSizeWithParametersBuilder:sendingParameters
         remainingQueueSize:remaingQueueSize];
    } else {
        [self.logger debugDev:@"Cannot inject remaining queue size when its empty"
                    issueType:ADJIssueLogicError];
    }

    ADJClock *_Nullable clock = self.clockWeak;
    if (clock == nil) {
        [self.logger debugDev:@"Cannot inject sent at without a reference to clock"
                    issueType:ADJIssueWeakReference];
        return sendingParameters;
    }

    ADJResult<ADJTimestampMilli *> *_Nonnull nowResult = [clock nonMonotonicNowTimestamp];
    if (nowResult.fail != nil) {
        [self.logger debugDev:@"Invalid now timestamp when injecting sent at"
                  resultFail:nowResult.fail
                    issueType:ADJIssueExternalApi];
    } else {
        [ADJSdkPackageBuilder
         injectSentAtWithParametersBuilder:sendingParameters
         sentAtTimestamp:nowResult.value];

    }

    return sendingParameters;
}

@end