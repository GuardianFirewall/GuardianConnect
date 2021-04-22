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
    [[GRDVPNHelper sharedInstance] setMainCredential:main];
    [self addVPNObserver];
}

- (void)showConnectedStateUI {
    LOG_SELF;
    self.createButton.title = NSLocalizedString(@"Disconnect VPN", nil);
}

- (void)showDisconnectedStateUI {
    LOG_SELF;
    self.createButton.title = NSLocalizedString(@"Connect VPN", nil);
}

- (void)showDisconnectingStateUI {
    LOG_SELF;
    self.createButton.title = NSLocalizedString(@"Disconnecting VPN...", nil);
}

- (void)showConnectingStateUI {
    LOG_SELF;
    self.createButton.title = NSLocalizedString(@"Connecting VPN...", nil);
}

- (void)handleConnectionStatus:(NEVPNStatus)status {
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
                    //UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:[NSString stringWithFormat:@"Couldn't save subscriber credential in local keychain. Please try again. If this issue persists please notify our technical support about your issue."] preferredStyle:UIAlertControllerStyleAlert];
                    //[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    //[self safePresentViewController:alert];
                });
                
            } else { //we were successful saving the token
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [GRDVPNHelper setIsPayingUser:YES];
                    [defaults setObject:[response objectForKey:@"type"] forKey:kSubscriptionPlanTypeStr];
                    [defaults setObject:[NSDate dateWithTimeIntervalSince1970:[[response objectForKey:@"pet-expires"] integerValue]] forKey:kGuardianPETokenExpirationDate];
                    [defaults removeObjectForKey:kKnownGuardianHosts];
                    
                    // Removing any pending day pass expiration notifications
                    //[[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
                    //GRDDayPassManager *dayPassManager = [GRDDayPassManager new];
                    //NSString *dpat = [response objectForKey:@"dpat"];
                                        
                    //[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionActive object:nil];
                    
                });
            }
            
        } else {
            GRDLog(@"Login failed :S with error: %@", errorMessage);
        }
        GRDLog(@"response: %@", response);
        
    }];
}

- (IBAction)clearKeychain:(id)sender {
    [[GRDVPNHelper sharedInstance] forceDisconnectVPNIfNecessary];
    [GRDVPNHelper clearVpnConfiguration];
}

- (IBAction)createVPNConnection:(id)sender {
    
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
