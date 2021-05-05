//
//  GRDPrefsWindowController.h
//  Guardian
//
//  Created by Kevin Bradley on 4/27/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "DBPrefsWindowController.h"

NS_ASSUME_NONNULL_BEGIN

@interface GRDPrefsWindowController : DBPrefsWindowController

@property (strong, nonatomic) IBOutlet NSView *generalPreferenceView;
@property (strong, nonatomic) IBOutlet NSView *blocklistPreferenceView;
@property (strong, nonatomic) IBOutlet NSView *exceptionsPreferencesView;
@property (strong, nonatomic) IBOutlet NSView *notificationsPreferencesView;
@property (strong, nonatomic) IBOutlet NSView *updatesPreferenceView;
@property (strong, nonatomic) IBOutlet NSView *advancedPreferenceView;
@property (strong, nonatomic) IBOutlet NSTreeController *blacklistTreeController;
@property (strong, nonatomic) IBOutlet NSOutlineView *blacklistOutlineView;
- (void)fetchBlacklistItems;

@end

NS_ASSUME_NONNULL_END
