//
//  MainMenuController.m
//  Guardian
//
//  Created by Kevin Bradley on 4/26/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#define EVENT_REFRESH_INTERVAL 30.0
#define ALERTS_DISPLAY_DELAY 0.5

#import "MainMenuController.h"
#import <GuardianConnect/GuardianConnectMac.h>
#import "NSColor+Additions.h"
#import "GRDEvent.h"
#import "NSObject+Extras.h"


typedef NS_ENUM(NSInteger, GRDButtonType) {
    GRDButtonTypeTotalAlerts = 10,
    GRDButtonTypeDataTracker,
    GRDButtonTypeLocationTracker,
    GRDButtonTypeMailTracker,
    GRDButtonTypePageHijacker,
};

@interface MainMenuController ()

@property (nonatomic, strong) NSDictionary *_latestStats;
@property (nonatomic, strong) NSArray *_events;
@property NSInteger _alertTotal;
@property NSInteger _dataTotal;
@property NSInteger _mailTotal;
@property NSInteger _pageTotal;
@property NSInteger _locationTotal;
@property NSPredicate *filterPredicate;
@property GCImageView *imageView;
@property BOOL expanded;
@property NSArray *_currentHosts;
@property NSArray *_regions;
@property NSArray *regionMenuItems;
@property NSArray <GRDRegion *> *regions;
@property GRDRegion *_localRegion;
@property (weak) IBOutlet NSWindow *window;
@end

@implementation MainMenuController

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu == _menu){
        _menuIsOpen = true;
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    if (menu == _menu){
        _menuIsOpen = false;
    }
}

/// Array of buttons on alertWindow used to invert button state when choosing each respective button
- (NSArray <NSButton *>*)alertButtons {
    return @[self.totalAlertsButton,
             self.locationTrackerButton,
             self.pageHijackerButton,
             self.dataTrackerButton,
             self.mailTrackerButton];
}

/// Invert the rest of the buttons states dependent on which was just selected.
- (void)invertButtons:(NSButton *)button {
    [[self alertButtons] enumerateObjectsUsingBlock:^(NSButton * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj == button){
            [obj setState:NSControlStateValueOn];
        } else {
            [obj setState:NSControlStateValueOff];
        }
    }];
}


/// Action triggered when any of the buttons are selected on the Alerts Window
- (IBAction)toggleAlertFilter:(NSButton *)sender {
    @weakify(self);
    GRDButtonType type = [sender tag];
    switch (type) {
        case GRDButtonTypeTotalAlerts:
            _filterPredicate = nil;
            break;
        
        case GRDButtonTypeDataTracker:
            _filterPredicate = [NSPredicate predicateWithFormat:@"title == 'Data Tracker'"];
            break;
            
        case GRDButtonTypeMailTracker:
            _filterPredicate = [NSPredicate predicateWithFormat:@"title == 'Mail Tracker'"];
            break;
        
        case GRDButtonTypeLocationTracker:
            _filterPredicate = [NSPredicate predicateWithFormat:@"title == 'Location Tracker'"];
            break;
            
        case GRDButtonTypePageHijacker:
            _filterPredicate = [NSPredicate predicateWithFormat:@"title == 'Page Hijacker'"];
            break;
            
        default:
            break;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self invertButtons:sender];
        if (self_weak_.filterPredicate){
            [self.alertsArrayController setContent:[self_weak_._events filteredArrayUsingPredicate:self_weak_.filterPredicate]];
        } else {
            [self.alertsArrayController setContent:self_weak_._events];
        }
        [self updateAlertWindow];
    });
}

- (void)removeAlertObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:self.alertsWindow.contentView];
}

- (void)addAlertObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowResized:) name:NSViewFrameDidChangeNotification object:self.alertsWindow.contentView];
}

- (void)windowResized:(NSNotification *)n {
    NSView *view = (NSView *)[n object];
    CGFloat height = [view frame].size.height;
    if (height <= 240){
        [self hideAlertsTableView];
    } else {
        [self showAlertsTableView];
    }
}

- (void)hideAlertsTableView {
    [self.tableContainerView setHidden:true];
    [self.tableContainerView setAlphaValue:0.0];
}

- (void)showAlertsTableView {
    [self.tableContainerView setHidden:false];
    [self.tableContainerView setAlphaValue:1.0];
    [self.alertsWindow hideExpandText];
}


