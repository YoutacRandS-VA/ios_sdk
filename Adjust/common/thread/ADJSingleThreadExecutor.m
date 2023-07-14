//
//  ADJSingleThreadExecutor.m
//  Adjust
//
//  Created by Aditi Agrawal on 12/07/22.
//  Copyright © 2022 Adjust GmbH. All rights reserved.
//

#import "ADJSingleThreadExecutor.h"

#import "ADJUtilSys.h"
#import "ADJLocalThreadController.h"
#import "ADJConstants.h"

#pragma mark Fields
@interface ADJSingleThreadExecutor ()
#pragma mark - Injected dependencies
#pragma mark - Internal variables
@property (nonnull, readonly, strong, nonatomic) dispatch_queue_t serialQueue;
@property (readwrite, assign, nonatomic) BOOL isThreadExecuting;
@property (readwrite, assign, nonatomic) BOOL hasFinalized;

@end

@implementation ADJSingleThreadExecutor
#pragma mark Instantiation
- (nonnull instancetype)initWithLoggerFactory:(nonnull id<ADJLoggerFactory>)loggerFactory
                             sourceLoggerName:(nonnull NSString *)sourceLoggerName
{
    self = [super initWithLoggerFactory:loggerFactory
                             loggerName:[NSString stringWithFormat:@"%@-STE", sourceLoggerName]];

    _serialQueue = dispatch_queue_create(self.logger.name.UTF8String,
                                         dispatch_queue_attr_make_with_qos_class
                                         (DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, 0));

    _isThreadExecuting = NO;
    _hasFinalized = NO;

    return self;
}

- (nullable instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark Public API
- (nullable ADJResultFail *)scheduleInSequenceFrom:(nonnull NSString *)from
                                    delayTimeMilli:(nonnull ADJTimeLengthMilli *)delayTimeMilli
                                             block:(nonnull void (^)(void))blockToSchedule
{
    if (delayTimeMilli.millisecondsSpan.uIntegerValue == 0) {
        return [self executeInSequenceFrom:from block:blockToSchedule];
    }

    if (self.hasFinalized) {
        return [[ADJResultFail alloc]
                initWithMessage:@"Cannot schedule in sequence when it has finalized"];
    }

    __block ADJLocalThreadController *_Nonnull localThreadController =
    [ADJLocalThreadController instance];

    NSString *_Nonnull callerLocalId = [localThreadController localIdOrOutside];

    __typeof(self) __weak weakSelf = self;
    dispatch_after
    ([ADJUtilSys dispatchTimeWithMilli:delayTimeMilli.millisecondsSpan.uIntegerValue],
     self.serialQueue,
     ^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        NSString *_Nonnull runningLocalId =
            [localThreadController
             setNextLocalIdWithSerialDispatchQueue:strongSelf.serialQueue];

        [strongSelf.logger traceThreadChangeWithCallerThreadId:callerLocalId
                                               runningThreadId:runningLocalId
                                                    fromCaller:from];

        blockToSchedule();
    });

    return nil;
}
- (void)scheduleInSequenceWithLogger:(nonnull ADJLogger *)logger
                                from:(nonnull NSString *)from
                      delayTimeMilli:(nonnull ADJTimeLengthMilli *)delayTimeMilli
                               block:(nonnull void (^)(void))block
{
    ADJResultFail *_Nullable scheduleFail =
        [self scheduleInSequenceFrom:from
                      delayTimeMilli:delayTimeMilli
                               block:block];
    if (scheduleFail != nil) {
        [logger debugDev:@"Failed to schedule in sequence with delay"
                    from:from
              resultFail:scheduleFail
               issueType:ADJIssueThreadsAndLocks];
    }
}

- (nullable ADJResultFail *)executeInSequenceFrom:(nonnull NSString *)from
                                            block:(nonnull void (^)(void))blockToExecute
{
    return [self executeInSequenceFromCaller:from block:blockToExecute];
}
- (void)executeInSequenceWithLogger:(nonnull ADJLogger *)logger
                               from:(nonnull NSString *)from
                              block:(nonnull void (^)(void))blockToExecute
{
    ADJResultFail *_Nullable executeFail = [self executeInSequenceFrom:from block:blockToExecute];
    if (executeFail != nil) {
        [logger debugDev:@"Failed to execute in sequence"
                    from:from
              resultFail:executeFail
               issueType:ADJIssueThreadsAndLocks];
    }
}

- (nullable ADJResultFail *)
    executeInSequenceSkippingTraceWithBlock:(nonnull void (^)(void))blockToExecute
{
    return [self executeInSequenceFromCaller:nil block:blockToExecute];
}

- (nullable ADJResultFail *)executeAsyncFrom:(nonnull NSString *)from
                                       block:(nonnull void (^)(void))blockToExecute
{
    if (self.hasFinalized) {
        return [[ADJResultFail alloc]
                initWithMessage:@"Cannot execute async when it has finalized"];
    }

    __block ADJLocalThreadController *_Nonnull localThreadController =
        [ADJLocalThreadController instance];

    __block NSString *_Nonnull callerLocalId = [localThreadController localIdOrOutside];

    __typeof(self) __weak weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        NSString *_Nonnull runningLocalId =
            [localThreadController setNextLocalIdInConcurrentThread];

        // no need to check for skip trace local id,
        //  since there is no async executions downstream of the log collection.
        //  If/when that changes, it will be necessary to check here
        [strongSelf.logger traceThreadChangeWithCallerThreadId:callerLocalId
                                               runningThreadId:runningLocalId
                                                    fromCaller:from];

        blockToExecute();

        // because the thread can be reused by an outside execution
        //  it needs to be clear to avoid reading it again by mistake
        [localThreadController removeLocalIdInConcurrentThread];
    });

    return nil;
}
- (void)executeAsyncWithLogger:(nonnull ADJLogger *)logger
                          from:(nonnull NSString *)from
                         block:(nonnull void (^)(void))blockToExecute
{
    ADJResultFail *_Nullable executeFail = [self executeAsyncFrom:from block:blockToExecute];
    if (executeFail != nil) {
        [logger debugDev:@"Failed to execute async"
                    from:from
              resultFail:executeFail
               issueType:ADJIssueThreadsAndLocks];
    }
}

