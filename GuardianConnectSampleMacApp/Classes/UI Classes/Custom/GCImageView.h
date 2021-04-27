//
//  GCImageView.h
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@protocol GCImageViewDelegate <NSObject>
-(void)mouseEnteredMainIcon:(id)control event:(NSEvent *)theEvent;
-(void)mouseExitedMainIcon:(id)control event:(NSEvent *)theEvent;
-(void)createMenu;
-(NSStatusItem *)item;
-(NSMenu *)menu;
-(BOOL)menuIsOpen;
-(void)openPreferences;
@end

@interface GCImageView : NSImageView {
    
    NSTrackingRectTag      iconTrackingRectTag; // Used to track mouseEntered and mouseExited events for alerts display
    NSTimeInterval         iconLastClickTime;   // Timestamp of last click (used to detect double-click)
    BOOL                   iconTrackingRectTagIsValid;
}
@property (weak) id <GCImageViewDelegate> appDelegate;

-(void)createTrackingRect;
-(void)removeTrackingRect;

@end

NS_ASSUME_NONNULL_END
