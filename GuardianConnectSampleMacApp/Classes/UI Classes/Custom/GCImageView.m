//
//  GCImageView.m
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GCImageView.h"

@implementation GCImageView

-(void)mouseDownMainThread:(NSEvent *) theEvent {
    if (_appDelegate){
        [_appDelegate createMenu];
    }
    
    NSTimeInterval thisTime = [theEvent timestamp];
    if ((iconLastClickTime + 1.0) > thisTime) {
        [_appDelegate openPreferences];
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
        [statusI popUpStatusItemMenu: menu];
#pragma clang diagnostic pop
    }
    iconLastClickTime = thisTime;
}

-(void)removeTrackingRect {
    
    if (iconTrackingRectTagIsValid ) {
        [self removeTrackingRect: iconTrackingRectTag];
        iconTrackingRectTagIsValid = FALSE;
    }
}

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
    
    [self performSelectorOnMainThread: @selector(mouseDownMainThread:) withObject: theEvent waitUntilDone: NO];
    [super mouseDown:theEvent];
}

-(void)mouseUp:(NSEvent *)theEvent {
    [super mouseUp:theEvent];
}

@end
