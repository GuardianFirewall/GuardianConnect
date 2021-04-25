//
//  GCWindow.m
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GCWindow.h"

@implementation GCWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag {
    self = [super initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag];
    return self;
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [event locationInWindow];
    if(NSPointInRect(location, self.contentView.frame)){
        [_appDelegate mouseEnteredAlertsWindow:self event:event];
    } else {
        [_appDelegate mouseExitedAlertsWindow:self event:event];
    }
    [super mouseMoved:event];
}

@end
