//
//  MPAdDestinationDisplayAgent.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import "MPAdDestinationDisplayAgent.h"
#import "MPCoreInstanceProvider.h"
#import "MPLastResortDelegate.h"
#import "MPLogging.h"
#import "NSURL+MPAdditions.h"
#import "MPCoreInstanceProvider.h"
#import "MPAnalyticsTracker.h"
#import "MOPUBExperimentProvider.h"
#import "MoPub+Utility.h"
#import "SKStoreProductViewController+MPAdditions.h"
#import <SafariServices/SafariServices.h>

// For non-module targets, UIKit must be explicitly imported
// since MoPubSDK-Swift.h will not import it.
#if __has_include(<MoPubSDK/MoPubSDK-Swift.h>)
    #import <UIKit/UIKit.h>
    #import <MoPubSDK/MoPubSDK-Swift.h>
#else
    #import <UIKit/UIKit.h>
    #import "UnityInterView-Swift.h"
#endif

static NSString * const kDisplayAgentErrorDomain = @"com.mopub.displayagent";

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MPAdDestinationDisplayAgent () <SFSafariViewControllerDelegate, SKStoreProductViewControllerDelegate>

@property (nonatomic, strong) MPURLResolver *resolver;
@property (nonatomic, strong) MPURLResolver *enhancedDeeplinkFallbackResolver;
@property (nonatomic, strong) MPProgressOverlayView *overlayView;
@property (nonatomic, assign) BOOL isLoadingDestination;
@property (nonatomic) MOPUBDisplayAgentType displayAgentType;
@property (nonatomic, strong) SKStoreProductViewController *storeKitController;
@property (nonatomic, strong) SFSafariViewController *safariController;
@property (nonatomic, strong) MPSKAdNetworkData *skAdNetworkData;
@property (nonatomic, strong) id<MPAnalyticsTracker> analyticsTracker;

@property (nonatomic, strong) MPActivityViewControllerHelper *activityViewControllerHelper;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MPAdDestinationDisplayAgent

@synthesize delegate;

+ (MPAdDestinationDisplayAgent *)agentWithDelegate:(id<MPAdDestinationDisplayAgentDelegate>)delegate
{
    MPAdDestinationDisplayAgent *agent = [[MPAdDestinationDisplayAgent alloc] init];
    agent.delegate = delegate;
    agent.overlayView = [[MPProgressOverlayView alloc] initWithDelegate:agent];
    agent.activityViewControllerHelper = [[MPActivityViewControllerHelper alloc] initWithDelegate:agent];
    agent.displayAgentType = MOPUBExperimentProvider.sharedInstance.displayAgentType;
    agent.analyticsTracker = [MPAnalyticsTracker sharedTracker];
    return agent;
}

- (void)dealloc
{
    [self dismissAllModalContent];

    self.overlayView.delegate = nil;

    // XXX: If this display agent is deallocated while a StoreKit controller is still on-screen,
    // nil-ing out the controller's delegate would leave us with no way to dismiss the controller
    // in the future. Therefore, we change the controller's delegate to a singleton object which
    // implements SKStoreProductViewControllerDelegate and is always around.
    self.storeKitController.delegate = [MPLastResortDelegate sharedDelegate];
}

- (void)dismissAllModalContent
{
    [self.overlayView hide];
}

+ (BOOL)shouldDisplayContentInApp
{
    switch (MOPUBExperimentProvider.sharedInstance.displayAgentType) {
        case MOPUBDisplayAgentTypeInApp:
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        case MOPUBDisplayAgentTypeSafariViewController:
#pragma clang diagnostic pop
            return YES;
        case MOPUBDisplayAgentTypeNativeSafari:
            return NO;
    }
}

