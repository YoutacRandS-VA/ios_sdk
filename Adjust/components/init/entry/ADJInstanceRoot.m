//
//  ADJInstanceRoot.m
//  Adjust
//
//  Created by Genady Buchatsky on 04.11.22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJInstanceRoot.h"

#import "ADJLogger.h"
#import "ADJSdkConfigData.h"
#import "ADJPreSdkInitRoot.h"
#import "ADJPostSdkInitRoot.h"
#import "ADJPostSdkStartRoot.h"
#import "ADJPublisherController.h"

@interface ADJInstanceRoot ()
#pragma mark - Internal variables
@property (nullable, readonly, weak, nonatomic) id<ADJEntryRootBag> entryRootBagWeak;
@property (nullable, readwrite, strong, nonatomic) ADJPreSdkInitRoot *preSdkInitRoot;
@property (nullable, readwrite, strong, nonatomic) ADJPostSdkInitRoot *postSdkInitRoot;
@property (nonnull, readonly, strong, nonatomic) ADJLogger *logger;

@end

@implementation ADJInstanceRoot
#pragma mark - Synthesize protocol properties
@synthesize sdkConfigData = _sdkConfigData;
@synthesize instanceId = _instanceId;
@synthesize logController = _logController;
@synthesize threadController = _threadController;
@synthesize clientExecutor = _clientExecutor;
@synthesize commonExecutor = _commonExecutor;
@synthesize clock = _clock;
@synthesize publisherController = _publisherController;

#pragma mark Instantiation
+ (nonnull instancetype)instanceWithConfigData:(nonnull ADJSdkConfigData *)configData
                                    instanceId:(nonnull ADJInstanceIdData *)instanceId
                                  entryRootBag:(nonnull id<ADJEntryRootBag>)entryRootBag
{
    ADJInstanceRoot *_Nonnull instanceRoot =
        [[ADJInstanceRoot alloc] initWithConfigData:configData
                                         instanceId:instanceId
                                       entryRootBag:entryRootBag];

    [instanceRoot createSdkInitRootInClientContext];

    return instanceRoot;
}

- (nonnull instancetype)initWithConfigData:(nonnull ADJSdkConfigData *)configData
                                instanceId:(nonnull ADJInstanceIdData *)instanceId
                              entryRootBag:(nonnull id<ADJEntryRootBag>)entryRootBag
{
    self = [super init];
    _sdkConfigData = configData;
    _instanceId = instanceId;
    _entryRootBagWeak = entryRootBag;

    _clock = [[ADJClock alloc] init];

    _publisherController = [[ADJPublisherController alloc] init];

    _logController = [[ADJLogController alloc] initWithSdkConfigData:configData
                                                 publisherController:_publisherController
                                                          instanceId:instanceId];

    _threadController = [[ADJThreadController alloc] initWithLoggerFactory:_logController];

    _clientExecutor = [_threadController
                       createSingleThreadExecutorWithLoggerFactory:_logController
                       sourceDescription:@"clientExecutor"];
    _commonExecutor = [_threadController
                       createSingleThreadExecutorWithLoggerFactory:_logController
                       sourceDescription:@"commonExecutor"];
    [_logController injectDependeciesWithCommonExecutor:_commonExecutor];

    _logger = [_logController createLoggerWithSource:@"InstanceRoot"];

    return self;
}

- (void)createSdkInitRootInClientContext {
    __typeof(self) __weak weakSelf = self;
    [_clientExecutor executeInSequenceWithBlock:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        strongSelf.preSdkInitRoot = [[ADJPreSdkInitRoot alloc] initWithInstanceRootBag:strongSelf];
    } source:@"ADJInstanceRoot init"];
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark Public API
- (nullable NSString *)sdkPrefix {
    id<ADJEntryRootBag> _Nullable entryRootBag = self.entryRootBagWeak;
    if (entryRootBag == nil) {
        [self.logger debugDev:@"Cannot return sdk prefix without entry root reference"
                    issueType:ADJIssueWeakReference];
        return nil;
    }

    return entryRootBag.sdkPrefix;
}

