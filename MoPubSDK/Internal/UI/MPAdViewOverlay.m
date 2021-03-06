//
//  MPAdViewOverlay.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import "MPAdViewOverlay.h"
#import "MPCountdownTimerView.h"
#import "MPGlobal.h"
#import "MPLogging.h"
#import "MPVASTConstant.h"
#import "MPVideoPlayer.h"
#import "MPViewableButton.h"
#import "UIButton+MPAdditions.h"
#import "UIImage+MPAdditions.h"
#import "UIView+MPAdditions.h"

// For non-module targets, UIKit must be explicitly imported
// since MoPubSDK-Swift.h will not import it.
#if __has_include(<MoPubSDK/MoPubSDK-Swift.h>)
    #import <UIKit/UIKit.h>
    #import <MoPubSDK/MoPubSDK-Swift.h>
#else
    #import <UIKit/UIKit.h>
    #import "UnityInterView-Swift.h"
#endif

static CGFloat const kRectangleButtonPadding = 16;
static CGFloat const kSkipButtonDimension = 50; // 50x50, same size as the Close button

@interface MPAdViewOverlay () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) MPVideoPlayerViewOverlayConfig *config;
@property (nonatomic, assign) MPAdViewCloseButtonLocation closeButtonLocation; // setter has UI side effect
@property (nonatomic, assign) MPAdViewCloseButtonType closeButtonType; // setter has UI side effect
@property (nonatomic, assign) BOOL allowPassthroughForTouches; // if NO, touches won't reach the content view underneath
@property (nonatomic, strong) MPResumableTimer *clickThroughEnablingTimer;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

// UI elements that are considered friendly Viewability obstructions.
// All of the views must conform to `MPViewabilityObstruction`.
@property (nonatomic, strong) MPViewableButton *callToActionButton; // located at the bottom-right corner
@property (nonatomic, strong) MPViewableButton *closeButton; // located at the top-right corner by default, created during `init`
@property (nonatomic, strong) MPViewableButton *skipButton; // located at the top-right corner
@property (nonatomic, strong) MPVASTIndustryIconView *iconView; // located at the top-left corner
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *closeButtonConstraints;
@property (nonatomic, strong) NSLayoutConstraint *iconViewWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconViewHeightConstraint;
@property (nonatomic, strong) MPCountdownTimerView *timerView; // located at the top-right corner
@property (nonatomic, assign) BOOL hasCountdownTimerCompleted;
@property (nonatomic, assign) BOOL videoCompleted;

@end

#pragma mark -

@interface MPAdViewOverlay (MPVASTIndustryIconViewDelegate) <MPVASTIndustryIconViewDelegate>
@end

#pragma mark -

@implementation MPAdViewOverlay

- (void)dealloc {
    [self.notificationCenter removeObserver:self];
    [self.timerView stopAndSignalCompletion:NO];
    [self.clickThroughEnablingTimer invalidate];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _allowPassthroughForTouches = YES;
        
        _closeButton = [MPViewableButton buttonWithType:UIButtonTypeCustom
                                        obstructionType:MPViewabilityObstructionTypeClose
                                        obstructionName:MPViewabilityObstructionNameCloseButton];
        _closeButton.backgroundColor = [UIColor clearColor];
        _closeButton.accessibilityLabel = @"Close ad";
        _closeButton.translatesAutoresizingMaskIntoConstraints = NO; // use Autolayout
        [_closeButton addTarget:self action:@selector(didHitCloseButton:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_closeButton];
        [self setCloseButtonLocation:MPAdViewCloseButtonLocationTopRight];
        [self setCloseButtonType:MPAdViewCloseButtonTypeImageButton];
    }
    return self;
}

