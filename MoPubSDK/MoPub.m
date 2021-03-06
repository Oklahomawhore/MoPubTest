//
//  MoPub.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import "MoPub.h"
// For non-module targets, UIKit must be explicitly imported
// since MoPubSDK-Swift.h will not import it.
#if __has_include(<MoPubSDK/MoPubSDK-Swift.h>)
    #import <UIKit/UIKit.h>
    #import <MoPubSDK/MoPubSDK-Swift.h>
#else
    #import <UIKit/UIKit.h>
    #import "UnityInterView-Swift.h"
#endif
#import "MPAdServerURLBuilder.h"
#import "MPConsentManager.h"
#import "MPConstants.h"
#import "MPLogging.h"
#import "MPMediationManager.h"
#import "MPRewardedAds.h"
#import "MPWebView.h"
#import "MOPUBExperimentProvider.h"
#import "MPAdConversionTracker.h"
#import "MPConsentManager.h"
#import "MPConsentChangedNotification.h"
#import "MPSessionTracker.h"
#import "MPViewabilityManager.h"


@interface MoPub ()

@property (nonatomic, strong) NSArray *globalMediationSettings;

@property (nonatomic, assign, readwrite) BOOL isSdkInitialized;

@property (nonatomic, strong) MOPUBExperimentProvider *experimentProvider;

@end

@implementation MoPub

+ (MoPub *)sharedInstance
{
    static MoPub *sharedInstance = nil;
    static dispatch_once_t initOnceToken;
    dispatch_once(&initOnceToken, ^{
        sharedInstance = [[MoPub alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        [self commonInitWithExperimentProvider:MOPUBExperimentProvider.sharedInstance];
    }
    return self;
}

/**
 This common init enables unit testing with an `MOPUBExperimentProvider` instance that is not a singleton.
 */
- (void)commonInitWithExperimentProvider:(MOPUBExperimentProvider *)experimentProvider
{
    _experimentProvider = experimentProvider;
}

- (void)setLocationUpdatesEnabled:(BOOL)locationUpdatesEnabled
{
    MPDeviceInformation.enableLocation = locationUpdatesEnabled;
}

- (BOOL)locationUpdatesEnabled
{
    return MPDeviceInformation.enableLocation;
}

- (void)setLogLevel:(MPBLogLevel)level
{
    MPLogging.consoleLogLevel = level;
}

- (MPBLogLevel)logLevel
{
    return MPLogging.consoleLogLevel;
}

- (void)setClickthroughDisplayAgentType:(MOPUBDisplayAgentType)displayAgentType
{
    self.experimentProvider.displayAgentType = displayAgentType;
}

// Keep -version and -bundleIdentifier methods around for Fabric backwards compatibility.
- (NSString *)version
{
    return MP_SDK_VERSION;
}

- (NSString *)bundleIdentifier
{
    return MP_BUNDLE_IDENTIFIER;
}

- (void)initializeSdkWithConfiguration:(MPMoPubConfiguration *)configuration
                            completion:(void(^_Nullable)(void))completionBlock
{
    if (@available(iOS 10, *)) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [self setSdkWithConfiguration:configuration completion:completionBlock];
        });
    } else {
        MPLogEvent([MPLogEvent error:[NSError sdkMinimumOsVersion:10] message:nil]);
        NSAssert(false, @"MoPub SDK requires iOS 10 and up");
    }
}

