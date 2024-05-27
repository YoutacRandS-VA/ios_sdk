//
//  AppDelegate.m
//  AdjustExample-ObjC
//
//  Created by Pedro Filipe (@nonelse) on 12th October 2015.
//  Copyright © 2015-Present Adjust GmbH. All rights reserved.
//

#import "Constants.h"
#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Configure Adjust SDK.
    NSString *appToken = kAppToken;
    NSString *environment = ADJEnvironmentSandbox;
    ADJConfig *adjustConfig = [ADJConfig configWithAppToken:appToken environment:environment];

    // Change the log level.
    [adjustConfig setLogLevel:ADJLogLevelVerbose];

    // Set default tracker.
    // [adjustConfig setDefaultTracker:@"{TrackerToken}"];

    // Send in the background.
    // [adjustConfig setSendInBackground:YES];

    // Enable LinkMe feature.
    // [adjustConfig enableLinkMe];

    // Set an attribution delegate.
    [adjustConfig setDelegate:self];

    // Add global callback parameters.
    [Adjust addGlobalCallbackParameter:@"sp_bar" forKey:@"sp_foo"];
    [Adjust addGlobalCallbackParameter:@"sp_value" forKey:@"sp_key"];

    // Add global partner parameters.
    [Adjust addGlobalPartnerParameter:@"sp_bar" forKey:@"sp_foo"];
    [Adjust addGlobalPartnerParameter:@"sp_value" forKey:@"sp_key"];

    // Remove global callback parameter.
    [Adjust removeGlobalCallbackParameterForKey:@"sp_key"];

    // Remove global partner parameter.
    [Adjust removeGlobalPartnerParameterForKey:@"sp_foo"];
    
    // Remove all global callback parameters.
    // [Adjust removeGlobalCallbackParameters];

    // Remove all global partner parameters.
    // [Adjust removeGlobalPartnerParameters];
    
    // Initialise the SDK.
    [Adjust appDidLaunch:adjustConfig];
    
    // Put the SDK in offline mode.
    // [Adjust setOfflineMode:YES];
    
    // Disable the SDK.
    // [Adjust setEnabled:NO];
    
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"Scheme based deep link opened an app: %@", url);
    // add your code below to handle deep link
    // (e.g., open deep link content)
    // url object contains the deep link

    // Call the below method to send deep link to Adjust backend
    [Adjust processDeeplink:url];
    return YES;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *restorableObjects))restorationHandler {
    if ([[userActivity activityType] isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSLog(@"Universal link opened an app: %@", [userActivity webpageURL]);
        // Pass deep link to Adjust in order to potentially reattribute user.
        [Adjust processDeeplink:[userActivity webpageURL]];
    }
    return YES;
}

- (void)adjustAttributionChanged:(ADJAttribution *)attribution {
    NSLog(@"Attribution callback called!");
    NSLog(@"Attribution: %@", attribution);
}

- (void)adjustEventTrackingSucceeded:(ADJEventSuccess *)eventSuccessResponseData {
    NSLog(@"Event success callback called!");
    NSLog(@"Event success data: %@", eventSuccessResponseData);
}

- (void)adjustEventTrackingFailed:(ADJEventFailure *)eventFailureResponseData {
    NSLog(@"Event failure callback called!");
    NSLog(@"Event failure data: %@", eventFailureResponseData);
}

- (void)adjustSessionTrackingSucceeded:(ADJSessionSuccess *)sessionSuccessResponseData {
    NSLog(@"Session success callback called!");
    NSLog(@"Session success data: %@", sessionSuccessResponseData);
}

- (void)adjustSessionTrackingFailed:(ADJSessionFailure *)sessionFailureResponseData {
    NSLog(@"Session failure callback called!");
    NSLog(@"Session failure data: %@", sessionFailureResponseData);
}

- (BOOL)adjustDeeplinkResponse:(NSURL *)deeplink {
    NSLog(@"Deferred deep link callback called!");
    NSLog(@"Deferred deep link URL: %@", [deeplink absoluteString]);
    
    // Allow Adjust SDK to open received deferred deep link.
    // If you don't want it to open it, return NO; instead.
    return YES;
}

- (void)adjustSkanUpdatedWithConversionData:(NSDictionary<NSString *, NSString *> *)data {
    NSLog(@"Conversion value updated callback called!");
    NSLog(@"Conversion value dictionary: \n%@", data.description);
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Show ATT dialog.
    if (@available(iOS 14, *)) {
        [Adjust requestAppTrackingAuthorizationWithCompletionHandler:^(NSUInteger status) {
            // Process user's response.
        }];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