- (nullable ADJResultFail *)executeSynchronouslyFrom:(nonnull NSString *)from
                                             timeout:(nonnull ADJTimeLengthMilli *)timeout
                                               block:(nonnull void (^)(void))blockToExecute
{
    __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    ADJResultFail *_Nullable executeAsyncFail = [self executeAsyncFrom:from
                                                                 block:^{
        blockToExecute();
        dispatch_semaphore_signal(semaphore);
    }];

    if (executeAsyncFail != nil) {
        return [[ADJResultFail alloc] initWithMessage:@"Cannot execute sync with timeout"
                                                  key:@"execute async fail"
                                            otherFail:executeAsyncFail];
    }

    intptr_t waitResult =
        dispatch_semaphore_wait(semaphore,
                                [ADJUtilSys
                                 dispatchTimeWithMilli:timeout.millisecondsSpan.uIntegerValue]);

    if (waitResult != 0) {
        return [[ADJResultFail alloc] initWithMessage:@"Could end sync execution within timeout"
                                                  key:@"timeout milliseconds"
                                          stringValue:timeout.millisecondsDescription];
    }

    return nil;
}
- (void)executeSynchronouslyWithLogger:(nonnull ADJLogger *)logger
                                  from:(nonnull NSString *)from
                               timeout:(nonnull ADJTimeLengthMilli *)timeout
                                 block:(nonnull void (^)(void))blockToExecute
{
    ADJResultFail *_Nullable executeFail = [self executeSynchronouslyFrom:from
                                                                  timeout:timeout
                                                                    block:blockToExecute];
    if (executeFail != nil) {
        [logger debugDev:@"Failed to execute sync"
                    from:from
              resultFail:executeFail
               issueType:ADJIssueThreadsAndLocks];
    }
}

#pragma mark - ADJTeardownFinalizer
- (void)finalizeAtTeardown {
    if (self.hasFinalized) {
        return;
    }
    self.hasFinalized = YES;
}

#pragma mark - NSObject
- (void)dealloc {
    [self finalizeAtTeardown];
}

#pragma mark Internal Methods
- (nullable ADJResultFail *)executeInSequenceFromCaller:(nullable NSString *)fromCaller
                                                  block:(nonnull void (^)(void))blockToExecute
{
    if (self.hasFinalized) {
        return [[ADJResultFail alloc]
                initWithMessage:@"Cannot execute in sequence when it has finalized"];
    }

    __block ADJLocalThreadController *_Nonnull localThreadController =
    [ADJLocalThreadController instance];

    NSString *_Nonnull callerLocalId = [localThreadController localIdOrOutside];

    __typeof(self) __weak weakSelf = self;
    dispatch_async(self.serialQueue, ^{
        __typeof(weakSelf) __strong strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        if (fromCaller != nil) {
            // no need to set a new thread id when it is tracing a new thread
            //  because, so far, there is any sort of logging downstream of the log collector
            // If that changes and some "special" (to avoid looping) logging is done, then
            //  this will need to be done in those cases
            NSString *_Nonnull runningLocalId =
            [localThreadController setNextLocalIdWithSerialDispatchQueue:strongSelf.serialQueue];

            [strongSelf.logger traceThreadChangeWithCallerThreadId:callerLocalId
                                                   runningThreadId:runningLocalId
                                                        fromCaller:fromCaller];
        }

        blockToExecute();
    });

    return nil;
}

/*
 private void tryToRunI(@NonNull final RunnableWrap runnableWrap) {
     try {
         // not inside the skip local trace id check
         //  since .setNextLocalId() has the side effect of writing the thread local id
         @NonNull final NonNegativeLong runningThreadId =
                 LocalThreadController.setNextLocalIdAndReturnIt();

         if (! runnableWrap.skipTraceLocalId) {
             @NonNull final NonNegativeLong callerThreadId = runnableWrap.callerThreadId;

             logger.trace(callerThreadId, runningThreadId,
                     "Changing Thread local id from %s to %s in: %s",
                     callerThreadId, runningThreadId, runnableWrap.sourceDescription);
         }

         runnableWrap.run();
     } catch (@Nullable final Throwable throwable) {
         // catch exception here, instead of letting thread pool handle it, to have log of source
         logger.errorStackTrace(IssueType.THREADS_AND_LOCKS, throwable, "Execution failed");
     }
 }

- (void)executeQueuedBlocks {
    void (^nextBlockToExecute)(void);

    while (YES) {
        @synchronized (self.blockQueue) {
            // exit condition of while true loop, when no more tasks are left to run
            if (self.blockQueue.count == 0) {
                self.isThreadExecuting = NO;
                break;
            }
            // pop next task to be run
            nextBlockToExecute = [self.blockQueue objectAtIndex:0];
            [self.blockQueue removeObjectAtIndex:0];
        }

        // running of the next task outside of synchronized to not block it
        nextBlockToExecute();
    }
}
*/
@end