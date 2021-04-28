//
//  GCImageView.m
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GCImageView.h"
#import <Carbon/Carbon.h>

@implementation GCImageView

- (BOOL)optionKeyIsDown {
    return (GetCurrentKeyModifiers() & optionKey) != 0;
}

-(void)mouseDownInMainThread:(NSEvent *)theEvent {
    if (_appDelegate){
        [_appDelegate createMenu];
    }
    if (theEvent.clickCount == 3) {
        [_appDelegate openPreferences:nil];
    } else {
        NSStatusItem * statusI = [_appDelegate item];
        NSMenu       * menu    = [_appDelegate menu];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        /*
        [[menu itemArray] enumerateObjectsUsingBlock:^(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            //[obj setTarget:_appDelegate];
            NSLog(@"sel: %@ target: %@", NSStringFromSelector(obj.action), obj.target);
        }];
         */
        if ([self optionKeyIsDown]){
            [_appDelegate showDeveloperItems];
        } else {
            [_appDelegate hideDeveloperItems];
        }
        [statusI popUpStatusItemMenu: menu];
#pragma clang diagnostic pop
    }
}

-(void)removeTrackingRect {
    
    if (iconTrackingRectTagIsValid ) {
        [self removeTrackingRect: iconTrackingRectTag];
        iconTrackingRectTagIsValid = FALSE;
    }
}

//TODO: update to use NSTrackingArea instead, supported all the way back to 10.5

-(void)createTrackingRect {
    [self removeTrackingRect];
    NSRect frame = [self frame];
    NSRect trackingRect = NSMakeRect(frame.origin.x + 1.0f, frame.origin.y, frame.size.width - 1.0f, frame.size.height);
    iconTrackingRectTag = [self addTrackingRect: trackingRect
                                              owner: self
                                           userData: nil
                                       assumeInside: NO];
    iconTrackingRectTagIsValid = TRUE;
}

-(void)drawRect:(NSRect)rect {
    NSStatusItem * statusI = [_appDelegate item];
    BOOL menuIsOpen = [_appDelegate menuIsOpen];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [statusI drawStatusBarBackgroundInRect: rect withHighlight: menuIsOpen];
#pragma clang diagnostic pop
    [super drawRect: rect];
}


-(id)initWithFrame:(NSRect) frame {
    
    self = [super initWithFrame: frame];
    if (self) {
        iconTrackingRectTagIsValid = FALSE;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
#pragma clang diagnostic pop
    }
    
    return self;
}

-(void) dealloc {
    
    [self removeTrackingRect];
    [self unregisterDraggedTypes];
    [_appDelegate mouseExitedMainIcon:self event:[NSEvent new]];
    
}

- (void)mouseEntered:(NSEvent *)event {
    if (_appDelegate){
        [_appDelegate mouseEnteredMainIcon:self event:event];
    }
}

- (void)mouseExited:(NSEvent *)event {
    if (_appDelegate){
        [_appDelegate mouseExitedMainIcon:self event:event];
    }
}

-(void)mouseDown:(NSEvent *)theEvent {
    
    [self performSelectorOnMainThread: @selector(mouseDownInMainThread:) withObject: theEvent waitUntilDone: NO];
    [super mouseDown:theEvent];
}

-(void)mouseUp:(NSEvent *)theEvent {
    [super mouseUp:theEvent];
}

@end
