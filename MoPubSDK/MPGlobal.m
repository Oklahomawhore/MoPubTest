//
//  MPGlobal.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import "MPGlobal.h"
#import "MPConstants.h"
#import "MPLogging.h"
#import "NSURL+MPAdditions.h"
#import "MoPub.h"
#import "NSBundle+MPAdditions.h"
#import <CommonCrypto/CommonDigest.h>

#import <sys/types.h>
#import <sys/sysctl.h>

BOOL MPViewHasHiddenAncestor(UIView *view);
UIWindow *MPViewGetParentWindow(UIView *view);
BOOL MPViewIntersectsParentWindow(UIView *view);
NSString *MPSHA1Digest(NSString *string);

UIInterfaceOrientation MPInterfaceOrientation()
{
    return [UIApplication sharedApplication].statusBarOrientation;
}

UIWindow *MPKeyWindow()
{
    return [UIApplication sharedApplication].keyWindow;
}

CGFloat MPStatusBarHeight() {
    if ([UIApplication sharedApplication].statusBarHidden) return 0.0f;

    CGFloat width = CGRectGetWidth([UIApplication sharedApplication].statusBarFrame);
    CGFloat height = CGRectGetHeight([UIApplication sharedApplication].statusBarFrame);

    return (width < height) ? width : height;
}

CGRect MPApplicationFrame(BOOL includeSafeAreaInsets)
{
    // Starting with iOS8, the orientation of the device is taken into account when
    // requesting the key window's bounds. We are making the assumption that the
    // key window is equivalent to the application frame.
    CGRect frame = [UIApplication sharedApplication].keyWindow.frame;

    if (@available(iOS 11, *)) {
        if (includeSafeAreaInsets) {
            // Safe area insets include the status bar offset.
            UIEdgeInsets safeInsets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
            frame.origin.x = safeInsets.left;
            frame.size.width -= (safeInsets.left + safeInsets.right);
            frame.origin.y = safeInsets.top;
            frame.size.height -= (safeInsets.top + safeInsets.bottom);
            
            return frame;
        }
    }
   
    frame.origin.y += MPStatusBarHeight();
    frame.size.height -= MPStatusBarHeight();

    return frame;
}

CGRect MPScreenBounds()
{
    // Starting with iOS8, the orientation of the device is taken into account when
    // requesting the key window's bounds.
    return [UIScreen mainScreen].bounds;
}

CGSize MPScreenResolution()
{
    CGRect bounds = MPScreenBounds();
    CGFloat scale = MPDeviceScaleFactor();

    return CGSizeMake(bounds.size.width*scale, bounds.size.height*scale);
}

CGFloat MPDeviceScaleFactor()
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
        [[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        return [[UIScreen mainScreen] scale];
    } else {
        return 1.0;
    }
}

NSDictionary *MPDictionaryFromQueryString(NSString *query) {
    NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
    NSArray *queryElements = [query componentsSeparatedByString:@"&"];
    for (NSString *element in queryElements) {
        NSArray *keyVal = [element componentsSeparatedByString:@"="];
        NSString *key = [keyVal objectAtIndex:0];
        NSString *value = [keyVal lastObject];
        [queryDict setObject:[value stringByRemovingPercentEncoding] forKey:key];
    }
    return queryDict;
}

NSString *MPSHA1Digest(NSString *string)
{
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
    CC_SHA1([data bytes], (CC_LONG)[data length], digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

NSString *MPResourcePathForResource(NSString *resourceName)
{
    NSBundle *resourceBundle = NSBundle.mopubResourceBundle;
    NSString *resourcePath = [resourceBundle pathForResource:resourceName ofType:nil];
    return resourcePath;
}

NSArray *MPConvertStringArrayToURLArray(NSArray *strArray)
{
    NSMutableArray *urls = [NSMutableArray array];

    for (NSObject *str in strArray) {
        if ([str isKindOfClass:[NSString class]]) {
            NSURL *url = [NSURL URLWithString:(NSString *)str];
            if (url) {
                [urls addObject:url];
            }
        }
    }

    return urls;
}

UIInterfaceOrientationMask MPInterstitialOrientationTypeToUIInterfaceOrientationMask(MPInterstitialOrientationType type)
{
    switch (type) {
        case MPInterstitialOrientationTypePortrait: return UIInterfaceOrientationMaskPortrait;
        case MPInterstitialOrientationTypeLandscape: return UIInterfaceOrientationMaskLandscape;
        default: return UIInterfaceOrientationMaskAll;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UIDevice (MPAdditions)

- (NSString *)mp_hardwareDeviceName
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return platform;
}

@end

@implementation UIApplication (MPAdditions)

- (BOOL)mp_supportsOrientationMask:(UIInterfaceOrientationMask)orientationMask
{
    NSArray *supportedOrientations = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations"];

    if (orientationMask & UIInterfaceOrientationMaskLandscapeLeft) {
        if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"]) {
            return YES;
        }
    }

    if (orientationMask & UIInterfaceOrientationMaskLandscapeRight) {
        if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"]) {
            return YES;
        }
    }

    if (orientationMask & UIInterfaceOrientationMaskPortrait) {
        if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"]) {
            return YES;
        }
    }

    if (orientationMask & UIInterfaceOrientationMaskPortraitUpsideDown) {
        if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortraitUpsideDown"]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)mp_doesOrientation:(UIInterfaceOrientation)orientation matchOrientationMask:(UIInterfaceOrientationMask)orientationMask
{
    BOOL supportsLandscapeLeft = (orientationMask & UIInterfaceOrientationMaskLandscapeLeft) > 0;
    BOOL supportsLandscapeRight = (orientationMask & UIInterfaceOrientationMaskLandscapeRight) > 0;
    BOOL supportsPortrait = (orientationMask & UIInterfaceOrientationMaskPortrait) > 0;
    BOOL supportsPortraitUpsideDown = (orientationMask & UIInterfaceOrientationMaskPortraitUpsideDown) > 0;

    if (supportsLandscapeLeft && orientation == UIInterfaceOrientationLandscapeLeft) {
        return YES;
    }

    if (supportsLandscapeRight && orientation == UIInterfaceOrientationLandscapeRight) {
        return YES;
    }

    if (supportsPortrait && orientation == UIInterfaceOrientationPortrait) {
        return YES;
    }

    if (supportsPortraitUpsideDown && orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return YES;
    }
    
    return NO;
}

@end
