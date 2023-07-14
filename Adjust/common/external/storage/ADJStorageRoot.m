//
//  ADJStorageRoot.m
//  Adjust
//
//  Created by Aditi Agrawal on 20/07/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJStorageRoot.h"
#import "ADJSingleThreadExecutor.h"

#pragma mark Fields
#pragma mark - Public properties
/* .h
 @property (nonnull, readonly, strong, nonatomic) ADJKeychainStorage *keychainStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJSQLiteController *sqliteController;
 @property (nonnull, readonly, strong, nonatomic) ADJAdidStateStorage *adidStateStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJAttributionStateStorage *attributionStateStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJAsaAttributionStateStorage *asaAttributionStateStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJCoppaStateStorage *coppaStateStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJClientActionStorage *clientActionStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJDeviceIdsStorage *deviceIdsStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJPushTokenStateStorage *pushTokenStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJEventStateStorage *eventStateStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJEventDeduplicationStorage *eventDeduplicationStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJGlobalCallbackParametersStorage *globalCallbackParametersStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJGlobalPartnerParametersStorage *globalPartnerParametersStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJGdprForgetStateStorage *gdprForgetStateStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJLogQueueStorage *logQueueStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJMainQueueStorage *mainQueueStorage;
 @property (nonnull, readonly, strong, nonatomic) ADJSdkActiveStateStorage *sdkActiveStateStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJMeasurementSessionStateStorage *measurementSessionStateStorage;
 @property (nonnull, readonly, strong, nonatomic)
     ADJLaunchedDeeplinkStateStorage *launchedDeeplinkStateStorage;
 */
@interface ADJStorageRoot ()

#pragma mark - Internal variables
@property (nonnull, readonly, strong, nonatomic) ADJSingleThreadExecutor *storageExecutor;
//@property (nonnull, readonly, strong, nonatomic) ADJV4FilesController *v4FilesController;
@end

@implementation ADJStorageRoot
#pragma mark Instantiation
#define buildAndInjectStorage(varName, classType)       \
    _ ## varName = [[classType alloc]                   \
        initWithLoggerFactory:loggerFactory             \
        storageExecutor:self.storageExecutor            \
        sqliteController:self.sqliteController];        \
    [self.sqliteController addSqlStorage:self.varName]  \

- (nonnull instancetype)
    initWithLoggerFactory:(nonnull id<ADJLoggerFactory>)loggerFactory
    threadExecutorFactory:(nonnull id<ADJThreadExecutorFactory>)threadExecutorFactory
    instanceId:(nonnull ADJInstanceIdData *)instanceId
{
    self = [super initWithLoggerFactory:loggerFactory loggerName:@"StorageRoot"];

    _storageExecutor = [threadExecutorFactory
                        createSingleThreadExecutorWithLoggerFactory:loggerFactory
                        sourceLoggerName:@"Storage"];

    _keychainStorage = [[ADJKeychainStorage alloc] initWithLoggerFactory:loggerFactory];

    _sqliteController = [[ADJSQLiteController alloc] initWithLoggerFactory:loggerFactory
                                                                instanceId:instanceId];

    buildAndInjectStorage(adidStateStorage, ADJAdidStateStorage);
    buildAndInjectStorage(attributionStateStorage, ADJAttributionStateStorage);
    buildAndInjectStorage(asaAttributionStateStorage, ADJAsaAttributionStateStorage);
    buildAndInjectStorage(clientActionStorage, ADJClientActionStorage);
    buildAndInjectStorage(coppaStateStorage, ADJCoppaStateStorage);
    buildAndInjectStorage(deviceIdsStorage, ADJDeviceIdsStorage);
    buildAndInjectStorage(eventStateStorage, ADJEventStateStorage);
    buildAndInjectStorage(pushTokenStorage, ADJPushTokenStateStorage);
    buildAndInjectStorage(eventDeduplicationStorage, ADJEventDeduplicationStorage);
    buildAndInjectStorage(gdprForgetStateStorage, ADJGdprForgetStateStorage);
    buildAndInjectStorage(globalCallbackParametersStorage, ADJGlobalCallbackParametersStorage);
    buildAndInjectStorage(globalPartnerParametersStorage, ADJGlobalPartnerParametersStorage);
    buildAndInjectStorage(logQueueStorage, ADJLogQueueStorage);
    buildAndInjectStorage(mainQueueStorage, ADJMainQueueStorage);
    buildAndInjectStorage(sdkActiveStateStorage, ADJSdkActiveStateStorage);
    buildAndInjectStorage(measurementSessionStateStorage, ADJMeasurementSessionStateStorage);
    buildAndInjectStorage(launchedDeeplinkStateStorage, ADJLaunchedDeeplinkStateStorage);

    [self.sqliteController readAllIntoMemorySync];

    return self;
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark Public API
- (void)finalizeAtTeardownWithCloseStorageBlock:(nullable void (^)(void))closeStorageBlock {
    __typeof(self) __weak weakSelf = self;
    ADJResultFail *_Nullable executeFail =
        [self.storageExecutor executeInSequenceFrom:@"finalize at teardown"
                                              block:^{
            __typeof(weakSelf) __strong strongSelf = weakSelf;
            if (strongSelf == nil) { return; }

            [strongSelf.sqliteController.sqliteDb close];

            if (closeStorageBlock != nil) {
                closeStorageBlock();
            }

            // prevent any other storage task from executing
            [strongSelf.storageExecutor finalizeAtTeardown];
        }];
    if (executeFail != nil) {
        [self.logger debugDev:@"Cannot execute finalize at teardown"
                   resultFail:executeFail
                    issueType:ADJIssueThreadsAndLocks];

        if (closeStorageBlock != nil) {
            closeStorageBlock();
        }
    }
}

#pragma mark - ADJTeardownFinalizer

- (void)finalizeAtTeardown {
    [self finalizeAtTeardownWithCloseStorageBlock:nil];
}

@end

