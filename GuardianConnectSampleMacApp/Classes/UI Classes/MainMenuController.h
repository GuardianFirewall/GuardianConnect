//
//  MainMenuController.h
//  Guardian
//
//  Created by Kevin Bradley on 4/26/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCImageView.h"
#import "GCWindow.h"
#import "GCSubscriptionManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface MainMenuController : NSObjectController <GCImageViewDelegate, GCWindowDelegate, GCSubscriptionManagerDelegate, NSMenuDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSScrollView *tableContainerView;
@property (weak) IBOutlet GCWindow *alertsWindow;
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSButton *onDemandCheckbox;
@property (nullable, nonatomic, strong) NSTimer *eventRefreshTimer;
@property (nonatomic, strong) NSStatusItem *item;
@property (nonatomic, strong) NSMenu *menu;
@property (weak) IBOutlet NSTableView *alertsTableView;
@property (weak) IBOutlet NSArrayController *alertsArrayController;
@property NSMenuItem *regionPickerMenuItem;
@property BOOL isMouseOverStatusIcon;
@property BOOL isMouseOverAlertsWindow;
@property BOOL menuIsOpen;

@property (weak) IBOutlet NSButton *dataTrackerButton;
@property (weak) IBOutlet NSButton *locationTrackerButton;
@property (weak) IBOutlet NSButton *mailTrackerButton;
@property (weak) IBOutlet NSButton *pageHijackerButton;
@property (weak) IBOutlet NSButton *totalAlertsButton;

- (IBAction)login:(id)sender;
- (void)showLoginWindow:(id)sender;
- (IBAction)createVPNConnection:(id)sender;
- (IBAction)clearVPNSettings:(id)sender;
- (IBAction)spoofReceiptData:(id)sender;
- (IBAction)refreshEventData:(id)sender;
- (void)selectRegion:(NSMenuItem *)sender;
- (IBAction)showAlertsWindow:(id _Nullable)sender;
- (IBAction)toggleAlertFilter:(id)sender;
- (void)removeAlertObserver;
- (void)createMenu;
- (void)clearLocalCache;
- (void)startEventRefreshTimer;
- (void)stopEventRefreshTimer;
- (void)updateAlertWindow;
- (void)toggleExpandedManually:(BOOL)manually;
- (void)populateRegionDataIfNecessary;
- (void)fetchEventData;
- (void)quit:(id)send;
@end

NS_ASSUME_NONNULL_END