- (void)setSdkWithConfiguration:(MPMoPubConfiguration *)configuration
                     completion:(void(^_Nullable)(void))completionBlock
{
    @synchronized (self) {
        // Set the console logging level.
        MPLogging.consoleLogLevel = configuration.loggingLevel;
        
        // Store the global mediation settings
        self.globalMediationSettings = configuration.globalMediationSettings;
        
        // Create a dispatch group to synchronize mutliple asynchronous tasks.
        dispatch_group_t initializationGroup = dispatch_group_create();
        
        // Configure the consent manager and synchronize regardless of the result
        // of `checkForDoNotTrackAndTransition`.
        dispatch_group_enter(initializationGroup);

        MPConsentManager.sharedManager.adUnitIdUsedForConsent = configuration.adUnitIdForAppInitialization;
        MPConsentManager.sharedManager.allowLegitimateInterest = configuration.allowLegitimateInterest;
        // Process personal data if a user is in GDPR region.
        [[MPConsentManager sharedManager] checkForIfaChange];
        [MPConsentManager.sharedManager checkForDoNotTrackAndTransition];
        [MPConsentManager.sharedManager synchronizeConsentWithCompletion:^(NSError * _Nullable error) {
            dispatch_group_leave(initializationGroup);
        }];
        
        // Configure session tracker
        [MPSessionTracker initializeNotificationObservers];
        
        // Configure Viewability
        dispatch_group_enter(initializationGroup);
        [MPViewabilityManager.sharedManager initializeWithCompletion:^(BOOL isInitialized) {
            dispatch_group_leave(initializationGroup);
        }];
        
        // Configure mediated network SDKs
        __block NSArray<id<MPAdapterConfiguration>> * initializedNetworks = nil;
        dispatch_group_enter(initializationGroup);
        [MPMediationManager.sharedManager initializeWithAdditionalProviders:configuration.additionalNetworks
                                                             configurations:configuration.mediatedNetworkConfigurations
                                                             requestOptions:configuration.moPubRequestOptions
                                                                   complete:^(NSError * error, NSArray<id<MPAdapterConfiguration>> * initializedAdapters) {
            initializedNetworks = initializedAdapters;
            dispatch_group_leave(initializationGroup);
        }];
        
        // Start MPDeviceInformation to pre-cache carrier information.
        dispatch_group_enter(initializationGroup);
        [MPDeviceInformation startWithCompletion:^{
            dispatch_group_leave(initializationGroup);
        }];
        
        // Once all of the asynchronous tasks have completed, notify the
        // completion handler.
        dispatch_group_notify(initializationGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            MPLogEvent([MPLogEvent sdkInitializedWithNetworks:initializedNetworks]);
            self.isSdkInitialized = YES;
            if (completionBlock) {
                completionBlock();
            }
        });
    }
}

- (id<MPMediationSettingsProtocol>)globalMediationSettingsForClass:(Class)aClass
{
    NSArray *mediationSettingsCollection = self.globalMediationSettings;

    for (id<MPMediationSettingsProtocol> settings in mediationSettingsCollection) {
        if ([settings isKindOfClass:aClass]) {
            return settings;
        }
    }

    return nil;
}

- (void)disableViewability:(MPViewabilityOption)vendors
{
    [MPViewabilityManager.sharedManager disableViewability];
}

- (void)disableViewability
{
    [MPViewabilityManager.sharedManager disableViewability];
}

- (void)setEngineInformation:(MPEngineInfo *)info
{
    MPAdServerURLBuilder.engineName = info.name;
    MPAdServerURLBuilder.engineVersion = info.version;
}

- (void)setEngineName:(NSString *)name version:(NSString *)version
{
    MPAdServerURLBuilder.engineName = name;
    MPAdServerURLBuilder.engineVersion = version;
}

@end

@implementation MoPub (Mediation)

- (id<MPAdapterConfiguration>)adapterConfigurationNamed:(NSString *)className {
    // No class name
    if (className == nil) {
        return nil;
    }
    
    // Class doesn't exist.
    Class classToFind = NSClassFromString(className);
    if (classToFind == Nil) {
        return nil;
    }
    
    NSPredicate * predicate = [NSPredicate predicateWithFormat:@"self isKindOfClass: %@", classToFind];
    NSArray * adapters = [MPMediationManager.sharedManager.adapters.allValues filteredArrayUsingPredicate:predicate];
    return adapters.firstObject;
}

- (NSArray<NSString *> * _Nullable)availableAdapterClassNames {
    NSMutableArray<NSString *> * adapterClassNames = [NSMutableArray arrayWithCapacity:MPMediationManager.sharedManager.adapters.count];
    [MPMediationManager.sharedManager.adapters.allValues enumerateObjectsUsingBlock:^(id<MPAdapterConfiguration>  _Nonnull adapter, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * className = NSStringFromClass(adapter.class);
        if (className != nil) {
            [adapterClassNames addObject:className];
        }
    }];
    
    return adapterClassNames;
}

