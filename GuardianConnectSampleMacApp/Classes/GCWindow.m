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
    if (self){
        [self changeCloseButton];
    }
    return self;
}

- (void)changeCloseButton {
    NSButton *button = [self standardWindowButton:NSWindowCloseButton];
    [button setTarget:self];
    [button setAction:@selector(closeViaButton)];
}

- (void)makeKeyAndOrderFront:(id)sender {
    [super makeKeyAndOrderFront:sender];
    [self startMouseTracking];
}

- (void)close {
    [self stopMouseTracking];
    [super close];
}

- (void)mouseEntered:(NSEvent *)event {
    [_appDelegate mouseEnteredAlertsWindow:self event:event];
    [super mouseEntered:event];
}

- (void)mouseExited:(NSEvent *)event {
    [_appDelegate mouseExitedAlertsWindow:self event:event];
    [super mouseExited:event];
}

-(void) startMouseTracking {
    if (_trackingRectTag == 0  ) {
        NSView * windowView = [self contentView];
        NSRect trackingFrame = [windowView frame];
        trackingFrame.size.height += 1000.0;    // Include the title bar in the tracking rectangle (will be clipped)
        
        _trackingRectTag = [windowView addTrackingRect: trackingFrame
                                                 owner: self
                                              userData: nil
                                          assumeInside: NO];
    }
    
}

-(void)stopMouseTracking {
    if (_trackingRectTag != 0  ) {
        [[self contentView] removeTrackingRect: _trackingRectTag];
        _trackingRectTag = 0;
    }
}

- (void)closeViaButton {
    [self close];
}
/*
- (void)mouseMoved:(NSEvent *)event {
    NSPoint location = [event locationInWindow];
    if(NSPointInRect(location, self.contentView.frame)){
        [_appDelegate mouseEnteredAlertsWindow:self event:event];
    } else {
        [_appDelegate mouseExitedAlertsWindow:self event:event];
    }
    [super mouseMoved:event];
}
*/
@end