/// whether or not the user is logged in to a pro account
- (BOOL)isLoggedIn {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"userLoggedIn"];
}


/// Is there an active VPN connection open
- (BOOL)isConnected {
    NEVPNStatus status = [[[NEVPNManager sharedManager] connection] status];
    return (status == NEVPNStatusConnected);
}

#pragma mark Menu Management

- (NSString *)currentDisplayHostname {
    GRDRegion *selected = [[GRDVPNHelper sharedInstance] selectedRegion];
    if (selected){
        return selected.displayName;
    } else {
        return [[NSUserDefaults standardUserDefaults] valueForKey:kGRDVPNHostLocation];
    }
}

/// Title for the VPN connection menu item
- (NSString *)connectButtonTitle {
    if ([self isConnected]){
        return [NSString stringWithFormat:@"Disconnect (%@) VPN", [self currentDisplayHostname]];
    }
    return @"Connect VPN";
}

/// Title of the pro menu item
- (NSString *)proMenuTitle {
    if ([self isLoggedIn]){
        return @"Pro Logout";
    }
    return @"Pro Login";
}

/// Updates the G menu image dependent on dark / light / pro and connected states.
- (void)updateMenuImage {
    NSString *defaultImageName = @"Little_G.png";
    if ([NSColor darkMode]){
        defaultImageName = @"White_G.png";
    }
    if ([self isConnected]){
        defaultImageName = @"Little_G_Dark.png";
        if ([GRDVPNHelper proMode]){
            defaultImageName = @"Little_G_Pro_Dark.png";
        }
    }
    NSImage *image = [NSImage imageNamed:defaultImageName];
    self.imageView.image = image;

}

- (void)refreshMenu {
    self.menu = [self freshMenu];
    self.item.menu = self.menu;
}

/// Create the actual menu, this is recreated routinely to refresh the contents, could probably be done more 'properly' but this will do for now.
- (void)createMenu {
    if (self.item){
        [self refreshMenu];
        [self updateMenuImage];
        return;
    }
    CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:thickness];
    self.imageView = [[GCImageView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 24.0, 22.0)];
    self.imageView.appDelegate = self;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self.item setView:self.imageView];
#pragma clang diagnostic pop
    [self.imageView createTrackingRect];
    [self refreshMenu];
    [self updateMenuImage];
}

- (NSMenu *)freshMenu {
    [self createAlertTotals];
    if (!self.menu){
        self.menu = [NSMenu new];
    } else {
        [self.menu removeAllItems];
    }
    //NSMenu *menu = [NSMenu new];
    //self.menu.delegate = self;
    NSMenuItem *proLogin = [[NSMenuItem alloc] initWithTitle:[self proMenuTitle] action:@selector(showLoginWindow:) keyEquivalent:@""];
    [self.menu addItem:proLogin];
    if ([GRDVPNHelper isPayingUser]){
        //Only add the settings to enable the VPN if we are currently a paying user
        NSMenuItem *enableVPN = [[NSMenuItem alloc] initWithTitle:[self connectButtonTitle] action:@selector(createVPNConnection:) keyEquivalent:@""];
        [self.menu addItem:enableVPN];
        NSMenuItem *clearVPNSettings = [[NSMenuItem alloc] initWithTitle:@"Clear VPN Settings" action:@selector(clearVPNSettings:) keyEquivalent:@""];
        [self.menu addItem:clearVPNSettings];
    }
    NSMenuItem *spoofReceipt = [[NSMenuItem alloc] initWithTitle:@"Spoof Receipt" action:@selector(spoofReceiptData:) keyEquivalent:@""];
    [self.menu addItem:spoofReceipt];
    
    NSMenuItem *quitApplication = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];
    [self.menu addItem:quitApplication];
    [self.menu addItem:[NSMenuItem separatorItem]];
    if ([self isConnected]){
        
        //Only add the total alerts menu if we are currently connected
        NSString *totalString = [NSString stringWithFormat:@"Total Alerts: %lu", __alertTotal];
        NSString *dataTrackerString = [NSString stringWithFormat:@" %lu", __dataTotal];
        NSString *locationTrackerString = [NSString stringWithFormat:@" %lu", __locationTotal];
        NSString *mailTrackerString = [NSString stringWithFormat:@" %lu", __mailTotal];
        NSString *pageHijackerString = [NSString stringWithFormat:@" %lu", __pageTotal];
        [self.dataTrackerButton setTitle:dataTrackerString];
        [self.locationTrackerButton setTitle:locationTrackerString];
        [self.pageHijackerButton setTitle:pageHijackerString];
        [self.mailTrackerButton setTitle:mailTrackerString];
        [self.totalAlertsButton setTitle:totalString];
        NSMenuItem *totalAlertsBlocked = [[NSMenuItem alloc] initWithTitle:totalString action:nil keyEquivalent:@""];
        [self.menu addItem:totalAlertsBlocked];
        NSMenuItem *alertsView = [[NSMenuItem alloc] initWithTitle:@"Show Alerts" action:@selector(showAlertsWindow:) keyEquivalent:@""];
        [self.menu addItem:alertsView];
        
        if ([GRDVPNHelper proMode]){
            if (self.regionMenuItems && !self.regionPickerMenuItem){
                self.regionPickerMenuItem = [[NSMenuItem alloc] initWithTitle:@"Region Selection" action:nil keyEquivalent:@""];
                [self.regionPickerMenuItem setSubmenu:[NSMenu new]];
                [[self.regionPickerMenuItem submenu] setItemArray:self.regionMenuItems];
                [self.menu addItem:self.regionPickerMenuItem];
            } else if (self.regionPickerMenuItem){
                if ([self.menu.itemArray containsObject:self.regionPickerMenuItem]){
                    [self.menu removeItem:self.regionPickerMenuItem];
                }
                [self.menu addItem:self.regionPickerMenuItem];
            }
        }
    }
    return self.menu;
}

