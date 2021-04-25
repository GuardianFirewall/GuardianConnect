//
//  AppDelegate.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCSubscriptionManager.h"
#import "GCImageView.h"
#import "GCWindow.h"

typedef NS_ENUM(NSInteger, GRDButtonType) {
    GRDButtonTypeTotalAlerts = 10,
    GRDButtonTypeDataTracker,
    GRDButtonTypeLocationTracker,
    GRDButtonTypeMailTracker,
    GRDButtonTypePageHijacker,
};


@interface AppDelegate : NSObject <NSApplicationDelegate, GCSubscriptionManagerDelegate, NSMenuDelegate, GCImageViewDelegate, GCWindowDelegate>

@property (nonatomic, strong) NSStatusItem *item;
@property (nonatomic, strong) NSMenu *menu;
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSButton *onDemandCheckbox;
@property (nonatomic, strong) NSTimer *eventRefreshTimer;
@property (weak) IBOutlet GCWindow *alertsWindow;
@property (weak) IBOutlet NSButton *dataTrackerButton;
@property (weak) IBOutlet NSButton *locationTrackerButton;
@property (weak) IBOutlet NSButton *mailTrackerButton;
@property (weak) IBOutlet NSButton *pageHijackerButton;
@property (weak) IBOutlet NSButton *totalAlertsButton;
@property (weak) IBOutlet NSArrayController *alertsArrayController;
@property (weak) IBOutlet NSTableView *alertsTableView;
@property (weak) IBOutlet NSScrollView *tableContainerView;
@property NSMenuItem *regionPickerMenuItem;
@property BOOL isMouseOverStatusIcon;
@property BOOL isMouseOverAlertsWindow;
@property BOOL menuIsOpen;

- (IBAction)login:(id)sender;
- (IBAction)createVPNConnection:(id)sender;
- (IBAction)clearVPNSettings:(id)sender;
- (IBAction)spoofReceiptData:(id)sender;
- (IBAction)refreshEventData:(id)sender;
- (IBAction)showAlertsWindow:(id)sender;
- (IBAction)toggleAlertFilter:(id)sender;
- (void)removeAlertObserver;
@end