- (void)finalizeAtTeardownWithBlock:(nullable void (^)(void))closeStorageBlock {
    __typeof(self) __weak weakSelf = self;
    BOOL canExecuteTask = [self.clientExecutor executeInSequenceWithBlock:^{

        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        if (strongSelf.preSdkInitRoot != nil) {
            [strongSelf.preSdkInitRoot finalizeAtTeardownWithBlock:closeStorageBlock];
        }

        if (strongSelf.postSdkInitRoot != nil) {
            [strongSelf.postSdkInitRoot finalizeAtTeardownWithBlock:closeStorageBlock];
        }

        [strongSelf.threadController finalizeAtTeardown];
    } source:@"finalizeAtTeardownWithBlock"];

    if (! canExecuteTask && closeStorageBlock != nil) {
        closeStorageBlock();
    }
}

#pragma mark - ADJAdjustInstance
- (void)initSdkWithConfig:(nonnull ADJAdjustConfig *)adjustConfig {
    [self ccExecuteWithPreAndSelfBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot,
                                          ADJInstanceRoot *_Nonnull instanceRoot)
     {
        ADJClientConfigData *_Nullable clientConfig = [ADJClientConfigData
                                                       instanceFromClientWithAdjustConfig:adjustConfig
                                                       logger:preSdkInitRoot.logger];

        if (! [preSdkInitRoot.sdkActiveController ccTrySdkInit]) {
            return;
        }

        // Initialize PostSdkInitRoot instance
        instanceRoot.postSdkInitRoot =
        [[ADJPostSdkInitRoot alloc] initWithClientConfig:clientConfig
                                         instanceRootBag:instanceRoot
                                       preSdkInitRootBag:preSdkInitRoot];

        // Inject remaining dependencies before subscriptions
        [preSdkInitRoot
         ccSetDependenciesAtSdkInitWithInstanceRootBag:instanceRoot
         postSdkInitRootBag:instanceRoot.postSdkInitRoot
         clientActionsPostSdkStart:instanceRoot.postSdkInitRoot.postSdkStartRoot];

        // Subscribe to publishers
        [instanceRoot ccSubscribeToPublishers:instanceRoot.publisherController];
        [preSdkInitRoot ccSubscribeToPublishers:instanceRoot.publisherController];
        [instanceRoot.postSdkInitRoot ccSubscribeToPublishers:instanceRoot.publisherController];

        // Finalize Initialization process
        [instanceRoot.postSdkInitRoot ccCompletePostSdkInit];

    } source:@"sdkInit"];
}

- (void)inactivateSdk {
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot) {
        [preSdkInitRoot.sdkActiveController ccInactivateSdk];
    } source:@"inactivateSdk"];
}

- (void)reactivateSdk {
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot) {
        [preSdkInitRoot.sdkActiveController ccReactivateSdk];
    } source:@"reactivateSdk"];
}

- (void)gdprForgetDevice {
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot) {
        BOOL updatedForgottenStatus = [preSdkInitRoot.sdkActiveController ccGdprForgetDevice];
        if (! updatedForgottenStatus) { return; }

        [preSdkInitRoot.gdprForgetController forgetDevice];
    } source:@"gdprForgetDevice"];
}

- (void)appWentToTheForegroundManualCall {
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot) {
        [preSdkInitRoot.lifecycleController ccForeground];
    } source:@"appWentToTheForegroundManualCall"];
}

- (void)appWentToTheBackgroundManualCall {
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot) {
        [preSdkInitRoot.lifecycleController ccBackground];
    } source:@"appWentToTheBackgroundManualCall"];
}

