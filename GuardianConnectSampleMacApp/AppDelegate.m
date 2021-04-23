//
//  AppDelegate.m
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <GuardianConnect/GuardianConnectMac.h>


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

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
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (BOOL)darkMode {

    NSString *interfaceStyle = [[NSUserDefaults standardUserDefaults] valueForKey:@"AppleInterfaceStyle"];
    if ([interfaceStyle isEqualToString:@"Dark"]){
        return true;
    }
    return false;
    
}
#pragma clang diagnostic pop

- (NSString *)connectButtonTitle {
    NEVPNStatus status = [[[NEVPNManager sharedManager] connection] status];
    switch (status) {
        case NEVPNStatusConnected:
            return @"Disconnect VPN";
        case NEVPNStatusDisconnected:
            return @"Connect VPN";
            
        default:
            return @"Connect VPN";
    }
}

- (void)createMenu {
    CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
    NSMenu *menu = [NSMenu new];
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:thickness];
     self.item.image = [NSImage imageNamed:@"Little_G.png"];
    if ([self darkMode]){
        self.item.image = [NSImage imageNamed:@"White_G.png"];
    }
    NSMenuItem *enableVPN = [[NSMenuItem alloc] initWithTitle:[self connectButtonTitle] action:@selector(createVPNConnection:) keyEquivalent:@""];
    [menu addItem:enableVPN];
    NSMenuItem *clearVPNSettings = [[NSMenuItem alloc] initWithTitle:@"Clear VPN Settings" action:@selector(clearKeychain:) keyEquivalent:@""];
    [menu addItem:clearVPNSettings];
    NSMenuItem *spoofReceipt = [[NSMenuItem alloc] initWithTitle:@"Spoof Receipt" action:@selector(spoofReceiptData:) keyEquivalent:@""];
    [menu addItem:spoofReceipt];
    self.item.menu = menu;
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
            NSString *dataTrackerTotal = alertTotals[@"data-tracker-total"];
            NSString *locationTrackerTotal = alertTotals[@"location-tracker-total"];
            NSString *mailTrackerTotal = alertTotals[@"mail-tracker-total"];
            NSString *pageHijackerTotal = alertTotals[@"page-hijacker-total"];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.dataTrackerField.stringValue = dataTrackerTotal;
                self.locationTrackerField.stringValue = locationTrackerTotal;
                self.pageHijackerField.stringValue = pageHijackerTotal;
                self.mailTrackerField.stringValue = mailTrackerTotal;
            });
        }];
        /*
        [[GRDGatewayAPI new] getEvents:^(NSDictionary * _Nonnull response, BOOL success, NSString * _Nonnull error) {
            GRDLog(@"events: %@", response);
        }];
         */
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
                });
            }
        } else {
            GRDLog(@"Login failed with error: %@", errorMessage);
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
    [GRDVPNHelper setIsPayingUser:false];
    [GRDKeychain removeGuardianKeychainItems];
    [GRDKeychain removeSubscriberCredentialWithRetries:3];
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