+ (CGRect)closeButtonFrameForAdSize:(CGSize)adSize atLocation:(MPAdViewCloseButtonLocation)location {
    CGRect closeButtonFrame = CGRectMake(0, 0, kMPAdViewCloseButtonSize.width, kMPAdViewCloseButtonSize.height);
    
    switch (location) {
        case MPAdViewCloseButtonLocationBottomCenter:
            closeButtonFrame.origin = CGPointMake((adSize.width - kMPAdViewCloseButtonSize.width) / 2,
                                                  adSize.height - kMPAdViewCloseButtonSize.height);
            break;
        case MPAdViewCloseButtonLocationBottomLeft:
            closeButtonFrame.origin = CGPointMake(0, adSize.height - kMPAdViewCloseButtonSize.height);
            break;
        case MPAdViewCloseButtonLocationBottomRight:
            closeButtonFrame.origin = CGPointMake(adSize.width - kMPAdViewCloseButtonSize.width,
                                                  adSize.height - kMPAdViewCloseButtonSize.height);
            break;
        case MPAdViewCloseButtonLocationCenter:
            closeButtonFrame.origin = CGPointMake((adSize.width - kMPAdViewCloseButtonSize.width) / 2,
                                                  (adSize.height - kMPAdViewCloseButtonSize.height) / 2);
            break;
        case MPAdViewCloseButtonLocationTopCenter:
            closeButtonFrame.origin = CGPointMake((adSize.width - kMPAdViewCloseButtonSize.width) / 2, 0);
            break;
        case MPAdViewCloseButtonLocationTopLeft:
            closeButtonFrame.origin = CGPointZero;
            break;
        case MPAdViewCloseButtonLocationTopRight:
            closeButtonFrame.origin = CGPointMake(adSize.width - kMPAdViewCloseButtonSize.width, 0);
            break;
    }
    
    return closeButtonFrame;
}

- (void)setCloseButtonLocation:(MPAdViewCloseButtonLocation)closeButtonLocation {
    _closeButtonLocation = closeButtonLocation;
    
    if (self.closeButtonConstraints.count == 0) {
        self.closeButtonConstraints = @[
            [self.closeButton.mp_safeWidthAnchor constraintEqualToConstant:kMPAdViewCloseButtonSize.width],
            [self.closeButton.mp_safeHeightAnchor constraintEqualToConstant:kMPAdViewCloseButtonSize.height],
            [self.closeButton.mp_safeTopAnchor constraintEqualToAnchor:self.mp_safeTopAnchor],
            [self.closeButton.mp_safeLeadingAnchor constraintEqualToAnchor:self.mp_safeLeadingAnchor],
            [self.closeButton.mp_safeBottomAnchor constraintEqualToAnchor:self.mp_safeBottomAnchor],
            [self.closeButton.mp_safeTrailingAnchor constraintEqualToAnchor:self.mp_safeTrailingAnchor],
            [self.closeButton.mp_safeCenterXAnchor constraintEqualToAnchor:self.mp_safeCenterXAnchor],
            [self.closeButton.mp_safeCenterYAnchor constraintEqualToAnchor:self.mp_safeCenterYAnchor]
        ];
    }
    else {
        [NSLayoutConstraint deactivateConstraints:self.closeButtonConstraints];
    }
    
    NSMutableArray<NSLayoutConstraint *> *constraintsToActivate = [NSMutableArray arrayWithArray:@[
        [self.closeButton.mp_safeWidthAnchor constraintEqualToConstant:kMPAdViewCloseButtonSize.width],
        [self.closeButton.mp_safeHeightAnchor constraintEqualToConstant:kMPAdViewCloseButtonSize.height]
    ]];
    switch (closeButtonLocation) {
        case MPAdViewCloseButtonLocationBottomCenter:
            [constraintsToActivate addObject:[self.closeButton.mp_safeCenterXAnchor constraintEqualToAnchor:self.mp_safeCenterXAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeBottomAnchor constraintEqualToAnchor:self.mp_safeBottomAnchor]];
            break;
        case MPAdViewCloseButtonLocationBottomLeft:
            [constraintsToActivate addObject:[self.closeButton.mp_safeLeadingAnchor constraintEqualToAnchor:self.mp_safeLeadingAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeBottomAnchor constraintEqualToAnchor:self.mp_safeBottomAnchor]];
            break;
        case MPAdViewCloseButtonLocationBottomRight:
            [constraintsToActivate addObject:[self.closeButton.mp_safeTrailingAnchor constraintEqualToAnchor:self.mp_safeTrailingAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeBottomAnchor constraintEqualToAnchor:self.mp_safeBottomAnchor]];
            break;
        case MPAdViewCloseButtonLocationCenter:
            [constraintsToActivate addObject:[self.closeButton.mp_safeCenterXAnchor constraintEqualToAnchor:self.mp_safeCenterXAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeCenterYAnchor constraintEqualToAnchor:self.mp_safeCenterYAnchor]];
            break;
        case MPAdViewCloseButtonLocationTopCenter:
            [constraintsToActivate addObject:[self.closeButton.mp_safeCenterXAnchor constraintEqualToAnchor:self.mp_safeCenterXAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeTopAnchor constraintEqualToAnchor:self.mp_safeTopAnchor]];
            break;
        case MPAdViewCloseButtonLocationTopLeft:
            [constraintsToActivate addObject:[self.closeButton.mp_safeLeadingAnchor constraintEqualToAnchor:self.mp_safeLeadingAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeTopAnchor constraintEqualToAnchor:self.mp_safeTopAnchor]];
            break;
        case MPAdViewCloseButtonLocationTopRight:
            [constraintsToActivate addObject:[self.closeButton.mp_safeTrailingAnchor constraintEqualToAnchor:self.mp_safeTrailingAnchor]];
            [constraintsToActivate addObject:[self.closeButton.mp_safeTopAnchor constraintEqualToAnchor:self.mp_safeTopAnchor]];
            break;
    }
    [NSLayoutConstraint activateConstraints:constraintsToActivate];
    
    [self setNeedsLayout];
}

