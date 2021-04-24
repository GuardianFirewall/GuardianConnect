//
//  AppDelegate.m
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

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

- (BOOL)isLoggedIn {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"userLoggedIn"];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    GRDCredential *main = [GRDCredentialManager mainCredentials];
    if (main || ([GRDVPNHelper isPayingUser])){
        self.createButton.enabled = true;
    }
    [[GRDVPNHelper sharedInstance] setMainCredential:main];
    
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

- (BOOL)darkMode {

    NSString *interfaceStyle = [[NSUserDefaults standardUserDefaults] valueForKey:@"AppleInterfaceStyle"];
    if ([interfaceStyle isEqualToString:@"Dark"]){
        return true;
    }
    return false;
    
}

- (BOOL)isConnected {
    NEVPNStatus status = [[[NEVPNManager sharedManager] connection] status];
    return (status == NEVPNStatusConnected);
}

- (NSString *)connectButtonTitle {
    if ([self isConnected]){
            return @"Disconnect VPN";
    }
    return @"Connect VPN";
}

- (NSString *)proMenuTitle {
    if ([self isLoggedIn]){
        return @"Pro Logout";
    }
    return @"Pro Login";
}

- (void)selectInverted:(GRDButtonType)type {

        switch (type) {
            case GRDButtonTypeTotalAlerts:
                [self.totalAlertsButton setState:NSControlStateValueOn];
                [self.locationTrackerButton setState:NSControlStateValueOff];
                [self.pageHijackerButton setState:NSControlStateValueOff];
                [self.mailTrackerButton setState:NSControlStateValueOff];
                [self.dataTrackerButton setState:NSControlStateValueOff];
                break;
            
            case GRDButtonTypeDataTracker:
                [self.totalAlertsButton setState:NSControlStateValueOff];
                [self.locationTrackerButton setState:NSControlStateValueOff];
                [self.pageHijackerButton setState:NSControlStateValueOff];
                [self.mailTrackerButton setState:NSControlStateValueOff];
                [self.dataTrackerButton setState:NSControlStateValueOn];
                break;
                
            case GRDButtonTypeMailTracker:
                [self.totalAlertsButton setState:NSControlStateValueOff];
                [self.locationTrackerButton setState:NSControlStateValueOff];
                [self.pageHijackerButton setState:NSControlStateValueOff];
                [self.mailTrackerButton setState:NSControlStateValueOn];
                [self.dataTrackerButton setState:NSControlStateValueOff];
                break;
            
            case GRDButtonTypeLocationTracker:
                [self.totalAlertsButton setState:NSControlStateValueOff];
                [self.locationTrackerButton setState:NSControlStateValueOn];
                [self.pageHijackerButton setState:NSControlStateValueOff];
                [self.mailTrackerButton setState:NSControlStateValueOff];
                [self.dataTrackerButton setState:NSControlStateValueOff];
                break;
                
            case GRDButtonTypePageHijacker:
                [self.totalAlertsButton setState:NSControlStateValueOff];
                [self.locationTrackerButton setState:NSControlStateValueOff];
                [self.pageHijackerButton setState:NSControlStateValueOn];
                [self.mailTrackerButton setState:NSControlStateValueOff];
                [self.dataTrackerButton setState:NSControlStateValueOff];
                break;
                
            default:
                break;
        }
}

- (IBAction)toggleAlertFilter:(NSButton *)sender {
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
        [self selectInverted:type];
        if (_filterPredicate){
            [self.alertsArrayController setContent:[__events filteredArrayUsingPredicate:_filterPredicate]];
        } else {
            [self.alertsArrayController setContent:__events];
        }
        [self updateAlertWindow];
    });
}

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

- (void)createMenu {
    [self createAlertTotals];
    CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
    NSMenu *menu = [NSMenu new];
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:thickness];
    self.item.image = [NSImage imageNamed:@"Little_G.png"];
    if ([self darkMode]){
        self.item.image = [NSImage imageNamed:@"White_G.png"];
    }
    NSMenuItem *proLogin = [[NSMenuItem alloc] initWithTitle:[self proMenuTitle] action:@selector(showLoginWindow:) keyEquivalent:@""];
    [menu addItem:proLogin];
    if ([GRDVPNHelper isPayingUser]){
        NSMenuItem *enableVPN = [[NSMenuItem alloc] initWithTitle:[self connectButtonTitle] action:@selector(createVPNConnection:) keyEquivalent:@""];
        [menu addItem:enableVPN];
        NSMenuItem *clearVPNSettings = [[NSMenuItem alloc] initWithTitle:@"Clear VPN Settings" action:@selector(clearKeychain:) keyEquivalent:@""];
        [menu addItem:clearVPNSettings];
    }
    NSMenuItem *spoofReceipt = [[NSMenuItem alloc] initWithTitle:@"Spoof Receipt" action:@selector(spoofReceiptData:) keyEquivalent:@""];
    [menu addItem:spoofReceipt];
    
    NSMenuItem *quitApplication = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];
    [menu addItem:quitApplication];
    [menu addItem:[NSMenuItem separatorItem]];
    self.item.menu = menu;
    if ([self isConnected]){
        //NSString *dataTrackerTotal = __latestStats[@"data-tracker-total"];
        //NSString *locationTrackerTotal = __latestStats[@"location-tracker-total"];
        //NSString *mailTrackerTotal = __latestStats[@"mail-tracker-total"];
        //NSString *pageHijackerTotal = __latestStats[@"page-hijacker-total"];
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
        NSMenuItem *totalAlertsBlocked = [[NSMenuItem alloc] initWithTitle:dataTrackerString action:nil keyEquivalent:@""];
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
        self.item.image = [NSImage imageNamed:@"Little_G_Dark.png"];
        if ([GRDVPNHelper proMode]){
           self.item.image = [NSImage imageNamed:@"Little_G_Pro_Dark.png"];
        }
    }
}

