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
//#import "GCSubscriptionManager.h"
#import <StoreKit/StoreKit.h>
#import "GRDSubscriptionManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GRDButtonType) {
    GRDButtonTypeTotalAlerts = 10,
    GRDButtonTypeDataTracker,
    GRDButtonTypeLocationTracker,
    GRDButtonTypeMailTracker,
    GRDButtonTypePageHijacker,
};

@interface MainMenuController : NSObjectController <GCImageViewDelegate, GCWindowDelegate, NSMenuDelegate, SKProductsRequestDelegate, GRDSubscriptionDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSScrollView *tableContainerView; //used to hide/show the table view as applicable
@property (weak) IBOutlet GCWindow *alertsWindow;
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSButton *onDemandCheckbox;
@property (nullable, nonatomic, strong) NSTimer *eventRefreshTimer;
@property (nonatomic, strong) NSStatusItem *item;
@property (nonatomic, strong) NSMenu *menu;
@property (weak) IBOutlet NSTableView *alertsTableView;
@property (weak) IBOutlet NSTableView *serverTableView;
@property (weak) IBOutlet NSArrayController *alertsArrayController;
@property (weak) IBOutlet NSArrayController *serversArrayController;
@property NSMenuItem *regionPickerMenuItem;
@property BOOL isMouseOverStatusIcon;
@property BOOL isMouseOverAlertsWindow;
@property BOOL menuIsOpen;
@property BOOL expanded;
@property (weak) IBOutlet NSWindow *subscriptionWindow;

@property (weak) IBOutlet NSButton *dataTrackerButton;
@property (weak) IBOutlet NSButton *locationTrackerButton;
@property (weak) IBOutlet NSButton *mailTrackerButton;
@property (weak) IBOutlet NSButton *pageHijackerButton;
@property (weak) IBOutlet NSButton *totalAlertsButton;
@property (weak) IBOutlet NSWindow *serverSelectionWindow;

- (void)login:(id)sender;
- (void)showLoginWindow:(id)sender;
- (void)createVPNConnection:(id)sender;
- (void)clearVPNSettings:(id)sender;
- (void)refreshEventData:(id)sender;
- (void)selectRegion:(NSMenuItem *)sender;
- (void)showAlertsWindow:(id _Nullable)sender;
- (IBAction)toggleAlertFilter:(id)sender;
- (void)removeAlertObserver;
- (void)createMenu;
- (void)startEventRefreshTimer;
- (void)stopEventRefreshTimer;
- (void)updateAlertWindow;
- (void)toggleExpandedManually:(BOOL)manually;
- (void)populateRegionDataIfNecessary;
- (void)fetchEventData;
- (void)quit:(id)send;
-(void)showDeveloperItems;
-(void)hideDeveloperItems;
-(void)fetchBlacklistItems;
- (void)openPreferences:(id _Nullable)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)connect:(id)sender;
- (void)showManualServerList:(id)sender;
- (void)showSubscriptionsView:(id)sender;
- (void)restoreSubscription:(id)sender;
- (IBAction)subscribe:(id)sender;
- (IBAction)planSelected:(NSButton *)sender;
@end

NS_ASSUME_NONNULL_END
