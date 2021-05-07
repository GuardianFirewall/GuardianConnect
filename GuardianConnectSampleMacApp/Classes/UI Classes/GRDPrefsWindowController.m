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
#import "NSObject+Extras.h"
@implementation GRDPrefsWindowController

- (void)setupToolbar{
    _contents = [NSMutableArray new];
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
    if (!_contents){
        _contents = [NSMutableArray new];
    }
    [[GRDSettingsController sharedInstance] updateServerBlocklistWithItemProgress:^(GRDBlacklistGroupItem * _Nonnull item) {
        //GRDLog(@"item: %@", item);
    } completion:^(BOOL success) {
        if (success){
            [_contents addObjectsFromArray:[[GRDSettingsController sharedInstance] blacklistGroups]];
        }
    }];
}

- (void)check:(id)sender {
    LOG_SELF;
    GRDBlacklistGroupItem *group = (GRDBlacklistGroupItem*)[sender associatedValue];
    if ([group allEnabled]){
        [group setAllDisabled:true];
    } else {
        [group setAllEnabled:true];
    }
    [group saveChanges];
}

// -------------------------------------------------------------------------------
//    viewForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView *result = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    GRDBlacklistGroupItem *node = [item representedObject];
    
    if ([tableColumn.identifier isEqualToString:@"AutomaticTableColumnIdentifier.0"]){
        NSButton *check = [NSButton checkboxWithTitle:@"" target:self action:@selector(check:)];
        [check setAssociatedValue:node];
        [result addSubview:check];
        if (node.allEnabled){
            check.state = NSControlStateValueOn;
        } else {
            check.state = NSControlStateValueOff;
        }
    } else {
        result.textField.stringValue = node.title;
    }
    GRDLog(@"tableColumn: %@", tableColumn);
    return result;
}

@end
