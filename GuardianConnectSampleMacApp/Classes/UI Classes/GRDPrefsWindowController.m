//
//  GRDPrefsWindowController.m
//  Guardian
//
//  Created by Kevin Bradley on 4/27/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDPrefsWindowController.h"
#import "GRDSettingsController.h"
#import <GuardianConnect/Shared.h>

@implementation GRDPrefsWindowController

- (void)setupToolbar{
    [self addView:self.generalPreferenceView label:@"General"];
    [self addView:self.blocklistPreferenceView label:@"Blocklist"];
    [self addView:self.exceptionsPreferencesView label:@"Exceptions"];
    [self addView:self.notificationsPreferencesView label:@"Notifications"];
    [self addView:self.updatesPreferenceView label:@"Updates"];
    [self addFlexibleSpacer];
    [self addView:self.advancedPreferenceView label:@"Advanced"];

    // Optional configuration settings.
    [self setCrossFade:[[NSUserDefaults standardUserDefaults] boolForKey:@"fade"]];
    [self setShiftSlowsAnimation:[[NSUserDefaults standardUserDefaults] boolForKey:@"shiftSlowsAnimation"]];
}

- (void)fetchBlacklistItems {
    [[GRDSettingsController sharedInstance] updateServerBlocklistWithItemProgress:^(GRDBlacklistGroupItem * _Nonnull item) {
        GRDLog(@"item: %@", item);
    } completion:^(BOOL success) {
        if (success){
            GRDLog(@"got all the items!");
            self.blacklistTreeController.content = [[GRDSettingsController sharedInstance] blacklistGroups];
        }
    }];
}

@end
