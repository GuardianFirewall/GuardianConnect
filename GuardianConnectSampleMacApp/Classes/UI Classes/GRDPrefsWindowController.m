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
            //self.blacklistTreeController.content = [[GRDSettingsController sharedInstance] blacklistGroups];
            //GRDBlacklistGroupItem *testItem = [[[GRDSettingsController sharedInstance] blacklistGroups] firstObject];
            //[self.blacklistTreeController insertObject:testItem atArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:0]];
            GRDLog(@"contents: %@", _contents);
            GRDLog(@"treeController arranged objects: %@", self.blacklistTreeController.arrangedObjects);
            
        }
    }];
}

// -------------------------------------------------------------------------------
//    viewForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView *result = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    GRDBlacklistGroupItem *node = [item representedObject];
    result.textField.stringValue = node.title;
    GRDLog(@"result: %@", result);
    return result;
}

@end