- (void)setCloseButtonType:(MPAdViewCloseButtonType)closeButtonType {
    _closeButtonType = closeButtonType;
    
    switch (closeButtonType) {
        case MPAdViewCloseButtonTypeNone:
            self.closeButton.hidden = YES;
            break;
        case MPAdViewCloseButtonTypeInvisibleButton:
             // the close button hit box is still effective even without the button images
            self.closeButton.hidden = NO;
            [self.closeButton setImage:nil forState:UIControlStateNormal];
            break;
        case MPAdViewCloseButtonTypeImageButton:
            self.skipButton.hidden = YES; // avoid overlapping
            self.timerView.hidden = YES; // avoid overlapping
            self.closeButton.hidden = NO;
            [self.closeButton setImage:[UIImage imageForAsset:kMPImageAssetCloseButton] forState:UIControlStateNormal];
            break;
    }
}

#pragma mark - UIView Override

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    _wasTapped = YES;
    
    /*
     When the video is playing, this overlay intercepts all touch events. After the video is
     finished, we might need to pass through the touch events to the companion ad underneath,
     unless the touch events happen upon the overlay subviews, such as the Close button.
     */
    if (self.allowPassthroughForTouches) {
        for (UIView *subview in self.subviews) {
            if (subview.isHidden == NO
                && subview.alpha > 0
                && subview.userInteractionEnabled
                && [subview pointInside:[self convertPoint:point toView:subview] withEvent:event]) {
                return YES; // let the subview handle the event
            }
        }
        return NO; // no subview can handle it, pass through
    } else {
        return YES; // let this overlay handle the event (with a tap gesture recognizer)
    }
}

#pragma mark - Private: Timer View

/**
 Show the timer view for a given skip offset. If the skip offset is less the video duration, the
 Skip button is shown after the timer reaches 0. If the skip offset is no less than the video duration,
 the Close button is shown after the timer reaches 0.
 */
- (void)showTimerViewForSkipOffset:(NSTimeInterval)skipOffset totalDuration:(NSTimeInterval)totalDuration {
    if (self.timerView) {
        return;
    }
    
    self.hasCountdownTimerCompleted = NO;
    
    __weak __typeof__(self) weakSelf = self;
    MPCountdownTimerView *timerView = [[MPCountdownTimerView alloc] initWithDuration:skipOffset timerCompletion:^(BOOL hasElapsed) {
        weakSelf.hasCountdownTimerCompleted = YES;
        
        // Only show the skip button if a video is still playing and
        // it has a companion ad.
        if (skipOffset < totalDuration && weakSelf.config.hasCompanionAd) {
            [weakSelf showSkipButton];
        } else {
            [weakSelf showCloseButton];
        }
        [weakSelf.timerView removeFromSuperview];
        [weakSelf.delegate videoPlayerViewOverlayDidFinishCountdown:weakSelf];
        
        // If the ad is a rewarded ad, show CTA when reward duration completes
        if (weakSelf.config.isRewardExpected) {
            [weakSelf showCallToActionButton];
        }
    }];
    
    // With user interaction disabled, when the user touches the timer,
    // the tap gesture recognizer's touch.view comes back as the overlay
    // and not the timer. This is fixed by enabling user interaction on the timer.
    [timerView setUserInteractionEnabled:YES];
    self.timerView = timerView;
    
    [self addSubview:timerView];
    timerView.translatesAutoresizingMaskIntoConstraints = NO;
    [[timerView.topAnchor constraintEqualToAnchor:self.mp_safeTopAnchor] setActive:YES];
    [[timerView.trailingAnchor constraintEqualToAnchor:self.mp_safeTrailingAnchor] setActive:YES];
    
    // Add notifications to pause the timer if needed
    [self.notificationCenter addObserver:self
                                selector:@selector(pauseTimer)
                                    name:UIApplicationDidEnterBackgroundNotification
                                  object:nil];
    [self.notificationCenter addObserver:self
                                selector:@selector(resumeTimer)
                                    name:UIApplicationWillEnterForegroundNotification
                                  object:nil];
    
    [timerView start];
}

