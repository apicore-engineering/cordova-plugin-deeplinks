//
//  SceneDelegate+CULPlugin.m
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Cordova/CDVSceneDelegate.h>
#import "CULPlugin.h"

@interface CDVSceneDelegate (CULPlugin)
- (void)cul_scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
          options:(UISceneConnectionOptions *)connectionOptions;
@end

@implementation CDVSceneDelegate (CULPlugin)

/**
 * cordova-ios 8's -scene:willConnectToSession:options: forwards only
 * connectionOptions.URLContexts and never reads connectionOptions.userActivities,
 * so a universal link that cold-starts the app is dropped before any plugin can
 * see it. Swizzling rather than overriding from this category keeps the upstream
 * URL forwarding — and whatever a later cordova-ios adds to that method — intact.
 */
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(self, @selector(scene:willConnectToSession:options:));
        Method replacement = class_getInstanceMethod(self, @selector(cul_scene:willConnectToSession:options:));
        if (original && replacement) {
            method_exchangeImplementations(original, replacement);
        }
    });
}

- (void)cul_scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    [self cul_scene:scene willConnectToSession:session options:connectionOptions];

    for (NSUserActivity *userActivity in connectionOptions.userActivities) {
        [CULPlugin handleUserActivityFromScene:userActivity];
    }
}

@end
