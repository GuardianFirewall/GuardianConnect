//
//  GCWindow.h
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GCWindowDelegate <NSObject>

-(void)mouseEnteredAlertsWindow:(id)control event:(NSEvent *)theEvent;
-(void)mouseExitedAlertsWindow:(id)control event:(NSEvent *)theEvent;
-(void)doubleClickTriggered:(id)control event:(NSEvent *)theEvent;
- (void)removeAlertObserver;

@end

@interface GCWindow : NSPanel
@property (weak) id <GCWindowDelegate> appDelegate;
@property BOOL shownManually;
@property NSTrackingRectTag trackingRectTag;
@property NSTimeInterval windowLastClickTime;
@property (weak) IBOutlet NSTextField *expandTextField;
-(void)showExpandText;
-(void)hideExpandText;
@end

NS_ASSUME_NONNULL_END