#pragma mark - Private: click-through (Call To Action / Learn More button)

- (void)setUpClickthroughForOffset:(NSTimeInterval)skipOffset videoDuration:(NSTimeInterval)videoDuration {
    if (self.config.isClickthroughAllowed == NO) {
        return;
    }
    
    // See click-through timing definition at https://developers.mopub.com/dsps/ad-formats/video/
    __typeof__(self) __weak weakSelf = self;
    self.clickThroughEnablingTimer = [[MPResumableTimer alloc] initWithInterval:MIN(skipOffset, videoDuration)
                                                                        repeats:NO
                                                                    runLoopMode:NSDefaultRunLoopMode
                                                                        closure:^(MPResumableTimer * _Nonnull timer) {
        __typeof__(self) strongSelf = weakSelf;
        [strongSelf enableClickthrough];
    }];
    [self.clickThroughEnablingTimer scheduleNow];
}

- (void)enableClickthrough {
    if (self.config.isClickthroughAllowed == NO) {
        return;
    }
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleClickThrough)];
    tapGestureRecognizer.delegate = self;
    [self addGestureRecognizer:tapGestureRecognizer];
    
    // If the ad is not a rewarded ad, show the CTA immediately when the clickthrough is enabled
    if (!self.config.isRewardExpected) {
        [self showCallToActionButton];
    }
}

- (void)showCallToActionButton {
    // If this ad has a companion, and the video has already completed (i.e., the companion ad is already on-screen),
    // do not show the call-to-action button.
    if (self.config.hasCompanionAd && self.videoCompleted) {
        return;
    }
    
    if (self.config.isClickthroughAllowed == NO || self.config.callToActionButtonTitle.length == 0) {
        return;
    }
    
    if (self.callToActionButton) {
        [self.callToActionButton setHidden:NO];
        return;
    }
    
    MPViewableButton *button = [MPViewableButton buttonWithType:UIButtonTypeCustom
                                                obstructionType:MPViewabilityObstructionTypeOther
                                                obstructionName:MPViewabilityObstructionNameCallToActionButton];
    self.callToActionButton = button;
    button.accessibilityLabel = @"Call To Action Button";
    [button addTarget:self action:@selector(handleClickThrough) forControlEvents:UIControlEventTouchUpInside];
    [button applyMPVideoPlayerBorderedStyleWithTitle:self.config.callToActionButtonTitle];
    
    [self addSubview:button];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [[button.bottomAnchor constraintEqualToAnchor:self.mp_safeBottomAnchor constant:-kRectangleButtonPadding] setActive:YES];
    [[button.trailingAnchor constraintEqualToAnchor:self.mp_safeTrailingAnchor constant:-kRectangleButtonPadding] setActive:YES];
}

- (void)handleClickThrough {
    [self.delegate videoPlayerViewOverlay:self didTriggerEvent:MPVideoEventClick];
}

#pragma mark - Private: Skip Button

/**
 See https://developers.mopub.com/dsps/ad-formats/video/ for the MoPub definition of "skippable"
 and "non-skippable".
 */
- (BOOL)isVideoAdDurationLongEnoughToBeASkippableAd:(NSTimeInterval)videoAdDuration {
    return kVASTMinimumDurationOfSkippableVideo < videoAdDuration;
}

- (void)showSkipButton {
    if (self.skipButton) {
        return;
    }
    
    MPViewableButton *button = [MPViewableButton buttonWithType:UIButtonTypeCustom
                                                obstructionType:MPViewabilityObstructionTypeMediaControls
                                                obstructionName:MPViewabilityObstructionNameSkipButton];
    self.skipButton = button;
    button.accessibilityLabel = @"Skip Button";
    [button addTarget:self action:@selector(didHitSkipButton) forControlEvents:UIControlEventTouchUpInside];
    [button setImage:[UIImage imageForAsset:kMPImageAssetSkipButton] forState:UIControlStateNormal];
    
    [self addSubview:button];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [[button.topAnchor constraintEqualToAnchor:self.mp_safeTopAnchor] setActive:YES];
    [[button.trailingAnchor constraintEqualToAnchor:self.mp_safeTrailingAnchor] setActive:YES];
    [[button.widthAnchor constraintEqualToConstant:kSkipButtonDimension] setActive:YES];
    [[button.heightAnchor constraintEqualToConstant:kSkipButtonDimension] setActive:YES];
}

