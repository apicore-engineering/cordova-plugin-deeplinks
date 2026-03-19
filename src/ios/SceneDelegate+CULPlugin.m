//
// SceneDelegate+CULPlugin.m
//
// Created for cordova-ios@8 Scene API support
// Handles Universal Links via SceneDelegate instead of AppDelegate
//

#import "SceneDelegate+CULPlugin.h"
#import "CULPlugin.h"
#import <objc/runtime.h>
#import <Cordova/CDV.h>

/**
 * Plugin name in config.xml
 */
static NSString *const PLUGIN_NAME = @"UniversalLinks";

@implementation CDVSceneDelegate (CULPlugin)

/*
 In cordova-ios@8, the app uses Scene API, so user activities come through SceneDelegate
 instead of AppDelegate. We swizzle two SceneDelegate methods:
   1. scene:continueUserActivity:          - app already running (warm launch)
   2. scene:willConnectToSession:options:  - app cold-launched via deeplink
*/
+ (void)load {
    NSLog(@"[UniversalLinks] ===== LOADING UniversalLinks Category =====");

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        Class targetClass = [CDVSceneDelegate class];
        NSLog(@"[UniversalLinks] Using CDVSceneDelegate class: %@", targetClass);

        // ------------------------------------------------------------------
        // 1) Swizzle scene:continueUserActivity: (warm / already-running launch)
        // ------------------------------------------------------------------
        SEL originalSEL = @selector(scene:continueUserActivity:);
        SEL swizzledSEL = @selector(culPlugin_scene:continueUserActivity:);

        Method originalMethod = class_getInstanceMethod(targetClass, originalSEL);
        Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSEL);

        NSLog(@"[UniversalLinks] continueUserActivity - original: %@  swizzled: %@",
              originalMethod ? @"FOUND" : @"NOT FOUND",
              swizzledMethod ? @"FOUND" : @"NOT FOUND");

        if (swizzledMethod) {
            if (originalMethod) {
                method_exchangeImplementations(originalMethod, swizzledMethod);
                NSLog(@"[UniversalLinks] Swizzled scene:continueUserActivity: in CDVSceneDelegate");
            } else {
                IMP imp           = method_getImplementation(swizzledMethod);
                const char *types = method_getTypeEncoding(swizzledMethod);
                BOOL didAdd       = class_addMethod(targetClass, originalSEL, imp, types);
                NSLog(@"[UniversalLinks] Added scene:continueUserActivity: - %@",
                      didAdd ? @"SUCCESS" : @"FAILED");
            }
        } else {
            NSLog(@"[UniversalLinks] ERROR: culPlugin_scene:continueUserActivity: not found");
        }

        // ------------------------------------------------------------------
        // 2) Swizzle scene:willConnectToSession:options: (cold launch)
        // ------------------------------------------------------------------
        SEL originalConnectSEL = @selector(scene:willConnectToSession:options:);
        SEL swizzledConnectSEL = @selector(culPlugin_scene:willConnectToSession:options:);

        Method originalConnectMethod = class_getInstanceMethod(targetClass, originalConnectSEL);
        Method swizzledConnectMethod = class_getInstanceMethod(targetClass, swizzledConnectSEL);

        NSLog(@"[UniversalLinks] willConnectToSession - original: %@  swizzled: %@",
              originalConnectMethod ? @"FOUND" : @"NOT FOUND",
              swizzledConnectMethod ? @"FOUND" : @"NOT FOUND");

        if (swizzledConnectMethod) {
            if (originalConnectMethod) {
                method_exchangeImplementations(originalConnectMethod, swizzledConnectMethod);
                NSLog(@"[UniversalLinks] Swizzled scene:willConnectToSession:options: in CDVSceneDelegate");
            } else {
                IMP imp           = method_getImplementation(swizzledConnectMethod);
                const char *types = method_getTypeEncoding(swizzledConnectMethod);
                BOOL didAdd       = class_addMethod(targetClass, originalConnectSEL, imp, types);
                NSLog(@"[UniversalLinks] Added scene:willConnectToSession:options: - %@",
                      didAdd ? @"SUCCESS" : @"FAILED");
            }
        } else {
            NSLog(@"[UniversalLinks] ERROR: culPlugin_scene:willConnectToSession:options: not found");
        }

        NSLog(@"[UniversalLinks] ===== UniversalLinks Setup COMPLETE =====");
    });
}