/// Can be used to 'spoof' receipt data from the iOS app, a way to login without a pro account and to also test/audit some of that workflow.
- (IBAction)spoofReceiptData:(id)sender {
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setMessage:@"This receipt data will be sent in place of our actual app store receipt data to attempt to create a VPN connection.\nUsing active iOS details for further POC"];
    [op setCanChooseFiles:TRUE];
    [op setCanChooseDirectories:FALSE];
    [op setAllowsMultipleSelection:FALSE];
    if ([op runModal] == NSModalResponseOK)
    {
        NSURL* fileNameOpened = [[op URLs] objectAtIndex:0];
        NSData *receiptData = [NSData dataWithContentsOfURL:fileNameOpened];
        //NSString *receiptString = [receiptData base64EncodedStringWithOptions:0];
        //self.textView.string = receiptString;
        //[self validateReceiptPressed:nil];
        [[NSUserDefaults standardUserDefaults] setValue:receiptData forKey:@"spoofedReceiptData"];
        [[GCSubscriptionManager sharedInstance]setDelegate:self];
        [[GCSubscriptionManager sharedInstance] verifyReceipt];
    }

}

#pragma mark GCSubscriberManager delegate
- (void)handleValidationSuccess {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createMenu];
    });
}


#pragma mark Menu Actions

/// Action called when '[Dis]connect VPN' menu item is chosen
- (IBAction)createVPNConnection:(id)sender {
    
    if (kCFCoreFoundationVersionNumber <= 1575.401){
        [self showMojaveIncompatibleAlert];
        return;
    }
    // If we are already connected, disconnect and return
    if ([self isConnected]){
        [[GRDVPNHelper sharedInstance] disconnectVPN];
        return;
    }
    
    if ([GRDVPNHelper activeConnectionPossible]){
        GRDLog(@"activeConnectionPossible!!");
        [[GRDVPNHelper sharedInstance] setOnDemand:self.onDemandCheckbox.state];
        [[GRDVPNHelper sharedInstance] configureAndConnectVPNWithCompletion:^(NSString * _Nullable message, GRDVPNHelperStatusCode status) {
            GRDLog(@"message: %@", message);
        }];
    } else {
        [[GRDVPNHelper sharedInstance] configureFirstTimeUserPostCredential:^{
            GRDLog(@"post cred!");
        } completion:^(BOOL success, NSString * _Nonnull errorMessage) {
            GRDLog(@"finished connection success: %d error: %@", success, errorMessage);
        }];
    }
}

/// Kill the application, note, this will NOT kill the VPN connection.
- (void)quit:(id)sender {
    exit(0);
}