- (void)displayDestinationForURL:(NSURL *)URL skAdNetworkData:(MPSKAdNetworkData *)skAdNetworkData
{
    if (self.isLoadingDestination) return;
    self.isLoadingDestination = YES;

    [self.delegate displayAgentWillPresentModal];
    [self.overlayView show];

    [self.resolver cancel];
    [self.enhancedDeeplinkFallbackResolver cancel];
    
    // Save SKAdNetwork data (or nil) for later
    self.skAdNetworkData = skAdNetworkData;
    
    // If SKAdNetwork data says to intercept all clicks, intercept here
    if (self.skAdNetworkData.clickMethod == MPSKAdNetworkDataClickMethodInterceptAllClicks) {
        // Fire destination URL as a click tracker
        [self.analyticsTracker sendTrackingRequestForURLs:@[URL]];
        
        // Display SKStoreProductViewController with SKAdNetwork click data
        [self presentStoreKitControllerWithProductParameters:self.skAdNetworkData.clickDataDictionary];
        return;
    }
    
    // For other clickthroughs, follow the URL and suggested action
    __weak __typeof__(self) weakSelf = self;
    self.resolver = [MPURLResolver resolverWithURL:URL completion:^(MPURLActionInfo *suggestedAction, NSError *error) {
        __typeof__(self) strongSelf = weakSelf;
        if (error) {
            [strongSelf failedToResolveURLWithError:error];
        } else {
            [strongSelf handleSuggestedURLAction:suggestedAction isResolvingEnhancedDeeplink:NO];
        }
    }];

    [self.resolver start];
}

- (void)cancel
{
    if (self.isLoadingDestination) {
        [self.resolver cancel];
        [self.enhancedDeeplinkFallbackResolver cancel];
        [self hideOverlay];
        [self completeDestinationLoading];
    }
}

