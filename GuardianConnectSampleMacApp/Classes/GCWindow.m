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


-(void)startMouseTracking {
    if (_trackingRectTag == 0  ) {
        NSView * windowView = [self contentView];
        NSRect trackingFrame = [windowView frame];
        trackingFrame.size.height += 1000.0;    // Include the title bar in the tracking rectangle (will be clipped)]
        trackingFrame.size.width += 50; //to assist in resizing being easier
        
        _trackingRectTag = [windowView addTrackingRect: trackingFrame
                                                 owner: self
                                              userData: nil
                                          assumeInside: NO];
    }
    
}

-(void)mouseUp:(NSEvent *)event {
    [super mouseUp:event];
}

-(void)mouseDown:(NSEvent *)event {
    NSTimeInterval thisTime = [event timestamp];
    if ((_windowLastClickTime + 1.0) > thisTime) {
        _windowLastClickTime = 0;
        [_appDelegate doubleClickTriggered:self event:event];
        return;
    } else {
        
    }
    _windowLastClickTime = thisTime;
    [super mouseDown:event];
}

-(void)stopMouseTracking {
    if (_trackingRectTag != 0  ) {
        [[self contentView] removeTrackingRect: _trackingRectTag];
        _trackingRectTag = 0;
    }
}

- (void)closeViaButton {
    self.shownManually = false;
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