- (void)switchToOfflineMode {
    [self ccWhenActiveWithPreBlock:^(ADJPreSdkInitRoot * _Nonnull preSdkInitRoot) {
        [preSdkInitRoot.offlineController ccPutSdkOffline];
    } clientSource:@"switchToOfflineMode"];
}

 - (void)switchBackToOnlineMode {
     [self ccWhenActiveWithPreBlock:^(ADJPreSdkInitRoot * _Nonnull preSdkInitRoot) {
         [preSdkInitRoot.offlineController ccPutSdkOnline];
     } clientSource:@"switchBackToOnlineMode"];
 }

- (void)activateMeasurementConsent {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientMeasurementConsentData *consentData = [ADJClientMeasurementConsentData instanceWithActivateConsent];
        if (consentData == nil) { return; }

        [clientActionsAPI ccTrackMeasurementConsent:consentData];
    } clientSource:@"activateMeasurementConsent"];
}

- (void)inactivateMeasurementConsent {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientMeasurementConsentData *consentData = [ADJClientMeasurementConsentData instanceWithInactivateConsent];
        if (consentData == nil) { return; }

        [clientActionsAPI ccTrackMeasurementConsent:consentData];
    } clientSource:@"inactivateMeasurementConsent"];
}

- (void)deviceIdsWithCallback:(nonnull id<ADJAdjustDeviceIdsCallback>)adjustDeviceIdsCallback {
    [self ccWithAdjustCallback:adjustDeviceIdsCallback
                      preBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot)
     {
        [preSdkInitRoot.clientCallbacksController
         ccDeviceIdsWithCallback:adjustDeviceIdsCallback
         clientReturnExecutor:preSdkInitRoot.clientReturnExecutor
         deviceController:preSdkInitRoot.deviceController];
    } clientSource:@"deviceIdsWithCallback"];
}

- (void)adjustAttributionWithCallback:
    (nonnull id<ADJAdjustAttributionCallback>)adjustAttributionCallback
{
    [self ccWithAdjustCallback:adjustAttributionCallback
                      preBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot)
     {
        [preSdkInitRoot.clientCallbacksController
         ccAttributionWithCallback:adjustAttributionCallback
         clientReturnExecutor:preSdkInitRoot.clientReturnExecutor
         attributionStateStorage:preSdkInitRoot.storageRoot.attributionStateStorage];
    } clientSource:@"adjustAttributionWithCallback"];
}

- (void)adjustLaunchedDeeplinkWithCallback:
(nonnull id<ADJAdjustLaunchedDeeplinkCallback>)adjustLaunchedDeeplinkCallback
{
    [self ccWithAdjustCallback:adjustLaunchedDeeplinkCallback
                      preBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot)
     {
        [preSdkInitRoot.clientCallbacksController
         ccLaunchedDeepLinkWithCallback:adjustLaunchedDeeplinkCallback
         clientReturnExecutor:preSdkInitRoot.clientReturnExecutor
         LaunchedDeeplinkStateStorage:preSdkInitRoot.storageRoot.launchedDeeplinkStateStorage];
    } clientSource:@"adjustLaunchedDeeplinkWithCallback"];
}

- (void)trackEvent:(nonnull ADJAdjustEvent *)adjustEvent {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientEventData *_Nullable clientData =
            [ADJClientEventData instanceFromClientWithAdjustEvent:adjustEvent
                                                           logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccTrackEventWithClientData:clientData];
    } clientSource:@"trackEvent"];
}

- (void)trackLaunchedDeeplink:(nonnull ADJAdjustLaunchedDeeplink *)adjustLaunchedDeeplink {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientLaunchedDeeplinkData *_Nullable clientData =
            [ADJClientLaunchedDeeplinkData
             instanceFromClientWithAdjustLaunchedDeeplink:adjustLaunchedDeeplink
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccTrackLaunchedDeeplinkWithClientData:clientData];
    } clientSource:@"trackLaunchedDeeplink"];
}

