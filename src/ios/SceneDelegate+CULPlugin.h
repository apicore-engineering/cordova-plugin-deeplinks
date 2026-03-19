//
// SceneDelegate+CULPlugin.h
//
// Created for cordova-ios@8 Scene API support
// Handles Universal Links via SceneDelegate instead of AppDelegate
//

#import <UIKit/UIKit.h>
#import <Cordova/CDVSceneDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface CDVSceneDelegate (CULPlugin)

// Warm launch: app was already running when the deeplink was triggered
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;

// Cold launch: app was started directly by tapping a deeplink
- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions;

@end

NS_ASSUME_NONNULL_END