/// Action called from 'Pro log[in/out]' menu item is chosen
- (void)showLoginWindow:(id)sender {
    
    //if we are currently logged in, just log out.
    if ([self isLoggedIn]){
        [self logOutUser];
        [self createMenu];
    } else {
        //not logged in. show the login window!
        [self.window makeKeyAndOrderFront:self.window];
        self.window.level = NSStatusWindowLevel;
    }
}

/// Make and process API calls necessary to log in to the a pro account
- (IBAction)login:(id)sender {
    [[GRDHousekeepingAPI new] loginUserWithEMail:self.usernameField.stringValue password:self.passwordField.stringValue completion:^(NSDictionary * _Nullable response, NSString * _Nullable errorMessage, BOOL success) {
        if (success){
            [GRDKeychain removeSubscriberCredentialWithRetries:3];
            OSStatus saveStatus = [GRDKeychain storePassword:response[kKeychainStr_PEToken] forAccount:kKeychainStr_PEToken];
            if (saveStatus != errSecSuccess) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"[authenticateUser] Failed to store PET. Aborting");
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = @"Error";
                    alert.informativeText = @"Couldn't save subscriber credential in local keychain. Please try again. If this issue persists please notify our technical support about your issue.";
                    [alert runModal];
                   
                });
                
            } else { //we were successful saving the token
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [GRDVPNHelper setIsPayingUser:TRUE];
                    [defaults setObject:[response objectForKey:@"type"] forKey:kSubscriptionPlanTypeStr];
                    [defaults setObject:[NSDate dateWithTimeIntervalSince1970:[[response objectForKey:@"pet-expires"] integerValue]] forKey:kGuardianPETokenExpirationDate];
                    [defaults removeObjectForKey:kKnownGuardianHosts];
                    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"userLoggedIn"];
                    [self.window close];
                    [self createMenu];
                });
            }
        } else { //the login failed :(
            GRDLog(@"Login failed with error: %@", errorMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                
                NSAlert *alert = [NSAlert new];
                alert.messageText = @"Error";
                alert.informativeText = errorMessage;
                [alert runModal];
            });
        }
        GRDLog(@"response: %@", response);
        
    }];
}

/// Clear local cache of currentl VPN data
- (void)clearLocalCache {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kKnownGuardianHosts];
    [defaults removeObjectForKey:housekeepingTimezonesTimestamp];
    [defaults removeObjectForKey:kKnownHousekeepingTimeZonesForRegions];
    [defaults removeObjectForKey:kGuardianAllRegions];
    [defaults removeObjectForKey:kGuardianAllRegionsTimeStamp];;
    [defaults removeObjectForKey:kGRDEAPSharedHostname];
    //[defaults removeObjectForKey:kGuardianEAPExpirationDate];
    [GRDKeychain removeGuardianKeychainItems];
    [GRDKeychain removeSubscriberCredentialWithRetries:3];
}

/// Completely log out a pro user
- (void)logOutUser {
    [self clearLocalCache];
    [GRDVPNHelper setIsPayingUser:false];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kSubscriptionPlanTypeStr];
    [[GRDVPNHelper sharedInstance] setMainCredential:nil];
    [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"userLoggedIn"];
    
}

/// Action called when Clear VPN Settings menu item is chosen
- (IBAction)clearVPNSettings:(id)sender {
    [[GRDVPNHelper sharedInstance] forceDisconnectVPNIfNecessary];
    [GRDVPNHelper clearVpnConfiguration];
    [self clearLocalCache];
}

/// An alert that is shown if we are on mojave or lower, can't work until DeviceCheck gets the heave-ho.
- (void)showMojaveIncompatibleAlert {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Error";
    alert.informativeText = @"Catalina or newer is required to use the DeviceCheck framework, currently this version of macOS is unsupported.";
    [alert runModal];
}

/// Action called when 'Show alerts' menu item is chosen
- (IBAction)showAlertsWindow:(id _Nullable)sender {
    if (![self isConnected]){
        //return;
    }
    if (sender != nil){
        NSLog(@"we got a sender, shown manually!");
        self.alertsWindow.shownManually = true;
    }
    [self.alertsWindow makeKeyAndOrderFront:nil];
    [self updateAlertWindow];
    [self addAlertObserver];
}

#pragma mark Event/Alert management