- (void)trackPushToken:(nonnull ADJAdjustPushToken *)adjustPushToken {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientPushTokenData *_Nullable clientData =
            [ADJClientPushTokenData
             instanceFromClientWithAdjustPushToken:adjustPushToken
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccTrackPushTokenWithClientData:clientData];
    } clientSource:@"trackPushToken"];
}

- (void)trackThirdPartySharing:(nonnull ADJAdjustThirdPartySharing *)adjustThirdPartySharing {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientThirdPartySharingData *_Nullable clientData =
            [ADJClientThirdPartySharingData
             instanceFromClientWithAdjustThirdPartySharing:adjustThirdPartySharing
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccTrackThirdPartySharingWithClientData:clientData];
    } clientSource:@"trackThirdPartySharing"];
}

- (void)trackAdRevenue:(nonnull ADJAdjustAdRevenue *)adjustAdRevenue {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientAdRevenueData *_Nullable clientData =
            [ADJClientAdRevenueData
             instanceFromClientWithAdjustAdRevenue:adjustAdRevenue
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccTrackAdRevenueWithClientData:clientData];
    } clientSource:@"trackAdRevenue"];
}

- (void)trackBillingSubscription:(nonnull ADJAdjustBillingSubscription *)adjustBillingSubscription {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientBillingSubscriptionData *_Nullable clientData =
            [ADJClientBillingSubscriptionData
             instanceFromClientWithAdjustBillingSubscription:adjustBillingSubscription
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccTrackBillingSubscriptionWithClientData:clientData];
    } clientSource:@"trackBillingSubscription"];
}

- (void)addGlobalCallbackParameterWithKey:(nonnull NSString *)key value:(nonnull NSString *)value {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientAddGlobalParameterData *_Nullable clientData =
            [ADJClientAddGlobalParameterData
             instanceFromClientWithAdjustConfigWithKeyToAdd:key
             valueToAdd:value
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccAddGlobalCallbackParameterWithClientData:clientData];
    } clientSource:@"addGlobalCallbackParameter"];
}
- (void)removeGlobalCallbackParameterByKey:(nonnull NSString *)key {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientRemoveGlobalParameterData *_Nullable clientData =
            [ADJClientRemoveGlobalParameterData
             instanceFromClientWithAdjustConfigWithKeyToRemove:key
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccRemoveGlobalCallbackParameterWithClientData:clientData];
    } clientSource:@"removeGlobalCallbackParameter"];
}
- (void)clearAllGlobalCallbackParameters {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientClearGlobalParametersData *_Nonnull clientData =
            [[ADJClientClearGlobalParametersData alloc] init];

        [clientActionsAPI ccClearGlobalCallbackParametersWithClientData:clientData];
    } clientSource:@"clearAllGlobalCallbackParameters"];
}

- (void)addGlobalPartnerParameterWithKey:(nonnull NSString *)key value:(nonnull NSString *)value {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientAddGlobalParameterData *_Nullable clientData =
            [ADJClientAddGlobalParameterData
             instanceFromClientWithAdjustConfigWithKeyToAdd:key
             valueToAdd:value
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccAddGlobalPartnerParameterWithClientData:clientData];
    } clientSource:@"addGlobalPartnerParameter"];
}

- (void)removeGlobalPartnerParameterByKey:(nonnull NSString *)key {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientRemoveGlobalParameterData *_Nullable clientData =
            [ADJClientRemoveGlobalParameterData
             instanceFromClientWithAdjustConfigWithKeyToRemove:key
             logger:logger];
        if (clientData == nil) { return; }

        [clientActionsAPI ccRemoveGlobalPartnerParameterWithClientData:clientData];
    } clientSource:@"removeGlobalPartnerParameter"];
}