// ----------------------------------------------------------------------------
// WARM LAUNCH: app was already running when the deeplink was triggered
// ----------------------------------------------------------------------------
- (void)culPlugin_scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    NSLog(@"[UniversalLinks] ===== UNIVERSAL LINK DETECTED (warm launch) =====");
    NSLog(@"[UniversalLinks] Activity Type: %@", userActivity.activityType);
    NSLog(@"[UniversalLinks] Webpage URL:   %@", userActivity.webpageURL);

    BOOL handled = NO;

    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] &&
        userActivity.webpageURL != nil) {

        NSLog(@"[UniversalLinks] This IS a Universal Link!");

        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            UIWindow *window           = windowScene.windows.firstObject;

            if (window && window.rootViewController) {
                UIViewController *rootVC = window.rootViewController;
                NSLog(@"[UniversalLinks] Root VC class: %@", NSStringFromClass([rootVC class]));

                if ([rootVC isKindOfClass:[CDVViewController class]]) {
                    CDVViewController *cordovaVC = (CDVViewController *)rootVC;
                    CULPlugin *plugin = [cordovaVC getCommandInstance:PLUGIN_NAME];

                    if (plugin != nil) {
                        NSLog(@"[UniversalLinks] Plugin instance found, handling...");
                        handled = [plugin handleUserActivity:userActivity];
                        NSLog(@"[UniversalLinks] Plugin handled: %@", handled ? @"YES" : @"NO");
                    } else {
                        NSLog(@"[UniversalLinks] Plugin instance not found");
                    }
                } else {
                    NSLog(@"[UniversalLinks] Root VC is not CDVViewController");
                }
            } else {
                NSLog(@"[UniversalLinks] No window or rootViewController found");
            }
        } else {
            NSLog(@"[UniversalLinks] Scene is not UIWindowScene: %@",
                  NSStringFromClass([scene class]));
        }

        if (handled) {
            NSLog(@"[UniversalLinks] ===== END (handled by UniversalLinks) =====");
            return;
        }
    } else {
        NSLog(@"[UniversalLinks] Not a Universal Link");
    }

    // Pass through to any other swizzled implementations (or the original).
    // Due to method swizzling this actually calls the original implementation.
    NSLog(@"[UniversalLinks] Passing to other handlers...");
    [self culPlugin_scene:scene continueUserActivity:userActivity];
    NSLog(@"[UniversalLinks] ===== END (passed to other handler) =====");
}

// ----------------------------------------------------------------------------
// COLD LAUNCH: app was not running; iOS launched it directly via the deeplink.
// connectionOptions.userActivities holds the incoming Universal Link.
// ----------------------------------------------------------------------------
- (void)culPlugin_scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    NSLog(@"[UniversalLinks] ===== COLD LAUNCH DEEPLINK CHECK =====");

    // Call the original (swizzled) implementation FIRST so Cordova can finish
    // its own scene setup before we try to reach into it.
    [self culPlugin_scene:scene willConnectToSession:session options:connectionOptions];

    // Look for a Universal Link in the connection options
    NSUserActivity *activity = nil;
    for (NSUserActivity *a in connectionOptions.userActivities) {
        if ([a.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && a.webpageURL) {
            activity = a;
            break;
        }
    }

    if (!activity) {
        NSLog(@"[UniversalLinks] No Universal Link in cold-launch options");
        return;
    }

    NSLog(@"[UniversalLinks] Cold-launch Universal Link found: %@", activity.webpageURL);

    if (![scene isKindOfClass:[UIWindowScene class]]) { return; }

    UIWindowScene *windowScene = (UIWindowScene *)scene;

    // Cordova's WebView may not be ready yet at this point, so we retry until
    // the plugin instance becomes available (up to ~3 seconds total).
    __block int attempts = 0;
    __block void (^tryHandle)(void);
    tryHandle = ^{
        attempts++;

        UIWindow *window         = windowScene.windows.firstObject;
        UIViewController *rootVC = window.rootViewController;

        if ([rootVC isKindOfClass:[CDVViewController class]]) {
            CDVViewController *cordovaVC = (CDVViewController *)rootVC;
            CULPlugin *plugin = [cordovaVC getCommandInstance:PLUGIN_NAME];

            if (plugin) {
                NSLog(@"[UniversalLinks] Cold-launch: handling after %d attempt(s)", attempts);
                [plugin handleUserActivity:activity];
                return;
            }
        }

        if (attempts < 10) {
            NSLog(@"[UniversalLinks] Cold-launch: plugin not ready yet, retrying... (%d/10)", attempts);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), tryHandle);
        } else {
            NSLog(@"[UniversalLinks] Cold-launch: gave up waiting for plugin after 10 attempts");
        }
    };

    tryHandle();

    NSLog(@"[UniversalLinks] ===== END COLD LAUNCH DEEPLINK CHECK =====");
}

@end