- (void)quit:(id)sender {
    exit(0);
}

- (void)showLoginWindow:(id)sender {
    
    if ([self isLoggedIn]){
        [self logOutUser];
        [self createMenu];
    } else {
        [self.window makeKeyAndOrderFront:self.window];
        self.window.level = NSStatusWindowLevel;
    }
}

- (void)startEventRefreshTimer {
    [self stopEventRefreshTimer];
    self.eventRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 repeats:true block:^(NSTimer * _Nonnull timer) {
        [self fetchEventData];
    }];
}

- (void)stopEventRefreshTimer {
    if (self.eventRefreshTimer){
        [self.eventRefreshTimer invalidate];
        self.eventRefreshTimer = nil;
    }
}

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

- (void)handleValidationSuccess {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.createButton.enabled = true;
    });
}

- (void)showConnectedStateUI {
    self.createButton.title = NSLocalizedString(@"Disconnect VPN", nil);
    [self fetchEventData]; //get data immediately, then start the timeer
    [self startEventRefreshTimer];
    [self createMenu];
}

- (void)showDisconnectedStateUI {
    self.createButton.title = NSLocalizedString(@"Connect VPN", nil);
    [self stopEventRefreshTimer];
    [self createMenu];
}

- (void)showDisconnectingStateUI {
    self.createButton.title = NSLocalizedString(@"Disconnecting VPN...", nil);
}

- (void)showConnectingStateUI {
    self.createButton.title = NSLocalizedString(@"Connecting VPN...", nil);
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

- (IBAction)refreshEventData:(id)sender {
    [self fetchEventData];
}

- (void)createAlertTotals {
    __dataTotal = [__latestStats[@"data-tracker-total"] integerValue];
    __locationTotal = [__latestStats[@"location-tracker-total"] integerValue];
    __mailTotal = [__latestStats[@"mail-tracker-total"] integerValue];
    __pageTotal = [__latestStats[@"page-hijacker-total"] integerValue];
    __alertTotal = __dataTotal + __locationTotal + __mailTotal + __pageTotal;
}

- (void)updateAlertTotals {
    
}

- (NSArray *)processedEvents:(NSArray *)events {
    __block NSMutableArray *processed = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        GRDEvent *newEvent = [[GRDEvent alloc] initWithDictionary:obj];
        [processed addObject:newEvent];
    }];
    return processed;
}

- (void)fetchEventData {
    if ([[[NEVPNManager sharedManager] connection] status] == NEVPNStatusConnected){
        
        [[GRDGatewayAPI new] getAlertTotals:^(NSDictionary * _Nullable alertTotals, BOOL success, NSString * _Nullable errorMessage) {
            //GRDLog(@"alert totals: %@", alertTotals);
            /*
             "data-tracker-total" = 122;
              "location-tracker-total" = 0;
              "mail-tracker-total" = 0;
              "page-hijacker-total" = 0;
             */
            __latestStats = alertTotals;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createAlertTotals];
                [self createMenu];
            });
        }];
        
        [[GRDGatewayAPI new] getEvents:^(NSDictionary * _Nonnull response, BOOL success, NSString * _Nonnull error) {
            
            if (success){
                __events = [self processedEvents:response[@"alerts"]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.alertsArrayController setContent:__events];
                });
                
            } else {
                GRDLog(@"failed to fetch events: %@", error);
            }
            //GRDLog(@"events: %@", response);
        }];
         
    }
}

- (void)addVPNObserver {
    [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *notif) {
        if ([notif.object isMemberOfClass:NEVPNConnection.class]){
            [self handleConnectionStatus:[[[NEVPNManager sharedManager] connection] status]];
        }
    }];
}

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
                    self.createButton.enabled = true;
                    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"userLoggedIn"];
                    [self.window close];
                    [self createMenu];
                });
            }
        } else {
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

- (void)logOutUser {
    [self clearLocalCache];
    [GRDVPNHelper setIsPayingUser:false];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kSubscriptionPlanTypeStr];
    [[GRDVPNHelper sharedInstance] setMainCredential:nil];
    [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"userLoggedIn"];
    
}

- (IBAction)clearKeychain:(id)sender {
    [[GRDVPNHelper sharedInstance] forceDisconnectVPNIfNecessary];
    [GRDVPNHelper clearVpnConfiguration];
    [self clearLocalCache];
    self.createButton.enabled = false;
    
}

- (void)showMojaveIncompatibleAlert {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Error";
    alert.informativeText = @"Catalina or newer is required to use the DeviceCheck framework, currently this version of macOS is unsupported.";
    [alert runModal];
}

- (IBAction)showAlertsWindow:(id)sender {
    [self.alertsWindow makeKeyAndOrderFront:nil];
    [self updateAlertWindow];
}

- (IBAction)createVPNConnection:(id)sender {
    
    if (kCFCoreFoundationVersionNumber <= 1575.401){
        [self showMojaveIncompatibleAlert];
        return;
    }
    
    if ([[[NEVPNManager sharedManager] connection] status] == NEVPNStatusConnected){
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

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