- (void)clearAllGlobalPartnerParameters {
    [self ccExecuteWithClientActionsBlock:^(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                                            ADJLogger * _Nonnull logger)
     {
        ADJClientClearGlobalParametersData *_Nonnull clientData =
            [[ADJClientClearGlobalParametersData alloc] init];

        [clientActionsAPI ccClearGlobalPartnerParametersWithClientData:clientData];
    } clientSource:@"clearAllGlobalPartnerParameters"];
}

#pragma mark Internal methods
- (void)
     ccExecuteWithPreBlock:
         (void (^_Nonnull)(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot))preBlock
     source:(nonnull NSString *)source
 {
     [self ccExecuteWithPreAndSelfBlock:
      ^(ADJPreSdkInitRoot * _Nonnull preSdkInitRoot, ADJInstanceRoot *_Nonnull instanceRoot) {
         preBlock(preSdkInitRoot);
     } source:source];
}
- (void)
     ccExecuteWithPreAndSelfBlock:
     (void (^_Nonnull)
      (ADJPreSdkInitRoot *_Nonnull preSdkInitRoot,
       ADJInstanceRoot *_Nonnull instanceRoot))preAndSelfBlock
     source:(nonnull NSString *)source
 {
    __typeof(self) __weak weakSelf = self;
    [self.clientExecutor executeInSequenceWithBlock:^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        ADJPreSdkInitRoot *_Nullable preSdkInitRootLocal = strongSelf.preSdkInitRoot;
        if (preSdkInitRootLocal == nil) {
            [strongSelf.logger debugDev:@"Unexpected invalid PreSdkInitRoot with self block"
                                   from:source
                              issueType:ADJIssueLogicError];
            return;
        }

        preAndSelfBlock(preSdkInitRootLocal, strongSelf);
    } source:source];
}

- (void)ccWhenActiveWithPreBlock: (void (^_Nonnull)(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot))preBlock
                    clientSource:(nonnull NSString *)clientSource {
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot * _Nonnull preSdkInitRoot) {
        if ([preSdkInitRoot.sdkActiveController ccCanPerformActionWithClientSource:clientSource]) {
            preBlock(preSdkInitRoot);
        }
    } source:clientSource];
}

- (void)
    ccWithAdjustCallback:(nullable id<ADJAdjustCallback>)adjustCallback
    preBlock:(void (^_Nonnull)(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot))preBlock
    clientSource:(nonnull NSString *)clientSource
{
    [self ccExecuteWithPreBlock:^(ADJPreSdkInitRoot * _Nonnull preSdkInitRoot) {
        if (adjustCallback == nil) {
            [preSdkInitRoot.logger errorClient:@"Cannot use invalid callback"
                                               from:clientSource];
            return;
        }

        NSString *_Nullable cannotPerformMessage =
            [preSdkInitRoot.sdkActiveController
             ccCanPerformActionOrElseMessageWithClientSource:clientSource];

        if (cannotPerformMessage != nil) {
            [preSdkInitRoot.clientCallbacksController
             failWithAdjustCallback:adjustCallback
             clientReturnExecutor:preSdkInitRoot.clientReturnExecutor
             cannotPerformMessage:cannotPerformMessage];
            return;
        }

        preBlock(preSdkInitRoot);
    } source:clientSource];
}

- (void)
    ccExecuteWithClientActionsBlock:
        (void (^_Nonnull)(id<ADJClientActionsAPI> _Nonnull clientActionsAPI,
                          ADJLogger *_Nonnull logger))clientActionsBlock
    clientSource:(nonnull NSString *)clientSource
{
    [self ccWhenActiveWithPreBlock:^(ADJPreSdkInitRoot *_Nonnull preSdkInitRoot) {
        clientActionsBlock([preSdkInitRoot.clientActionController ccClientMeasurementActions],
                           preSdkInitRoot.logger);
    } clientSource:clientSource];
}

- (void)ccSubscribeToPublishers:(ADJPublisherController *)publisherController {
    [publisherController subscribeToPublisher:self.logController];
}

@end