- (void)clearCachedNetworks {
    [MPMediationManager.sharedManager clearCache];
}

@end

@implementation MoPub (Consent)

- (BOOL)shouldShowConsentDialog {
    return [MPConsentManager sharedManager].isConsentNeeded;
}

- (BOOL)canCollectPersonalInfo {
    return [MPConsentManager sharedManager].canCollectPersonalInfo;
}

- (MPBool)isGDPRApplicable {
    return [MPConsentManager sharedManager].isGDPRApplicable;
}

- (void)forceGDPRApplicable {
    [MPConsentManager sharedManager].forceIsGDPRApplicable = YES;
}

- (MPConsentStatus)currentConsentStatus {
    return [MPConsentManager sharedManager].currentStatus;
}

- (NSString *)currentConsentIabVendorListFormat {
    return [MPConsentManager sharedManager].iabVendorList;
}

- (NSString *)currentConsentPrivacyPolicyVersion {
    return [MPConsentManager sharedManager].privacyPolicyVersion;
}

- (NSString *)currentConsentVendorListVersion {
    return [MPConsentManager sharedManager].vendorListVersion;
}

- (NSString *)previouslyConsentedIabVendorListFormat {
    return [MPConsentManager sharedManager].consentedIabVendorList;
}

- (NSString *)previouslyConsentedPrivacyPolicyVersion {
    return [MPConsentManager sharedManager].consentedPrivacyPolicyVersion;
}

- (NSString *)previouslyConsentedVendorListVersion {
    return [MPConsentManager sharedManager].consentedVendorListVersion;
}

- (void)loadConsentDialogWithCompletion:(void (^)(NSError * _Nullable))completion {
    [[MPConsentManager sharedManager] loadConsentDialogWithCompletion:completion];
}

- (void)showConsentDialogFromViewController:(UIViewController *)viewController
                                    didShow:(void (^ _Nullable)(void))didShow
                                 didDismiss:(void (^ _Nullable)(void))didDismiss {
    [[MPConsentManager sharedManager] showConsentDialogFromViewController:viewController
                                                                  didShow:didShow
                                                               didDismiss:didDismiss];
}

- (void)showConsentDialogFromViewController:(UIViewController *)viewController completion:(void (^ _Nullable)(void))completion {
    [self showConsentDialogFromViewController:viewController
                                      didShow:completion
                                   didDismiss:nil];
}

- (BOOL)allowLegitimateInterest {
    return [MPConsentManager sharedManager].allowLegitimateInterest;
}

- (void)setAllowLegitimateInterest:(BOOL)allowLegitimateInterest {
    [MPConsentManager sharedManager].allowLegitimateInterest = allowLegitimateInterest;
}

- (BOOL)isConsentDialogReady {
    return [MPConsentManager sharedManager].isConsentDialogLoaded;
}

- (void)revokeConsent {
    [[MPConsentManager sharedManager] revokeConsent];
}

- (void)grantConsent {
    [[MPConsentManager sharedManager] grantConsent];
}

- (NSURL *)currentConsentPrivacyPolicyUrl {
    return [[MPConsentManager sharedManager] privacyPolicyUrl];
}

- (NSURL *)currentConsentPrivacyPolicyUrlWithISOLanguageCode:(NSString *)isoLanguageCode {
    return [[MPConsentManager sharedManager] privacyPolicyUrlWithISOLanguageCode:isoLanguageCode];
}

- (NSURL *)currentConsentVendorListUrl {
    return [[MPConsentManager sharedManager] vendorListUrl];
}

- (NSURL *)currentConsentVendorListUrlWithISOLanguageCode:(NSString *)isoLanguageCode {
    return [[MPConsentManager sharedManager] vendorListUrlWithISOLanguageCode:isoLanguageCode];
}

@end
