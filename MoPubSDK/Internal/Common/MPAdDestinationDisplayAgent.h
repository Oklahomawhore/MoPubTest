//
//  MPAdDestinationDisplayAgent.h
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import <Foundation/Foundation.h>
#import "MPActivityViewControllerHelper+TweetShare.h"
#import "MPAdConfiguration.h"
#import "MPURLResolver.h"
#import "MPProgressOverlayView.h"
#import "MOPUBDisplayAgentType.h"

@protocol MPAdDestinationDisplayAgentDelegate;

@protocol MPAdDestinationDisplayAgent

@property (nonatomic, weak) id<MPAdDestinationDisplayAgentDelegate> delegate;

+ (id<MPAdDestinationDisplayAgent>)agentWithDelegate:(id<MPAdDestinationDisplayAgentDelegate>)delegate;
+ (BOOL)shouldDisplayContentInApp;
/**
 Displays destination URL or clickthrough data in-app. When @c skAdNetworkData is present, the URL is
 fired and forgotten as a tracker. When @c skAdNetworkData is @c nil, the URL is the destination URL.
 
 @param URL destination clickthrough URL, or click tracker if @c skAdNetworkData is non-nil
 @param skAdNetworkData (nullable) the App Store destination metadata for an SKAdNetwork-enabled ad
 */
- (void)displayDestinationForURL:(NSURL *)URL skAdNetworkData:(MPSKAdNetworkData *)skAdNetworkData;
- (void)cancel;

@end

@interface MPAdDestinationDisplayAgent : NSObject <
    MPAdDestinationDisplayAgent,
    MPProgressOverlayViewDelegate,
    MPActivityViewControllerHelperDelegate
>

@end

@protocol MPAdDestinationDisplayAgentDelegate <NSObject>

- (UIViewController *)viewControllerForPresentingModalView;
- (void)displayAgentWillPresentModal;
- (void)displayAgentWillLeaveApplication;
- (void)displayAgentDidDismissModal;

@end