- (void)didHitSkipButton {
    [self.delegate videoPlayerViewOverlay:self didTriggerEvent:MPVideoEventSkip];
}

#pragma mark - Timer Control

- (void)pauseTimer {
    [self.clickThroughEnablingTimer pause];
    [self.timerView pause];
}

- (void)resumeTimer {
    [self.clickThroughEnablingTimer scheduleNow];
    [self.timerView resume];
}

- (void)stopTimer {
    // Invalidate the timers
    [self.clickThroughEnablingTimer invalidate];
    [self.timerView stopAndSignalCompletion:NO];
    
    // Remove the timer view from the view hierarchy
    [self.timerView removeFromSuperview];
    
    // Immediately deallocate the timers
    self.clickThroughEnablingTimer = nil;
    self.timerView = nil;
}

#pragma mark - Private: Close Button

- (void)didHitCloseButton:(UIButton *)button {
    [self.delegate videoPlayerViewOverlay:self didTriggerEvent:MPVideoEventClose];
}

- (void)showCloseButton {
    self.closeButtonType = MPAdViewCloseButtonTypeImageButton;
}

#pragma mark - MPViewabilityObstruction

- (MPViewabilityObstructionType)viewabilityObstructionType {
    return MPViewabilityObstructionTypeNotVisible;
}

- (MPViewabilityObstructionName)viewabilityObstructionName {
    return MPViewabilityObstructionNameOverlay;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // Ignore touches on the countdown timer (or any subview), since they
    // do not count as clickthroughs.
    return ![touch.view isDescendantOfView:self.timerView];
}

@end

#pragma mark -

@implementation MPAdViewOverlay (MPVideoPlayerViewOverlay)

- (instancetype)initWithVideoOverlayConfig:(MPVideoPlayerViewOverlayConfig *)config {
    if (self = [self initWithFrame:CGRectZero]) {
        _config = config;
        _allowPassthroughForTouches = NO;
        _notificationCenter = [NSNotificationCenter defaultCenter];
        [self setCloseButtonType:MPAdViewCloseButtonTypeNone];
    }
    return self;
}

- (void)showCountdownTimerForDuration:(NSTimeInterval)duration {
    [self showTimerViewForSkipOffset:duration totalDuration:duration];
}

- (void)handleVideoStartForSkipOffset:(NSTimeInterval)skipOffset
                        videoDuration:(NSTimeInterval)videoDuration {
    if (videoDuration <= 0) {
        MPLogError(@"Video duration [%.2f] is not positive" ,videoDuration);
        return;
    }
    
    NSTimeInterval actualSkipOffset = skipOffset;
    
    // Watch out for the case of the actual video duration being less than the skip offset.
    // For rewarded ads, this only applies in the case that they do not have an end card.
    if (!self.config.isRewardExpected || !self.config.hasCompanionAd) {
        actualSkipOffset = MIN(skipOffset, videoDuration);
    }
    
    if (actualSkipOffset <= 0) { // Invalid `skipOffset`: need a valid one
        if (self.config.isRewardExpected) { // rewarded ads
            /*
             For rewarded ads, the rule is simple: respect the provided `skipOffset` if it's valid.
             The skip offset is provided in the ad response as the value of "x-rewarded-duration"
             from backend business logic.
             
             Interestingly, while a fixed 30 seconds skip offset is typically provided for rewarded
             video ads, they are "non-skippable" in the MoPub definition (cannot skip before reaching
             the typical 30 seconds video duration).
             
             See https://developers.mopub.com/dsps/ad-formats/rewarded-video/ for more details.
            */
            actualSkipOffset = kVASTDefaultVideoOffsetToShowSkipButtonForRewardedVideo;
        }
        else {  // non-rewarded ads
            /*
             For non-rewarded ads, the rule is more complicated because the backend business logic
             for non-rewarded ads skip offset is out of scope for the Rewarded Ads Project (2020). As
             a result, non-rewarded ads skip offset business logic is still defined in the client based
             on the actual video length. See https://developers.mopub.com/dsps/ad-formats/video/ for
             the MoPub definition of "skippable" and "non-skippable".
             
             Note: Since backend is not providing the skip offset in the non-rewarded ad respond yet,
             the SDK code path is supposed to always run through here with `skipOffset` being 0.
             Rewrite this part after backend starts providing skip offset for non-rewarded ads.
             */
            if ([self isVideoAdDurationLongEnoughToBeASkippableAd:videoDuration]) { // skippable video
                actualSkipOffset = kVASTVideoOffsetToShowSkipButtonForSkippableVideo; // use default time offset
            }
            else { // non-skippable video
                actualSkipOffset = videoDuration; // don't show Skip button, totally not skippable
            }
        }
    }
    
    // for Skip button
    [self showTimerViewForSkipOffset:actualSkipOffset totalDuration:videoDuration];
    
    // for Call To Action button ("Learn More") and enabling clickability
    if (!self.config.isRewardExpected && self.config.enableEarlyClickthroughForNonRewardedVideo) {
        // Enable clickthrough immediately when non-rewarded, and `vast-click-enabled` ad response flag is true
        [self enableClickthrough];
    } else {
        // Enable clickthrough after the skip offset (reward duration for rewarded) in all other cases
        [self setUpClickthroughForOffset:actualSkipOffset videoDuration:videoDuration];
    }
}

