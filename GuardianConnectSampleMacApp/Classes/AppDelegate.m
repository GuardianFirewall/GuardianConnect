//
//  AppDelegate.m
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

//how often event API gets hit, currently just on an 30 second interval loop
#define EVENT_REFRESH_INTERVAL 30.0

#import "AppDelegate.h"
#import <GuardianConnect/GuardianConnectMac.h>
#import "GRDEvent.h"
#import "NSColor+Additions.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSDictionary *_latestStats;
@property (nonatomic, strong) NSArray *_events;
@property NSInteger _alertTotal;
@property NSInteger _dataTotal;
@property NSInteger _mailTotal;
@property NSInteger _pageTotal;
@property NSInteger _locationTotal;
@property NSPredicate *filterPredicate;

@end

@implementation AppDelegate

#pragma mark Application Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [[GRDVPNHelper sharedInstance] _loadCredentialsFromKeychain];
    
    // This needs to be done as early as possible in the application lifecycle, why not now? :)
    [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (!error){
            [self addVPNObserver];
            [self handleConnectionStatus:[[[NEVPNManager sharedManager] connection] status]];
        } else {
            GRDLog(@"error: %@", error);
        }
    }];
    [self createMenu];
    if (![GRDVPNHelper isPayingUser]){
        [self.window makeKeyAndOrderFront:nil];
    }
    [self.totalAlertsButton setState:NSControlStateValueOn];
    [self updateAlertWindow];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark Misc

/// whether or not the OS is currently in darkMode
- (BOOL)darkMode {

    NSString *interfaceStyle = [[NSUserDefaults standardUserDefaults] valueForKey:@"AppleInterfaceStyle"];
    if ([interfaceStyle isEqualToString:@"Dark"]){
        return true;
    }
    return false;
    
}

#pragma mark VPN Management

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

/// Title for the VPN connection menu item
- (NSString *)connectButtonTitle {
    if ([self isConnected]){
            return @"Disconnect VPN";
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
    if ([self darkMode]){
        defaultImageName = @"White_G.png";
    }
    if ([self isConnected]){
        defaultImageName = @"Little_G_Dark.png";
        if ([GRDVPNHelper proMode]){
            defaultImageName = @"Little_G_Pro_Dark.png";
        }
    }
    NSImage *image = [NSImage imageNamed:defaultImageName];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self.item.image = image;
#pragma clang diagnostic pop
}

/// Create the actual menu, this is recreated routinely to refresh the contents, could probably be done more 'properly' but this will do for now.
- (void)createMenu {
    if (self.item){
        self.item.menu = [self freshMenu];
        return;
    }
    CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
    //NSMenu *menu = [NSMenu new];
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:thickness];
    NSMenu *menu = [self freshMenu];
    self.item.menu = menu;
    [self updateMenuImage];
}

- (NSMenu *)freshMenu {
    [self createAlertTotals];
    NSMenu *menu = [NSMenu new];
    NSMenuItem *proLogin = [[NSMenuItem alloc] initWithTitle:[self proMenuTitle] action:@selector(showLoginWindow:) keyEquivalent:@""];
    [menu addItem:proLogin];
    if ([GRDVPNHelper isPayingUser]){
        //Only add the settings to enable the VPN if we are currently a paying user
        NSMenuItem *enableVPN = [[NSMenuItem alloc] initWithTitle:[self connectButtonTitle] action:@selector(createVPNConnection:) keyEquivalent:@""];
        [menu addItem:enableVPN];
        NSMenuItem *clearVPNSettings = [[NSMenuItem alloc] initWithTitle:@"Clear VPN Settings" action:@selector(clearVPNSettings:) keyEquivalent:@""];
        [menu addItem:clearVPNSettings];
    }
    NSMenuItem *spoofReceipt = [[NSMenuItem alloc] initWithTitle:@"Spoof Receipt" action:@selector(spoofReceiptData:) keyEquivalent:@""];
    [menu addItem:spoofReceipt];
    
    NSMenuItem *quitApplication = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];
    [menu addItem:quitApplication];
    [menu addItem:[NSMenuItem separatorItem]];
    //self.item.menu = menu;
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
        [menu addItem:totalAlertsBlocked];
        NSMenuItem *alertsView = [[NSMenuItem alloc] initWithTitle:@"Show Alerts" action:@selector(showAlertsWindow:) keyEquivalent:@""];
        [menu addItem:alertsView];
        
        /*
        NSMenuItem *dataTrackerBlocked = [[NSMenuItem alloc] initWithTitle:dataTrackerString action:nil keyEquivalent:@""];
        [menu addItem:dataTrackerBlocked];
        NSMenuItem *locationTrackerBlocked = [[NSMenuItem alloc] initWithTitle:locationTrackerString action:nil keyEquivalent:@""];
        [menu addItem:locationTrackerBlocked];
        NSMenuItem *mailTrackerBlocked = [[NSMenuItem alloc] initWithTitle:mailTrackerString action:nil keyEquivalent:@""];
        [menu addItem:mailTrackerBlocked];
        NSMenuItem *pageHijackerBlocked = [[NSMenuItem alloc] initWithTitle:pageHijackerString action:nil keyEquivalent:@""];
        [menu addItem:pageHijackerBlocked];
         */
    }
    
    return menu;
}

#pragma mark Menu Actions

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
                    [GRDVPNHelper setIsPayingUser:YES];
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
- (IBAction)showAlertsWindow:(id)sender {
    [self.alertsWindow makeKeyAndOrderFront:nil];
    [self updateAlertWindow];
}

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

#pragma mark Alert window management

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

#pragma mark GCSubscriberManager delegate
- (void)handleValidationSuccess {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createMenu];
    });
}

#pragma mark VPN & UI state management

- (void)addVPNObserver {
    [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *notif) {
        if ([notif.object isMemberOfClass:NEVPNConnection.class]){
            [self handleConnectionStatus:[[[NEVPNManager sharedManager] connection] status]];
        }
    }];
}

- (void)handleConnectionStatus:(NEVPNStatus)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (status) {
            case NEVPNStatusConnected:{
                [self showConnectedStateUI];
                break;
                
            case NEVPNStatusDisconnected:
            case NEVPNStatusInvalid:
                [self showDisconnectedStateUI];
                break;
                
            case NEVPNStatusDisconnecting:
                [self showDisconnectingStateUI];
                break;
                
            case NEVPNStatusConnecting:
            case NEVPNStatusReasserting:
                [self showConnectingStateUI];
                break;
                
            default:
                break;
            }
        }
    });
}

- (void)showConnectedStateUI {
    [self fetchEventData]; //get data immediately, then start the timeer
    [self startEventRefreshTimer];
    [self createMenu];
}

- (void)showDisconnectedStateUI {
    [self stopEventRefreshTimer];
    [self createMenu];
}

- (void)showDisconnectingStateUI {
}

- (void)showConnectingStateUI {
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

@end
