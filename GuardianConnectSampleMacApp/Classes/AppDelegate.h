//
//  AppDelegate.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCSubscriptionManager.h"

typedef NS_ENUM(NSInteger, GRDButtonType) {
    GRDButtonTypeTotalAlerts = 10,
    GRDButtonTypeDataTracker,
    GRDButtonTypeLocationTracker,
    GRDButtonTypeMailTracker,
    GRDButtonTypePageHijacker,
};


@interface AppDelegate : NSObject <NSApplicationDelegate, GCSubscriptionManagerDelegate>

@property (nonatomic, strong) NSStatusItem *item;
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSButton *onDemandCheckbox;
@property (nonatomic, strong) NSTimer *eventRefreshTimer;
@property (weak) IBOutlet NSWindow *alertsWindow;
@property (weak) IBOutlet NSButton *dataTrackerButton;
@property (weak) IBOutlet NSButton *locationTrackerButton;
@property (weak) IBOutlet NSButton *mailTrackerButton;
@property (weak) IBOutlet NSButton *pageHijackerButton;
@property (weak) IBOutlet NSButton *totalAlertsButton;
@property (weak) IBOutlet NSArrayController *alertsArrayController;
@property (weak) IBOutlet NSTableView *alertsTableView;

- (IBAction)login:(id)sender;
- (IBAction)createVPNConnection:(id)sender;
- (IBAction)clearVPNSettings:(id)sender;
- (IBAction)spoofReceiptData:(id)sender;
- (IBAction)refreshEventData:(id)sender;
- (IBAction)showAlertsWindow:(id)sender;
- (IBAction)toggleAlertFilter:(id)sender;
@end