- (void)handleVideoComplete {
    if (self.videoCompleted) {
        return;
    }
    self.videoCompleted = YES;
    
    // For rewarded video, when the video ends, only if the countdown timer
    // has completed (i.e. the video is longer than the reward duration)
    // should we show the close button. Otherwise, the close button will be
    // shown when the countdown timer completes.
    // For non-rewarded, the countdown duration will never be longer than
    // the video itself, so they will both trigger around the same time.
    if (self.hasCountdownTimerCompleted) {
        [self showCloseButton];
    }
    
    if (self.config.hasCompanionAd) {
        self.allowPassthroughForTouches = YES;
        
        // companion ad and CTA button are mutually exclusive
        [self.callToActionButton removeFromSuperview];
        self.callToActionButton = nil;
        
        // companion ad and industry icon are mutually exclusive
        [self.iconView removeFromSuperview];
        self.iconView = nil;
    }
}

- (void)showIndustryIcon:(MPVASTIndustryIcon *)icon {
    if (self.iconView == nil) {
        self.iconView = [MPVASTIndustryIconView new];
        self.iconView.iconViewDelegate = self;
        self.iconViewWidthConstraint = [self.iconView.mp_safeWidthAnchor constraintEqualToConstant:icon.width];
        self.iconViewHeightConstraint = [self.iconView.mp_safeHeightAnchor constraintEqualToConstant:icon.height];
        
        [self addSubview:self.iconView];
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [[self.iconView.mp_safeTopAnchor constraintEqualToAnchor:self.mp_safeTopAnchor] setActive:YES];
        [[self.iconView.mp_safeLeadingAnchor constraintEqualToAnchor:self.mp_safeLeadingAnchor] setActive:YES];
        [self.iconViewWidthConstraint setActive:YES];
        [self.iconViewHeightConstraint setActive:YES];
    } else {
        // if the icon view already exists, update the width and height
        self.iconViewWidthConstraint.constant = icon.width;
        self.iconViewHeightConstraint.constant = icon.height;
    }
    
    [self.iconView setHidden:YES]; // hidden by default, only show after loaded
    [self.iconView loadIcon:icon]; // delegate will handle load status updates
}

- (void)hideIndustryIcon {
    [self.iconView setHidden:YES];
}

@end

#pragma mark -

@implementation MPAdViewOverlay (MPVASTIndustryIconViewDelegate)

- (void)industryIconView:(MPVASTIndustryIconView *)iconView
         didTriggerEvent:(MPVASTResourceViewEvent)event {
    switch (event) {
        case MPVASTResourceViewEvent_ClickThrough: {
            break; // no op
        }
        case MPVASTResourceViewEvent_DidLoadView: {
            [self.iconView setHidden:NO];
            break;
        }
        case MPVASTResourceViewEvent_FailedToLoadView: {
            [self.iconView removeFromSuperview];
            self.iconView = nil;
            break;
        }
    }
    
    [self.delegate industryIconView:iconView didTriggerEvent:event];
}

- (void)industryIconView:(MPVASTIndustryIconView *)iconView
didTriggerOverridingClickThrough:(NSURL *)url {
    [self.delegate industryIconView:iconView didTriggerOverridingClickThrough:url];
}

@end
