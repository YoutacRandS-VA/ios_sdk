//
//  AppDelegate.m
//  AdjustExample-ObjC
//
//  Created by Aditi Agrawal on 13/07/22.
//

#import "AppDelegate.h"

#import <Adjust/ADJAdjust.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    ADJAdjustConfig *_Nonnull adjustConfig =
    [[ADJAdjustConfig alloc] initWithAppToken:@"abc"
                                  environment:ADJEnvironmentSandbox];
    
    [ADJAdjust sdkInitWithAdjustConfig:adjustConfig];
    
    return YES;
}

@end
