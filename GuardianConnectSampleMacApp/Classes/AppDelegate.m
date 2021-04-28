//
//  AppDelegate.m
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/21/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

//how often event API gets hit, currently just on an 30 second interval loop
#define EVENT_REFRESH_INTERVAL 30.0
#define ALERTS_DISPLAY_DELAY 0.5

#import "AppDelegate.h"
#import <GuardianConnect/GuardianConnectMac.h>
#import "GRDEvent.h"
#import "NSColor+Additions.h"
#import "GRDRegion.h"
#import "NSObject+Extras.h"

@interface AppDelegate ()

@property NSArray *_currentHosts;
@property NSArray *_regions;
@property NSArray *regionMenuItems;
@property NSArray <GRDRegion *> *regions;
@property GRDRegion *_localRegion;
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
    [self.mainMenuController createMenu];
    if (![GRDVPNHelper isPayingUser]){
        [self.mainMenuController.window makeKeyAndOrderFront:nil];
    }
    [self.mainMenuController.totalAlertsButton setState:NSControlStateValueOn];
    [self.mainMenuController updateAlertWindow];
    self.mainMenuController.alertsWindow.appDelegate = self.mainMenuController;
    self.mainMenuController.expanded = true;
    [self.mainMenuController toggleExpandedManually:false];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark VPN & UI state management

/// Observes VPN connectivity to show different UI states as applicable
- (void)addVPNObserver {
    [[NSNotificationCenter defaultCenter] addObserverForName:NEVPNStatusDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *notif) {
        if ([notif.object isMemberOfClass:NEVPNConnection.class]){
            [self handleConnectionStatus:[[[NEVPNManager sharedManager] connection] status]];
        }
    }];
}

/// Matches the NEVPNStatus to the relevant connection state UI method
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

/// We are connected, currently don't tweak the UI, just fetch data and start the necessary timers
- (void)showConnectedStateUI {
    [self.mainMenuController populateRegionDataIfNecessary]; // for region selection, currently unused.
    [self.mainMenuController fetchEventData]; //get data immediately, then start the timeer
    [self.mainMenuController startEventRefreshTimer];
    [self.mainMenuController createMenu];
}

/// Stop refresh timers and refresh the menu
- (void)showDisconnectedStateUI {
    [self.mainMenuController stopEventRefreshTimer];
    [self.mainMenuController createMenu];
}

- (void)showDisconnectingStateUI {
}

- (void)showConnectingStateUI {
}

#pragma mark Event/Alert management

/// Creates & starts the timer to refresh the event data
- (void)startEventRefreshTimer {
    [self.mainMenuController startEventRefreshTimer];
}

/// Currently unimplemented, an IBAction that can be utilized to force a data refresh
- (IBAction)refreshEventData:(id)sender {
    [self.mainMenuController fetchEventData];
}

- (void)_getLocalRegion {
    __block NSString *localRegion = nil;
    [[GRDHousekeepingAPI new] requestTimeZonesForRegionsWithTimestamp:[NSNumber numberWithInt:0] completion:^(NSArray * _Nullable timeZones, BOOL success, NSUInteger responseStatusCode) {
        if (success){
            [[NSUserDefaults standardUserDefaults] setObject:timeZones forKey:kKnownHousekeepingTimeZonesForRegions];
            GRDRegion *region = [GRDServerManager localRegionFromTimezones:timeZones];
            NSString *regionName = region.regionName;
            localRegion = regionName;
            [self identifyLocalRegionIfNecessary:localRegion];
        }
    }];
}

- (void)identifyLocalRegionIfNecessary:(NSString *)localRegion { //for now just always locate it.
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"regionName == %@", localRegion];
    GRDRegion *local = [[_regions filteredArrayUsingPredicate:pred] firstObject];
    if (local){
        __localRegion = local;
        GRDLog(@"local region: %@", local);
        [local findBestServerWithCompletion:^(NSString * _Nonnull server, NSString * _Nonnull serverLocation, BOOL success) {
            if (success){
                GRDLog(@"found best server: %@ loc: %@", server, serverLocation);
            }
        }];
    }
}

// This is a bit of ugly glue code, when creating the MainMenuController NSMenuItem's and setting their actions its assuming by default
// that the actions are inside here, in the meantime, listen for them in here and forward them to the mainMenuController instance.

- (void)showLoginWindow:(id)sender {
    [self.mainMenuController showLoginWindow:sender];
}

- (void)selectRegion:(NSMenuItem *)sender {
    [self.mainMenuController selectRegion:sender];
}

- (void)showAlertsWindow:(id)sender {
    [self.mainMenuController showAlertsWindow:sender];
}

- (void)clearVPNSettings:(id)sender {
    [self.mainMenuController clearVPNSettings:sender];
}

- (void)createVPNConnection:(id)sender {
    [self.mainMenuController createVPNConnection:sender];
}

- (void)quit:(id)sender {
    [self.mainMenuController quit:sender];
}

- (void)spoofReceiptData:(id)sender {
    [self.mainMenuController spoofReceiptData:sender];
}

- (void)showManualServerList:(id)sender {
    [self.mainMenuController showManualServerList:sender];
}

@end
