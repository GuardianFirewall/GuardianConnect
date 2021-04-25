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
    if ((mainIconLastClickTime + 1.0) > thisTime) {
        [_appDelegate openPreferences];
    } else {
        NSStatusItem * statusI = [_appDelegate item];
        NSMenu       * menu    = [_appDelegate menu];
        [statusI popUpStatusItemMenu: menu];
    }
    mainIconLastClickTime = thisTime;
}

-(void) removeTrackingRectangle {
    
    if ( mainIconTrackingRectTagIsValid ) {
        [self removeTrackingRect: mainIconTrackingRectTag];
        mainIconTrackingRectTagIsValid = FALSE;
        NSLog(@"Removed main tracking rectangle for MainIconView");
    }
}

-(void)setupTrackingRect{
    [self removeTrackingRectangle];
    NSRect frame = [self frame];
    NSRect trackingRect = NSMakeRect(frame.origin.x + 1.0f, frame.origin.y, frame.size.width - 1.0f, frame.size.height);
    mainIconTrackingRectTag = [self addTrackingRect: trackingRect
                                              owner: self
                                           userData: nil
                                       assumeInside: NO];
    mainIconTrackingRectTagIsValid = TRUE;
    NSLog(@"setupTrackingRect: Added main tracking rectangle (%f,%f, %f, %f) for MainIconView",
          trackingRect.origin.x, trackingRect.origin.y, trackingRect.size.width, trackingRect.size.height);
}

-(void)drawRect:(NSRect)rect {
    NSStatusItem * statusI = [_appDelegate item];
    BOOL menuIsOpen = [_appDelegate menuIsOpen];
    [statusI drawStatusBarBackgroundInRect: rect withHighlight: menuIsOpen];
    [super drawRect: rect];
}


-(id)initWithFrame:(NSRect) frame {
    
    self = [super initWithFrame: frame];
    if (self) {
        mainIconTrackingRectTagIsValid = FALSE;
        [self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
    }
    
    return self;
}

-(void) dealloc {
    
    [self removeTrackingRectangle];
    [self unregisterDraggedTypes];
    [_appDelegate mouseExitedMainIcon:self event:nil];
    
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

    NSLog(@"mouseDown");
    [self performSelectorOnMainThread: @selector(mouseDownMainThread:) withObject: theEvent waitUntilDone: NO];
    [super mouseDown:theEvent];
}

-(void)mouseUp:(NSEvent *)theEvent {
    [super mouseUp:theEvent];
}

@end