/// Creates & starts the timer to refresh the event data
- (void)startEventRefreshTimer {
    [self stopEventRefreshTimer];
    self.eventRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:EVENT_REFRESH_INTERVAL repeats:true block:^(NSTimer * _Nonnull timer) {
        [self fetchEventData];
    }];
}

/// Stop the event refresh timer if applicable
- (void)stopEventRefreshTimer {
    if (self.eventRefreshTimer){
        [self.eventRefreshTimer invalidate];
        self.eventRefreshTimer = nil;
    }
}

/// Currently unimplemented, an IBAction that can be utilized to force a data refresh
- (IBAction)refreshEventData:(id)sender {
    [self fetchEventData];
}

/// Takes the latest event data and tabulates the total
- (void)createAlertTotals {
    __dataTotal = [__latestStats[@"data-tracker-total"] integerValue];
    __locationTotal = [__latestStats[@"location-tracker-total"] integerValue];
    __mailTotal = [__latestStats[@"mail-tracker-total"] integerValue];
    __pageTotal = [__latestStats[@"page-hijacker-total"] integerValue];
    __alertTotal = __dataTotal + __locationTotal + __mailTotal + __pageTotal;
}

/// Take NSDictionaries of data from event API and turn them into GRDEvent class
- (NSArray *)processedEvents:(NSArray *)events {
    __block NSMutableArray *processed = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        GRDEvent *newEvent = [[GRDEvent alloc] initWithDictionary:obj];
        [processed addObject:newEvent];
    }];
    return processed;
}

/// Makes the necessary API calls to GRDGatewayAPI to get our current event data & counts.
- (void)fetchEventData {
    
    @weakify(self);
    if ([self isConnected]){
        
        [[GRDGatewayAPI new] getAlertTotals:^(NSDictionary * _Nullable alertTotals, BOOL success, NSString * _Nullable errorMessage) {
            //GRDLog(@"alert totals: %@", alertTotals);
            self_weak_._latestStats = alertTotals;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createAlertTotals];
                [self createMenu];
            });
        }];
        
        [[GRDGatewayAPI new] getEvents:^(NSDictionary * _Nonnull response, BOOL success, NSString * _Nonnull error) {
            
            if (success){
                self_weak_._events = [self processedEvents:response[@"alerts"]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.alertsArrayController setContent:self_weak_._events];
                });
                
            } else {
                GRDLog(@"failed to fetch events: %@", error);
            }
            //GRDLog(@"events: %@", response);
        }];
         
    }
}

- (void)_createRegionMenu {
    self.regionMenuItems = [self _theRegionMenuItems];
    [self createMenu];
}

- (NSArray *)_theRegionMenuItems {
    __block NSMutableArray *menuItems = [NSMutableArray new];
    GRDRegion *selectedRegion = [[GRDVPNHelper sharedInstance] selectedRegion];
    GRDLog(@"selected region: %@", selectedRegion);
    NSMenuItem *automaticItem = [[NSMenuItem alloc] initWithTitle:@"Automatic" action:@selector(selectRegion:) keyEquivalent:@""];
    if (!selectedRegion){
        [automaticItem setState:NSControlStateValueOn];
    } else {
        [automaticItem setState:NSControlStateValueOff];
    }
    [menuItems addObject:automaticItem];
    [menuItems addObject:[NSMenuItem separatorItem]];
    [_regions enumerateObjectsUsingBlock:^(GRDRegion * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMenuItem *currentRegion = [[NSMenuItem alloc] initWithTitle:obj.displayName action:@selector(selectRegion:) keyEquivalent:@""];
        if ([obj.regionName isEqualToString:selectedRegion.regionName]){
            [currentRegion setState:NSControlStateValueOn];
        } else {
            [currentRegion setState:NSControlStateValueOff];
        }
        [currentRegion setAssociatedValue:obj];
        [menuItems addObject:currentRegion];
    }];
    return menuItems;
}

- (void)deselectInverseItems:(NSMenuItem *)sender {
    NSArray <NSMenuItem*> *parentArray = [sender parentItem].submenu.itemArray;
    [parentArray enumerateObjectsUsingBlock:^(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj != sender){
            [obj setState:NSControlStateValueOff];
        }
    }];
}

