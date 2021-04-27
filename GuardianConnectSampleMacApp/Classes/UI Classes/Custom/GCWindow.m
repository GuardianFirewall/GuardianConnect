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
    [self startTracking];
}

- (void)close {
    [self stopTracking];
    [_appDelegate removeAlertObserver];
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

//TODO: update to use NSTrackingArea instead, supported all the way back to 10.5

-(void)startTracking {
    if (_trackingRectTag == 0) {
        NSView *windowView = [self contentView];
        NSRect trackingFrame = [windowView frame];
        trackingFrame.size.height += 1000.0;
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
    if (event.clickCount == 2){
        [_appDelegate doubleClickTriggered:self event:event];
    }
    [super mouseDown:event];
}

-(void)restartTracking {
    [self stopTracking];
    [self startTracking];
}

-(void)stopTracking {
    if (_trackingRectTag != 0) {
        [[self contentView] removeTrackingRect: _trackingRectTag];
        _trackingRectTag = 0;
    }
}

- (void)closeViaButton {
    self.shownManually = false;
    [self close];
}

- (void)hideExpandText {
    self.expandTextField.alphaValue = 0.0;
}

- (void)showExpandText {
    self.expandTextField.alphaValue = 1.0;
}

@end