- (BOOL)handleSuggestedURLAction:(MPURLActionInfo *)actionInfo isResolvingEnhancedDeeplink:(BOOL)isResolvingEnhancedDeeplink
{
    if (actionInfo == nil) {
        [self failedToResolveURLWithError:[NSError errorWithDomain:kDisplayAgentErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL action"}]];
        return NO;
    }

    BOOL success = YES;

    switch (actionInfo.actionType) {
        case MPURLActionTypeStoreKit:
            [self showStoreKitWithAction:actionInfo];
            break;
        case MPURLActionTypeGenericDeeplink:
            [self openURLInApplication:actionInfo.deeplinkURL];
            break;
        case MPURLActionTypeEnhancedDeeplink:
            if (isResolvingEnhancedDeeplink) {
                // We end up here if we encounter a nested enhanced deeplink. We'll simply disallow
                // this to avoid getting into cycles.
                [self failedToResolveURLWithError:[NSError errorWithDomain:kDisplayAgentErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Cannot resolve an enhanced deeplink that is nested within another enhanced deeplink."}]];
                success = NO;
            } else {
                [self handleEnhancedDeeplinkRequest:actionInfo.enhancedDeeplinkRequest];
            }
            break;
        case MPURLActionTypeOpenInSafari:
            [self openURLInApplication:actionInfo.safariDestinationURL];
            break;
        case MPURLActionTypeOpenInWebView:
            [self showWebViewWithHTMLString:actionInfo.HTTPResponseString baseURL:actionInfo.webViewBaseURL actionType:MPURLActionTypeOpenInWebView];
            break;
        case MPURLActionTypeOpenURLInWebView:
            [self showWebViewWithHTMLString:actionInfo.HTTPResponseString baseURL:actionInfo.originalURL actionType:MPURLActionTypeOpenInWebView];
            break;
        case MPURLActionTypeShare:
            [self openShareURL:actionInfo.shareURL];
            break;
        default:
            [self failedToResolveURLWithError:[NSError errorWithDomain:kDisplayAgentErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Unrecognized URL action type."}]];
            success = NO;
            break;
    }

    return success;
}

- (void)handleEnhancedDeeplinkRequest:(MPEnhancedDeeplinkRequest *)request
{
    [MoPub openURL:request.primaryURL options:@{} completion:^(BOOL didOpenURLSuccessfully) {
        if (didOpenURLSuccessfully) {
            [self hideOverlay];
            [self.delegate displayAgentWillLeaveApplication];
            [self completeDestinationLoading];
            [[MPAnalyticsTracker sharedTracker] sendTrackingRequestForURLs:request.primaryTrackingURLs];
        } else if (request.fallbackURL) {
            [self handleEnhancedDeeplinkFallbackForRequest:request];
        } else {
            [self openURLInApplication:request.originalURL];
        }
    }];
}

- (void)handleEnhancedDeeplinkFallbackForRequest:(MPEnhancedDeeplinkRequest *)request
{
    __weak __typeof__(self) weakSelf = self;
    [self.enhancedDeeplinkFallbackResolver cancel];
    self.enhancedDeeplinkFallbackResolver = [MPURLResolver resolverWithURL:request.fallbackURL completion:^(MPURLActionInfo *actionInfo, NSError *error) {
        __typeof__(self) strongSelf = weakSelf;
        if (error) {
            // If the resolver fails, just treat the entire original URL as a regular deeplink.
            [strongSelf openURLInApplication:request.originalURL];
        }
        else {
            // Otherwise, the resolver will return us a URL action. We process that action
            // normally with one exception: we don't follow any nested enhanced deeplinks.
            BOOL success = [strongSelf handleSuggestedURLAction:actionInfo isResolvingEnhancedDeeplink:YES];
            if (success) {
                [[MPAnalyticsTracker sharedTracker] sendTrackingRequestForURLs:request.fallbackTrackingURLs];
            }
        }
    }];
    [self.enhancedDeeplinkFallbackResolver start];
}

- (void)showWebViewWithHTMLString:(NSString *)HTMLString baseURL:(NSURL *)URL actionType:(MPURLActionType)actionType {
    switch (self.displayAgentType) {
        case MOPUBDisplayAgentTypeInApp:
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        case MOPUBDisplayAgentTypeSafariViewController:
#pragma clang diagnostic pop
            self.safariController = ({
                SFSafariViewController * controller = [[SFSafariViewController alloc] initWithURL:URL];
                controller.delegate = self;
                controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
                controller.modalPresentationStyle = UIModalPresentationFullScreen;
                controller;
            });
            
            [self showAdBrowserController];
            break;
        case MOPUBDisplayAgentTypeNativeSafari:
            [self openURLInApplication:URL];
            break;
    }
}

- (void)showAdBrowserController {
    // Fire click display tracker
    [MPClickDisplayTracker trackClickDisplayWithSkAdNetworkData:self.skAdNetworkData displayType:MPClickDisplayTrackerDisplayTypeSafariViewController];
    
    // Display Safari View Controller
    [self hideOverlay];
    [[self.delegate viewControllerForPresentingModalView] presentViewController:self.safariController
                                                                       animated:MP_ANIMATED
                                                                     completion:nil];
}

- (void)showStoreKitProductWithParameters:(NSDictionary *)parameters fallbackURL:(NSURL *)URL
{
    if (!SKStoreProductViewController.canUseStoreProductViewController) {
        [self openURLInApplication:URL];
        return;
    }
    
    NSDictionary *productParameters = parameters;
    
    // If SKAdNetwork data indicates to intercept App Store clicks, intercept here.
    if (self.skAdNetworkData.clickMethod == MPSKAdNetworkDataClickMethodInterceptAppStoreClicks) {
        // Use clickthrough data from the SKAdNetwork data if available.
        productParameters = self.skAdNetworkData != nil ? self.skAdNetworkData.clickDataDictionary : parameters;
    }
    
    [self presentStoreKitControllerWithProductParameters:productParameters];
}

- (void)openURLInApplication:(NSURL *)URL
{
    // Fire click display tracker
    [MPClickDisplayTracker trackClickDisplayWithSkAdNetworkData:self.skAdNetworkData displayType:MPClickDisplayTrackerDisplayTypeNativeSafari];
    
    // Display URL natively
    [self hideOverlay];

    [MoPub openURL:URL options:@{} completion:^(BOOL didOpenURLSuccessfully) {
        if (didOpenURLSuccessfully) {
            [self.delegate displayAgentWillLeaveApplication];
        }
        [self completeDestinationLoading];
    }];
}

- (BOOL)openShareURL:(NSURL *)URL
{
    MPLogDebug(@"MPAdDestinationDisplayAgent - loading Share URL: %@", URL);
    MPMoPubShareHostCommand command = [URL mp_MoPubShareHostCommand];
    switch (command) {
        case MPMoPubShareHostCommandTweet:
            return [self.activityViewControllerHelper presentActivityViewControllerWithTweetShareURL:URL];
        default:
            MPLogInfo(@"MPAdDestinationDisplayAgent - unsupported Share URL: %@", [URL absoluteString]);
            return NO;
    }
}

- (void)failedToResolveURLWithError:(NSError *)error
{
    // Fire click display tracker
    [MPClickDisplayTracker trackClickDisplayWithSkAdNetworkData:self.skAdNetworkData displayType:MPClickDisplayTrackerDisplayTypeError];
    
    // Finish failing resolution
    [self hideOverlay];
    [self completeDestinationLoading];
}

- (void)completeDestinationLoading
{
    self.isLoadingDestination = NO;
    [self.delegate displayAgentDidDismissModal];
}

- (void)presentStoreKitControllerWithProductParameters:(NSDictionary *)parameters
{
    // Fire click display tracker
    [MPClickDisplayTracker trackClickDisplayWithSkAdNetworkData:self.skAdNetworkData displayType:MPClickDisplayTrackerDisplayTypeStoreProductViewController];
    
    // Display store product
    self.storeKitController = [[SKStoreProductViewController alloc] init];
    self.storeKitController.modalPresentationStyle = UIModalPresentationFullScreen;
    self.storeKitController.delegate = self;
    [self.storeKitController loadProductWithParameters:parameters completionBlock:nil];
    
    [self hideOverlay];
    [[self.delegate viewControllerForPresentingModalView] presentViewController:self.storeKitController animated:MP_ANIMATED completion:nil];
}

#pragma mark - <SKStoreProductViewControllerDelegate>

// Called when the user dismisses the store screen.
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    self.isLoadingDestination = NO;
    
    // In iOS 13.0 and later, SKStoreProductViewController is automatically dismissed when the
    // user clicks "Cancel", so we do not need to manually dismiss it.
    // However, in iOS 13.0 and 13.1, there's a bug in @c SKStoreProductViewController that
    // leaves around an invisible view controller giving the appearance of a softlock upon
    // dismissal. Given that, for iOS 13.0 and 13.1, *a* view controller must be dismissed
    // before the ad can be interacted with.
    // Therefore, for iOS 13.2 and later, when this method is called, assume the
    // @c SKStoreProductViewController has been dismissed. For iOS 13.1 and earlier, manually
    // dismiss it.
    if (@available(iOS 13.2, *)) {
        [self.delegate displayAgentDidDismissModal];
    }
    // Manually dismiss the presented view controller on iOS 13.1 and earlier.
    else {
        [self hideModalAndNotifyDelegate];
    }
    
    // *Note* Failure to dispose of @c storeKitController immediately after its use has been
    // known to cause an issue in iOS 13+ where videos played via MoVideo fail to unpause.
    // Disposing here fixes that issue.
    self.storeKitController = nil;
}

#pragma mark - <SFSafariViewControllerDelegate>

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    self.isLoadingDestination = NO;
    [self.delegate displayAgentDidDismissModal];
}

#pragma mark - <MPProgressOverlayViewDelegate>

- (void)overlayCancelButtonPressed
{
    [self cancel];
}

#pragma mark - Convenience Methods

- (void)hideModalAndNotifyDelegate
{
    [[self.delegate viewControllerForPresentingModalView] dismissViewControllerAnimated:MP_ANIMATED completion:^{
        [self.delegate displayAgentDidDismissModal];
    }];
}

- (void)hideOverlay
{
    [self.overlayView hide];
}

#pragma mark <MPActivityViewControllerHelperDelegate>

- (UIViewController *)viewControllerForPresentingActivityViewController
{
    return self.delegate.viewControllerForPresentingModalView;
}

- (void)activityViewControllerWillPresent
{
    [self hideOverlay];
    self.isLoadingDestination = NO;
    [self.delegate displayAgentWillPresentModal];
}

- (void)activityViewControllerDidDismiss
{
    [self.delegate displayAgentDidDismissModal];
}

- (void)showStoreKitWithAction:(MPURLActionInfo *)actionInfo
{
    // When opening an App Store (or other store kit) link, @c SKStoreProductViewController
    // should be used regardless of the @c displayAgentType.
    // This ensures that SKAdNetwork clicks are attributed correctly even if
    // @c MOPUBDisplayAgentTypeNativeSafari is set.
    [self showStoreKitProductWithParameters:actionInfo.iTunesStoreParameters
                                fallbackURL:actionInfo.iTunesStoreFallbackURL];
}

@end