- (void)selectRegion:(NSMenuItem *)sender {
    NSString *title = sender.title;
    [sender setState:NSControlStateValueOn];
    [self deselectInverseItems:sender];
    if ([title isEqualToString:@"Automatic"]){
        [[GRDVPNHelper sharedInstance] selectRegion:nil];
        [[GRDVPNHelper sharedInstance] configureFirstTimeUserPostCredential:nil completion:^(BOOL success, NSString * _Nonnull errorMessage) {
            
        }];
        return;
    }
    GRDRegion *region = (GRDRegion *)[sender associatedValue];
    GRDLog(@"found region: %@", region);
    [[GRDVPNHelper sharedInstance] forceDisconnectVPNIfNecessary];
    [GRDVPNHelper clearVpnConfiguration];
    [region findBestServerWithCompletion:^(NSString * _Nonnull server, NSString * _Nonnull serverLocation, BOOL success) {
        if (success){
            [[GRDVPNHelper sharedInstance] configureFirstTimeUserForHostname:server andHostLocation:serverLocation completion:^(BOOL success, NSString * _Nonnull errorMessage) {
                GRDLog(@"success: %d", success);
                if (success){
                    [[GRDVPNHelper sharedInstance] selectRegion:region];
                }
            }];
        }
    }];
}

/// Handle tint color changes whenever any of the vires buttons are selected
- (void)updateAlertWindow {
    CGFloat alpha = 1.0;
    if (self.totalAlertsButton.state == NSControlStateValueOff){
        alpha = 0.5;
    }
    self.totalAlertsButton.contentTintColor = [NSColor colorWithWhite:1.0 alpha:alpha];
    self.mailTrackerButton.contentTintColor = [NSColor mailTrackerRedSelected:self.mailTrackerButton.state];
    self.locationTrackerButton.contentTintColor = [NSColor locationTrackerGreenSelected:self.locationTrackerButton.state];
    self.dataTrackerButton.contentTintColor = [NSColor dataTrackerYellowSelected:self.dataTrackerButton.state];
    self.pageHijackerButton.contentTintColor = [NSColor pageHijackerPurpleSelected:self.pageHijackerButton.state];
}

#pragma UI / Mouse management

/// Called from GCImageView mouseEntered. Traced via event tracking in said class
-(void)mouseEnteredMainIcon:(id)control event:(NSEvent *)theEvent {
    _isMouseOverStatusIcon = TRUE;
    [self showOrHideAlertsWindowsAfterDelay:ALERTS_DISPLAY_DELAY
                                  fromTimestamp:(theEvent ? [theEvent timestamp] : 0.0)
                                       selector:@selector(showAlertsFromTimerOnMainThread)];
     
}

/// Called from GCImageView mouseExited. Traced via event tracking in said class
-(void)mouseExitedMainIcon:(id)control event:(NSEvent *)theEvent {
    _isMouseOverStatusIcon = FALSE;
    [self showOrHideAlertsWindowsAfterDelay:ALERTS_DISPLAY_DELAY
                                  fromTimestamp:(theEvent ? [theEvent timestamp] : 0.0)
                                       selector:@selector(hideAlertsFromTimerOnMainThread)];
    
}

- (void)openPreferences {
    
}


/// Called for both the GCImageView and GCWindow to show alerts based on mouseEnter/exit events to show the Alerts Window
-(void)showAlertsFromTimerOnMainThread {
    if ([self isMouseOverAnyView]) {
        [self performSelectorOnMainThread:@selector(showAlertsWindow) withObject:nil waitUntilDone:FALSE];
    }
}

/// Called for both the GCImageView and GCWindow to show alerts based on mouseEnter/exit events to hide the Alerts Window
-(void)hideAlertsFromTimerOnMainThread {
    
    if (![self isMouseOverAnyView]) {
        [self performSelectorOnMainThread:@selector(hideAlertsWindow) withObject:nil waitUntilDone:FALSE];
    }
}

/// Called from GCWindow when the mouse enters the AlertsWindow, serves to keep it visible as necessary
-(void)mouseEnteredAlertsWindow:(id)control event:(NSEvent *)theEvent  {
    _isMouseOverAlertsWindow = TRUE;
    [self showOrHideAlertsWindowsAfterDelay:ALERTS_DISPLAY_DELAY
                              fromTimestamp:(theEvent ? [theEvent timestamp] : 0.0)
                                   selector:@selector(showAlertsFromTimerOnMainThread)];
    
}

