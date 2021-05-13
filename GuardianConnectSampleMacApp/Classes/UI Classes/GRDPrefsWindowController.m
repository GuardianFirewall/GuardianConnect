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
            [self.contents addObjectsFromArray:[[GRDSettingsController sharedInstance] blacklistGroups]];
            [self.contents enumerateObjectsUsingBlock:^(GRDBlacklistGroupItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [obj.items enumerateObjectsUsingBlock:^(GRDBlacklistItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
                    [item setGroup:obj];
                }];
            }];
        }
    }];
}

- (void)check:(id)sender {
    GRDBlacklistGroupItem *item = (GRDBlacklistGroupItem*)[sender associatedValue];
    if ([item isLeaf]){ //were an item not a group
        GRDBlacklistItem *blItem = (GRDBlacklistItem *)item;
        if ([blItem enabled]){
            [blItem setEnabled:false];
        } else {
            [blItem setEnabled:true];
        }
        [[blItem group] saveChanges];
    } else { //we are indeed a group
        [item selectInverse];
    }
     [self.blacklistOutlineView reloadData];
}

// -------------------------------------------------------------------------------
//    viewForTableColumn:tableColumn:item
// -------------------------------------------------------------------------------
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSTableCellView *result = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    
    GRDBlacklistGroupItem *node = [item representedObject];
    
    if ([tableColumn.identifier isEqualToString:@"check"]){
        NSButton *check = nil;
        if (result.subviews.count == 1){
            check = [NSButton checkboxWithTitle:node.title target:self action:@selector(check:)];
            [check setAssociatedValue:node];
            [result addSubview:check];
        } else {
            check = (NSButton*)result.subviews.lastObject;
            check.title = node.title;
            [check setAssociatedValue:node];
            NSRect frame = check.frame;
            frame.size.width = 500; //just to make sure its okay for now since these cells get re-used.
            check.frame = frame;
        }
        
        if ([node respondsToSelector:@selector(allEnabled)]){
            check.allowsMixedState = true;
        
            if (!node.anyDisabled){
                check.state = NSControlStateValueOn;
            } else if ([node anyEnabled]){
                check.state = NSControlStateValueMixed;
            } else {
                check.state = NSControlStateValueOff;
            }
        } else {
            check.allowsMixedState = false;
            if (node.enabled){
                check.state = NSControlStateValueOn;
            } else {
                check.state = NSControlStateValueOff;
            }
        }
    } else {
        result.textField.stringValue = node.title;
    }
    //GRDLog(@"tableColumn: %@", tableColumn);
    return result;
}

@end
