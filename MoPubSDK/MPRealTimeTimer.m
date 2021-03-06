//
//  MPRealTimeTimer.m
//
//  Copyright 2018-2021 Twitter, Inc.
//  Licensed under the MoPub SDK License Agreement
//  http://www.mopub.com/legal/sdk-license-agreement/
//

#import "MPRealTimeTimer.h"

// For non-module targets, UIKit must be explicitly imported
// since MoPubSDK-Swift.h will not import it.
#if __has_include(<MoPubSDK/MoPubSDK-Swift.h>)
    #import <UIKit/UIKit.h>
    #import <MoPubSDK/MoPubSDK-Swift.h>
#else
    #import <UIKit/UIKit.h>
    #import "UnityInterView-Swift.h"
#endif

@interface MPRealTimeTimer ()

@property (strong, nonatomic) MPResumableTimer *timer;
@property (copy, nonatomic) void (^block)(MPRealTimeTimer *);
@property (assign, nonatomic) NSTimeInterval interval;
@property (assign, nonatomic, readwrite) BOOL isScheduled;

@property (copy, nonatomic) NSDate *fireDate;
@property (assign, nonatomic) NSTimeInterval currentTimeInterval;

@end

@implementation MPRealTimeTimer

- (instancetype)initWithInterval:(NSTimeInterval)interval
                           block:(void(^)(MPRealTimeTimer *))block {
    if (self = [super init]) {
        _interval = interval;
        _block = block;
    }
    
    return self;
}

- (void)scheduleNow {
    if (!self.isScheduled) {
        [self addNotificationCenterObservers];
        self.currentTimeInterval = self.interval;
        [self setTimerWithCurrentTimeInterval];
        self.isScheduled = YES;
    }
}

- (void)invalidate {
    [self.timer invalidate];
    self.timer = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.isScheduled = NO;
    self.fireDate = nil;
}

- (void)fire {
    [self invalidate];
    [self runBlock];
}

#pragma mark - Internal Methods

- (void)runBlock {
    if (self.block) {
        self.block(self);
    }
}

- (void)setTimerWithCurrentTimeInterval {
    __typeof__(self) __weak weakSelf = self;
    self.timer = [[MPResumableTimer alloc] initWithInterval:self.currentTimeInterval
                                                    repeats:NO
                                                runLoopMode:NSRunLoopCommonModes
                                                    closure:^(MPResumableTimer * _Nonnull timer) {
        __typeof__(self) strongSelf = weakSelf;
        [strongSelf fire];
    }];
    
    [self.timer scheduleNow];
    if (!self.fireDate) {
        self.fireDate = [NSDate dateWithTimeIntervalSinceNow:self.currentTimeInterval];
    }
}

- (void)didEnterBackground {
    // invalidate timer (don't invalidate self because we're still keeping time)
    [self.timer invalidate];
}

- (void)willEnterForeground {
    // skip resetting the timer if it's already set (i.e., in the iOS 13 new-window case)
    if ([self.timer isValid]) {
        return;
    }
    
    // check if date has passed and fire if needed
    NSComparisonResult result = [[NSDate date] compare:self.fireDate];
    if (result == NSOrderedSame || result == NSOrderedDescending) {
        [self fire];
        return;
    }
    
    // update time interval and schedule a new timer if it's not yet time to fire
    self.currentTimeInterval = [self.fireDate timeIntervalSinceNow];
    [self setTimerWithCurrentTimeInterval];
}

- (void)addNotificationCenterObservers {
    // Set up notifications to react to backgrounding/foregrounding
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
