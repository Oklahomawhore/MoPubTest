//
//  MPLogEvent.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import "MPLogEvent.h"
#import "MPAdapterConfiguration.h"
#import "MPReward.h"
#import "MPURLRequest.h"
#import "MPViewabilityObstruction.h"
#import "NSString+MPConsentStatus.h"

@implementation MPLogEvent

- (instancetype)initWithMessage:(NSString *)message {
    return [self initWithMessage:message level:MPBLogLevelDebug];
}

- (instancetype)initWithMessage:(NSString *)message level:(MPBLogLevel)level {
    if (self = [super init]) {
        _message = message;
        _logLevel = level;
    }
    
    return self;
}

+ (instancetype)error:(NSError *)error message:(NSString * _Nullable)message {
    NSString * formattedMessage = (message != nil ? [NSString stringWithFormat:@"%@: ", message] : @"");
    NSString * logMessage = [NSString stringWithFormat:@"%@(%@) %@", formattedMessage, @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:logMessage];
}

+ (instancetype)eventWithMessage:(NSString *)message level:(MPBLogLevel)level {
    return [[MPLogEvent alloc] initWithMessage:message level:level];
}

@end

#pragma mark - AdLifeCycle

@implementation MPLogEvent (AdLifeCycle)

+ (instancetype)adRequestedWithRequest:(MPURLRequest *)request {
    NSString * message = [NSString stringWithFormat:@"Requesting an ad from Adserver: %@", request];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adRequestReceivedResponse:(NSDictionary *)response {
    NSString * message = [NSString stringWithFormat:@"Adserver responded with:\n%@", response];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adLoadAttempt {
    static NSString * const message = @"Attempting to load ad";
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

+ (instancetype)adShowAttempt {
    static NSString * const message = @"Attempting to show ad";
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

+ (instancetype)adShowSuccess {
    static NSString * const message = @"Ad shown";
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

+ (instancetype)adShowFailedWithError:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Ad failed to show: (%@) %@", @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

+ (instancetype)adDidLoad {
    static NSString * const message = @"Ad loaded";
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

+ (instancetype)adFailedToLoadWithError:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Ad failed to load: (%@) %@", @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

+ (instancetype)adExpiredWithTimeInterval:(NSTimeInterval)expirationInterval {
    NSString * message = [NSString stringWithFormat:@"Ad expired since it was not shown within %@ minutes of it being loaded", @(expirationInterval / 60)];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillPresentModal {
    static NSString * const message = @"Ad will present modal";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adDidDismissModal {
    static NSString * const message = @"Ad did dismiss modal";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adTapped {
    static NSString * const message = @"Ad tapped";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillPresent {
    static NSString * const message = @"Ad will present";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adDidPresent {
    static NSString * const message = @"Ad did present";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillDismiss {
    static NSString * const message = @"Ad will dismiss";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adDidDismiss {
    static NSString * const message = @"Ad did dismiss";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adShouldRewardUserWithReward:(MPReward *)reward {
    NSString * message = [NSString stringWithFormat:@"Should rewarded user with %@ %@", reward.amount, reward.currencyType];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillLeaveApplication {
    static NSString * const message = @"Ad will leave application";
    return [[MPLogEvent alloc] initWithMessage:message];
}

@end

#pragma mark - AdapterAdLifeCycle

@implementation MPLogEvent (AdapterAdLifeCycle)

+ (instancetype)adLoadAttemptForAdapter:(NSString *)name dspCreativeId:(NSString *)creativeId dspName:(NSString *)dspName {
    NSString * creativeIdMessage = (creativeId != nil ? [NSString stringWithFormat:@" with DSP creative ID %@", creativeId] : @"");
    NSString * dspMessage = (dspName != nil ? [NSString stringWithFormat:@" and DSP Name %@", dspName] : @"");
    NSString * message = [NSString stringWithFormat:@"Adapter %@ attempting to load ad%@%@", name, creativeIdMessage, dspMessage];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adLoadSuccessForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter %@ successfully loaded ad", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adLoadFailedForAdapter:(NSString *)name error:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Adapter %@ failed to load ad: (%@) %@", name, @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adShowAttemptForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter %@ attempting to show ad", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adShowSuccessForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter %@ successfully showed ad", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adShowFailedForAdapter:(NSString *)name error:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Adapter %@ failed to show ad: (%@) %@", name, @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillPresentModalForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ will present modal", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adDidDismissModalForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ did dismiss modal", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adTappedForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ received tap event", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillAppearForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ will appear", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adDidAppearForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ did appear", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillDisappearForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ will disappear", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adDidDisappearForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ did disappear", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)adWillLeaveApplicationForAdapter:(NSString *)name {
    NSString * message = [NSString stringWithFormat:@"Adapter ad from %@ will leave application", name];
    return [[MPLogEvent alloc] initWithMessage:message];
}

@end

#pragma mark - Initialization

@implementation MPLogEvent (Initialization)

+ (instancetype)sdkInitializedWithNetworks:(NSArray<id<MPAdapterConfiguration>> *)networks {
    // Compile the network adapter versions and underlying SDK versions into a human
    // readable format string.
    NSMutableArray<NSString *> * networkVersions = [NSMutableArray arrayWithCapacity:networks.count];
    [networks enumerateObjectsUsingBlock:^(id<MPAdapterConfiguration> _Nonnull adapter, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * message = [NSString stringWithFormat:@"%@: Adapter version %@, SDK version %@", NSStringFromClass(adapter.class), adapter.adapterVersion, adapter.networkSdkVersion];
        [networkVersions addObject:message];
    }];
    NSString * networksMessage = (networkVersions.count > 0 ? [networkVersions componentsJoinedByString:@"\n\t"] : @"No adapters initialized");
    
    NSString * message = [NSString stringWithFormat:@"SDK initialized and ready to display ads.\n\tInitialized adapters:\n\t%@\n", networksMessage];
    return [[MPLogEvent alloc] initWithMessage:message level:MPBLogLevelInfo];
}

@end

#pragma mark - Consent

@implementation MPLogEvent (Consent)

+ (instancetype)consentSyncAttempted {
    static NSString * const message = @"Attempting to synchronize consent state";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentSyncCompletedWithMessage:(NSString * _Nullable)message {
    NSString * formattedMessage = (message != nil ? [NSString stringWithFormat:@": %@", message] : @"");
    NSString * logMessage = [NSString stringWithFormat:@"Consent synchronization complete%@", formattedMessage];
    return [[MPLogEvent alloc] initWithMessage:logMessage];
}

+ (instancetype)consentSyncFailedWithError:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Consent synchronization failed: (%@) %@", @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentUpdatedTo:(MPConsentStatus)newStatus from:(MPConsentStatus)oldStatus reason:(NSString * _Nullable)reason canCollectPersonalInfo:(BOOL)canCollectPII {
    NSString * reasonMessage = (reason != nil ? [NSString stringWithFormat:@" Reason: %@", reason] : @"");
    NSString * message = [NSString stringWithFormat:@"Consent changed to %@ from %@; PII can%@ be collected.%@", [NSString stringFromConsentStatus:newStatus], [NSString stringFromConsentStatus:oldStatus], (canCollectPII ? @"" : @"not"), reasonMessage];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentShouldShowDialog {
    static NSString * const message = @"Consent dialog should be shown";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentDialogLoadAttempted {
    static NSString * const message = @"Attempting to load consent dialog";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentDialogLoadSuccess {
    static NSString * const message = @"Consent dialog loaded";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentDialogLoadFailedWithError:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Consent dialog failed to load: (%@) %@", @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentDialogShowAttempted {
    static NSString * const message = @"Attempting to show consent dialog";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentDialogShowSuccess {
    static NSString * const message = @"Consent dialog shown";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)consentDialogShowFailedWithError:(NSError *)error {
    NSString * message = [NSString stringWithFormat:@"Consent dialog failed to show: (%@) %@", @(error.code), error.localizedDescription];
    return [[MPLogEvent alloc] initWithMessage:message];
}

@end

@implementation MPLogEvent (Javascript)

+ (instancetype)javascriptConsoleLogWithMessage:(NSString *)message {
    NSString * scrubbedMessage = [message stringByReplacingOccurrencesOfString:@"ios-log: " withString:@""];
    return [[MPLogEvent alloc] initWithMessage:[NSString stringWithFormat:@"Javascript console logged: %@", scrubbedMessage]];
}

@end

@implementation MPLogEvent (Viewability)

+ (instancetype)viewabilityDisabled {
    static NSString * const message = @"Viewability has been disabled";
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerCreated:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) created", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerDeallocated:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) deallocated", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerSessionStarted:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) started session", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerSessionStopped:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) stopped session", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerUpdatedTrackingView:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) changed tracked view", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerTrackedAdLoaded:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) ad event: loaded", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTrackerTrackedImpression:(id<MPViewabilityTracker>)tracker {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) ad event: impression", tracker];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTracker:(id<MPViewabilityTracker>)tracker trackedVideoEvent:(NSString *)event {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) video event: %@", tracker, event];
    return [[MPLogEvent alloc] initWithMessage:message];
}

+ (instancetype)viewabilityTracker:(id<MPViewabilityTracker>)tracker addedFriendlyObstruction:(id<MPViewabilityObstruction>)obstruction {
    NSString * message = [NSString stringWithFormat:@"Viewability tracker (%p) added friendly obstruction: %@", tracker, obstruction.viewabilityObstructionName];
    return [[MPLogEvent alloc] initWithMessage:message];
}

@end