/// Called from GCWindow when the mouse enters the AlertsWindow, serves to hide it as necessary
-(void)mouseExitedAlertsWindow:(id)control event:(NSEvent *)theEvent {
    _isMouseOverAlertsWindow = FALSE;
    [self showOrHideAlertsWindowsAfterDelay:ALERTS_DISPLAY_DELAY
                              fromTimestamp:(theEvent ? [theEvent timestamp] : 0.0)
                                   selector:@selector(hideAlertsFromTimerOnMainThread)];
    
}

- (void)toggleExpandedManually:(BOOL)manually {
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    NSRect windowFrame = self.alertsWindow.frame;
    CGFloat padding = 40;
    if (_expanded){
        windowFrame.origin.x = screenFrame.size.width - 330 - padding;//1590;
        windowFrame.origin.y = screenFrame.size.height - 200;//1000;
        windowFrame.size.width = 300;
        windowFrame.size.height = 200;
        [self hideAlertsTableView];
        _expanded = false;
    } else {
        windowFrame.origin.x = screenFrame.size.width - 649 - padding;//1271;
        windowFrame.origin.y = screenFrame.size.height - 356;//724;
        windowFrame.size.width = 619;
        windowFrame.size.height = 356;
        _expanded = true;
        [self showAlertsTableView];
        [self.alertsWindow hideExpandText];
    }
    CGFloat width = screenFrame.size.width - windowFrame.origin.x;
    CGFloat height = screenFrame.size.height - windowFrame.origin.y;
    NSLog(@"width: %.1f height: %.1f", width, height);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.alertsWindow setFrame:windowFrame display:true];
        self.alertsWindow.shownManually = manually;
    });
}

- (void)doubleClickTriggered:(id)control event:(NSEvent *)theEvent {
    [self toggleExpandedManually:true];
}

/// Method for showing the alert from the mouse event code
-(void)showAlertsWindow {
    [self showAlertsWindow:nil];
}

/// Method for hiding the alert from the mouse event code
-(void)hideAlertsWindow {
    [self.alertsWindow close];
}

/// Detects whether or not the mouse is over the G status bar image OR the Alerts Window, OR if the Alerts window has been 'shown manually' ie selected from the NSMenu status item.
-(BOOL)isMouseOverAnyView {
    return _isMouseOverAlertsWindow || _isMouseOverStatusIcon || self.alertsWindow.shownManually;
}

/// Function to get absolute nano seconds from our current time
uint64_t ourAbsoluteNanoseconds(void) {
    mach_timebase_info_data_t iData;
    mach_timebase_info(&iData);
    uint64_t currentNs = (unsigned long long)mach_absolute_time() * (unsigned long long)iData.numer / (unsigned long long)iData.denom;
    return currentNs;
}

/// The actual function that shows or hides our alert view from the mouse event methods & delegates.
-(void)showOrHideAlertsWindowsAfterDelay:(NSTimeInterval)delay
                           fromTimestamp:(NSTimeInterval)timestamp
                                selector:(SEL)selector {
    NSTimeInterval triggerTimeInterval;
    if (timestamp == 0.0) {
        triggerTimeInterval = 0.1;
    } else {
        uint64_t currentNanoseconds = ourAbsoluteNanoseconds();
        NSTimeInterval currentTimeInterval = (  ((NSTimeInterval) currentNanoseconds) / 1.0e9);
        triggerTimeInterval = timestamp + delay - currentTimeInterval;
        if (triggerTimeInterval < 0.1) {
            triggerTimeInterval = 0.1;
        }
    }
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:triggerTimeInterval
                                                      target:self
                                                    selector:selector
                                                    userInfo:nil
                                                     repeats:FALSE];
    [timer setTolerance: -1.0];
}

#pragma mark Region Selection

/// Populate region data for region selection
- (void)populateRegionDataIfNecessary {
    @weakify(self);
    [[GRDServerManager new] populateTimezonesIfNecessaryWithCompletion:^(NSArray * _Nonnull regions) {
        //GRDLog(@"we got these regions: %@", regions);
        self_weak_._regions = regions;
        self_weak_.regions = [GRDRegion regionsFromTimezones:regions];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _createRegionMenu];
        });
    }];
    
}

@end