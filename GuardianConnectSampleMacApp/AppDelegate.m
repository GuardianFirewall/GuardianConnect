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
    [self addVPNObserver];
}

- (void)showConnectedStateUI {
    self.createButton.title = NSLocalizedString(@"Disconnect VPN", nil);
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
        [self verifyReceipt];
    }

}

- (void)handleValidationSuccess {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.createButton.enabled = true;
    });
}

- (void)verifyReceipt {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
    // Creating and entering a dispatch_group so that we can check the subscription first
    // and if required check if the Subscriber Credential has expired
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    @weakify(self);
    // Jumping onto a background thread right away to not delay interface presentation in any way
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        GRDHousekeepingAPI *housekeeping = [[GRDHousekeepingAPI alloc] init];
        [housekeeping verifyReceiptWithCompletion:^(NSArray * _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage) {
            if (success == YES && validLineItems != nil) {
                // Creating a mutable dictionary so that we only have to process
                // the stupid expiration date / purchase date difference once
                NSMutableDictionary *latestValidLineItem;
                for (NSDictionary *item in validLineItems) {
                    NSString *productId = item[kGRDProductID];
                    NSInteger expirationDate;
                    if ([productId isEqualToString:kGuardianSubscriptionCustomDayPass]){
                        GRDLog(@"[DEBUG] found custom day passes, do not process them in any way!");
                        continue;
                    }
                    
                    if ([productId isEqualToString:kGuardianSubscriptionDayPassAlt] == YES || [productId isEqualToString:kGuardianSubscriptionDayPass] == YES) {
                        
                        //handle day pass expiration by their purchase date + adding an extra day
                        NSInteger purchaseInteger = [item[@"purchase_date_ms"] integerValue];
                        expirationDate = (purchaseInteger / 1000) + 86400;
                                
                    } else { // this isn't a day pass, just check the expiration date normally.
                        
                        NSInteger expireInteger = [item[@"expires_date_ms"] integerValue];
                        expirationDate = expireInteger / 1000;
                    }
                            
                    // Setting grdExpiresDate to 0 if we are iterating through everything for the first time, TODO: set this outside of the loop for cleaner code
                    NSInteger grdExpiresDate;
                    if (latestValidLineItem == nil) {
                        grdExpiresDate = 0;
                    } else { //a valid line item exists from one of the prior loop iterations, update grdExpiresDate
                        grdExpiresDate = [latestValidLineItem[kGRDExpiresDate] integerValue];
                    }
                    // The current loop item has a higher expiration date then our prior item, update the latestValidLineItem to a mutable copy of our current item
                    if (expirationDate > grdExpiresDate) {
                        latestValidLineItem = [item mutableCopy];
                        latestValidLineItem[kGRDExpiresDate] = [NSNumber numberWithLong:expirationDate];
                    }
                }
                
                //passed the for loop, we have the most recent valid subscription item at this point.
                
                // Check whether we should show the trial period text or not
                NSString *trialPeriodString = latestValidLineItem[@"is_trial_period"];
                if ([trialPeriodString isEqualToString:@"false"]) {
                   // [defaults setBool:YES forKey:kUserNotEligibleForFreeTrial];
                    //[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFreeTrialEligibilityChanged object:nil];
                }
                
                if ([GRDVPNHelper isPayingUser] == NO) {
                    GRDLog(@"Free user with new subscription detected. Converting to paid user");
                    [GRDVPNHelper setIsPayingUser:YES];
                    
                    // Removing the PET if present since no PET should be present if a valid IAP subscription is active
                    [GRDKeychain removeKeychanItemForAccount:kKeychainStr_PEToken];
                    
                    // Removing any pending day pass expiration notifications
                    //[[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
                    
                    NSString *productId = latestValidLineItem[kGRDProductID];
                    [defaults setObject:productId forKey:kSubscriptionPlanTypeStr];
                    [defaults removeObjectForKey:kKnownGuardianHosts];
                    //[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionActive object:nil];
                    //[[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
                    [self handleValidationSuccess];
                    
                    //there are additional steps necessary if it is a day pass subscription, setting a different user default for the expiration & setting up local user notifications about pending day pass expiration.
                    if ([productId isEqualToString:kGuardianSubscriptionDayPassAlt] || [productId isEqualToString:kGuardianSubscriptionDayPass]) {
                        
                        NSNumber *expiresDate = [NSNumber numberWithInteger:[latestValidLineItem[kGRDExpiresDate] integerValue]];
                        [defaults setObject:[NSDate dateWithTimeIntervalSince1970:[expiresDate integerValue]] forKey:kGuardianDayPassExpirationDate];
                        
                        //handling sending notifications if on iOS 12+, trying to slim down this function, and this didn't need to be in here.
                        //[self handleDayPassNotificationsIfNecessary:expiresDate];
                    }
                }
                    
                // Checking whether the receipt expiration has changed in any way since it's a good
                // indicator to determine if we need to get a new subscriber credential and
                // update all the local values based on it, as well as make zoe-agent do the right things in the future (Push Notifications, App Origin Detection etc.)
                NSDate *subCredSubExpirationDate = [defaults objectForKey:kGuardianSubscriptionExpiresDate];
                NSDate *grdExpiresDate = [NSDate dateWithTimeIntervalSince1970:[latestValidLineItem[kGRDExpiresDate] integerValue]];
                if ([subCredSubExpirationDate isEqualToDate:grdExpiresDate] == NO) {
                    GRDLog(@"Subscription change/renewal detected. Deleting subscriber credential in keychain");
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                    NSString *productId = latestValidLineItem[kGRDProductID];
                    [defaults setObject:productId forKey:kSubscriptionPlanTypeStr]; //im fairly certain setting the product id here is redudant, but it shouldnt hurt anything.
                    [defaults setObject:grdExpiresDate forKey:kGuardianSubscriptionExpiresDate];
                    [self handleValidationSuccess]; //this call is almost definitely redudant, but im also not certain it hurts anything.
                    
                } else {
                    // Leaving the group explicitly to check wether the token has expired
                    dispatch_group_leave(group);
                }
                    
            } else if (success == YES && validLineItems == nil) {// && ![self isFreeTrialOrDayPass]) { //the API call was successful, no subscription is found and they arent a day pass or free trial. if they are marked as a paying user, they are now expired.

                if ([GRDVPNHelper isPayingUser] == YES) {
                    GRDLog(@"No valid subscriptions found. Converting paid to free...");
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                    [defaults removeObjectForKey:kSubscriptionPlanTypeStr];
                    [defaults removeObjectForKey:kGuardianDayPassExpirationDate];
                    
                    [GRDVPNHelper setIsPayingUser:NO];
                    [defaults removeObjectForKey:kKnownGuardianHosts];
                    [defaults removeObjectForKey:kGuardianSubscriptionExpiresDate];
                    [defaults setBool:NO forKey:kGRDWifiAssistEnableFallback];
                    //[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionInactive object:nil];
                    //[[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
                    //self_weak_.activePurchase = false;
                    //self_weak_.isRestore = false;
                    //self_weak_.isPurchase = false;
                    //[self.delegate receiptInvalid]; //needs testing
                }
                
            } else {
                GRDLog(@"Failed to verify receipt: %@", errorMessage);
            }
        }];
        
        //this only gets called from above & will clear our subscriber credential if necessary.
        dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSString *subCredString = [GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential];
            if (![subCredString isEqualToString:@""]) {
                GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subCredString];
                if ([[NSDate date] compare:[NSDate dateWithTimeIntervalSince1970:subCred.tokenExpirationDate]] == NSOrderedDescending) {
                    GRDLog(@"Subscriber Credential expired. Removing old one");
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                }
            }
        });
    });
}


- (void)showDisconnectedStateUI {
    self.createButton.title = NSLocalizedString(@"Connect VPN", nil);
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
