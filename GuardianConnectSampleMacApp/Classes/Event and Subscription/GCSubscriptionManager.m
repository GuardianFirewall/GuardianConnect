//
//  GCSubscriptionManager.m
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/22/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GCSubscriptionManager.h"

@implementation GCSubscriptionManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static GCSubscriptionManager *shared;
    dispatch_once(&onceToken, ^{
        shared = [[GCSubscriptionManager alloc] init];
    });
    return shared;
}

- (void)verifyReceipt {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Creating and entering a dispatch_group so that we can check the subscription first
    // and if required check if the Subscriber Credential has expired
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    //@weakify(self);
    // Jumping onto a background thread right away to not delay interface presentation in any way
    __block NSInteger grdExpiresDate = 0;
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
                    
                    if (latestValidLineItem != nil) { //a valid line item exists from one of the prior loop iterations, update grdExpiresDate
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
                    if (self.delegate){
                        if([self.delegate respondsToSelector:@selector(handleValidationSuccess)]){
                            [self.delegate handleValidationSuccess];
                        }
                    }
                    
                    
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
                    if (self.delegate){
                        if([self.delegate respondsToSelector:@selector(handleValidationSuccess)]){
                            [self.delegate handleValidationSuccess];
                        }
                    }
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

@end
