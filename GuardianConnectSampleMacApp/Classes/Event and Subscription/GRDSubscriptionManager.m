//
//  GRDSubscriptionManager.m
//  Guardian
//
//  Created by Constantin Jacob on 12.04.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

@import UserNotifications;
#import "GRDSubscriptionManager.h"
#import <GuardianConnect/GuardianConnectMac.h>

@implementation GRDSubscriptionManager {
    BOOL _isRestore;
    BOOL _isPurchase;
    BOOL _activePurchase;
}
@synthesize delegate;

- (BOOL)isPurchase {
    return _isPurchase;
}

- (void)setIsPurchase:(BOOL)isPurchase {
    _isPurchase = isPurchase;
}

- (BOOL)isRestore {
    return _isRestore;
}

- (void)setIsRestore:(BOOL)isRestore {
    _isRestore = isRestore;
}

- (BOOL)activePurchase {
    return _activePurchase;
}

- (void)setActivePurchase:(BOOL)isActivePurchase {
    _activePurchase = isActivePurchase;
}

+ (instancetype)sharedManager {
	static dispatch_once_t onceToken;
	static GRDSubscriptionManager *shared;
	dispatch_once(&onceToken, ^{
		shared = [[GRDSubscriptionManager alloc] init];
	});
	return shared;
}

- (instancetype)init {
	self = [super init];
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	return self;
}

#if !TARGET_OS_OSX

- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
    GRDLog(@"[DEBUG][delegate/shouldAddStorePayment] payment == %@", payment);
    GRDLog(@"[DEBUG][delegate/shouldAddStorePayment] product == %@", product);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotficationPurchaseInAppStore object:nil];
    return YES;
}

#endif

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    GRDLog(@"[DEBUG][paymentQueueRestoreCompletedTransactionsFinished] queue == %@", queue);
    
    GRDLog(@"transactions: %@", queue.transactions);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRestoreSubscriptionFinished object:nil];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error; {
    GRDLog(@"[DEBUG][paymentQueue:queuerestoreCompletedTransactionsFailedWithError] queue == %@", queue);
    GRDLog(@"[DEBUG][paymentQueue:queuerestoreCompletedTransactionsFailedWithError] error == %@", error);
    
    NSString *errorString = nil;
    if([error code] == NSURLErrorTimedOut) {
        errorString = @"NSURLErrorTimedOut";
        
    } else if([error code] == NSURLErrorCannotFindHost) {
        errorString = @"NSURLErrorCannotFindHost";
        
    } else if([error code] == NSURLErrorCannotConnectToHost) {
        errorString = @"NSURLErrorCannotConnectToHost";
        
    } else if([error code] == NSURLErrorNetworkConnectionLost) {
        errorString = @"NSURLErrorNetworkConnectionLost";
        
    } else if([error code] == NSURLErrorNotConnectedToInternet) {
        errorString = @"NSURLErrorNotConnectedToInternet";
        
    } else if([error code] == NSURLErrorUserCancelledAuthentication) {
        errorString = @"NSURLErrorUserCancelledAuthentication";
        
    } else if([error code] == NSURLErrorSecureConnectionFailed) {
        errorString = @"NSURLErrorSecureConnectionFailed";
        
    } else if([error code] == SKErrorUnknown) {
        errorString = @"SKErrorUnknown";
        
    } else if([error code] == SKErrorClientInvalid) {
        errorString = @"SKErrorClientInvalid";
        
    } else if([error code] == SKErrorPaymentCancelled) {
        errorString = @"SKErrorPaymentCancelled";
        
    } else if([error code] == SKErrorPaymentInvalid) {
        errorString = @"SKErrorPaymentInvalid";
        
    } else if([error code] == SKErrorPaymentNotAllowed) {
        errorString = @"SKErrorPaymentNotAllowed";
        
    } else if([error code] == SKErrorStoreProductNotAvailable) {
        errorString = @"SKErrorStoreProductNotAvailable";
#if !TARGET_OS_OSX
    } else if([error code] == SKErrorCloudServicePermissionDenied) {
        errorString = @"SKErrorCloudServicePermissionDenied";
        
    } else if([error code] == SKErrorCloudServiceNetworkConnectionFailed) {
        errorString = @"SKErrorCloudServiceNetworkConnectionFailed";
        
    } else if([error code] == SKErrorCloudServiceRevoked) {
        errorString = @"SKErrorCloudServiceRevoked";
#endif
    } else {
        errorString = @"(Undefined Error)";
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRestoreSubscriptionError object:nil userInfo:@{@"errorString":errorString, @"NSError":error}];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {    
    BOOL wasSuccessfulPurchase = NO;
    
	for (SKPaymentTransaction *IAPPaymentTransaction in transactions) {
		if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStatePurchasing) {
            GRDLog(@"[DEBUG][delegate/updatedTransactions] purchasing...");
			_activePurchase = YES;
            
		} else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStatePurchased) {
			GRDLog(@"[DEBUG][delegate/updatedTransactions] state is purchased!");
            [[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
            
            wasSuccessfulPurchase = YES;
			[self.delegate validatingReceipt];
            _isPurchase = YES;
			
		} else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateFailed) {
			GRDLog(@"Purchase failed. Removing payment transaction from queue. Error: %@", IAPPaymentTransaction.error);
			[[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
			[self.delegate subscriptionFailed];
			
		} else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateDeferred) {
			GRDLog(@"[DEBUG][delegate/updatedTransactions] Purchase deferred. Informing user about deferred");
			[self.delegate subscriptionDeferred];
			
		} else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateRestored) {
			GRDLog(@"[DEBUG][delegate/updatedTransactions] Restore successful");
			[[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
            wasSuccessfulPurchase = YES;
			[self.delegate validatingReceipt];
            _isRestore = YES;
        }
	}
    
    // calls 'validateAppReceipt' for potential further action
    if (wasSuccessfulPurchase == YES) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self verifyReceipt];
        });
    }
}

/// conveinience check to see if our subscription type exists among the whitelisted types.
- (BOOL)hasWhitelistedSubscriptionType {
    NSString *subType = [[NSUserDefaults standardUserDefaults] stringForKey:kSubscriptionPlanTypeStr];
    return ([self.whitelist containsObject:subType]);
}

/// these are subscription types that we skip receipt validation on, they consist of partner product ID's and purchases made outside of the app store.
- (NSArray *)whitelist {
    return @[kGuardianSubscriptionTypeProfessionalBrave,kGuardianSubscriptionTypeProfessionalYearly, kGuardianSubscriptionTypeVisionary, kGuardianSubscriptionTypeProfessionalMonthly];
}

- (void)expireFreeTrial {
    GRDLog(@"[DEBUG] the trial has expired! clear any data related to valid subscription & show the subscription view!");
    if ([GRDVPNHelper isPayingUser]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        [def setBool:TRUE forKey:kGRDFreeTrialExpired];
        [def removeObjectForKey:kGRDTrialExpirationInterval];
        [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
        [GRDKeychain removeSubscriberCredentialWithRetries:3];
        //[def removeObjectForKey:kSubscriptionPlanTypeStr]; //we dont remove this because it would inhibit our free trial check
        [GRDVPNHelper setIsPayingUser:NO];
        [def removeObjectForKey:kKnownGuardianHosts];
        [def setBool:NO forKey:kGRDWifiAssistEnableFallback];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionInactive object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
    }
}

/// whether or not the GRDDayPassAvailableViewController shows the 'Activate' button, if we are currently a free trial or day pass OR we don't have an active subscription.
- (BOOL)showActivateButton {
    NSString *subscriptionTypeStr = [[NSUserDefaults standardUserDefaults] objectForKey:kSubscriptionPlanTypeStr];
    if ([self isFreeTrialOrDayPass] || subscriptionTypeStr == nil){
        return TRUE;
    }
    return FALSE;
}

/// called above & in verifyReceipt to make certain day pass users that are missing corresponding receipt data don't get unsubscribed accidently.
- (BOOL)isFreeTrialOrDayPass {
    NSString *subscriptionTypeStr = [[NSUserDefaults standardUserDefaults] objectForKey:kSubscriptionPlanTypeStr];
    NSArray *freeTrialTypes = @[kGuardianFreeTrial3Days,
                                kGuardianExtendedTrial30Days,
                                kGuardianSubscriptionGiftedDayPass,
                                kGuardianSubscriptionCustomDayPass];
    return ([freeTrialTypes containsObject:subscriptionTypeStr]);
}

/// used as part of the convoluted logic in checkTrialBalanceWithCompletion & in autoDetectedInstanceSelectingPro: rife for refactor.
- (BOOL)isFreeTrial {
    NSString *subscriptionTypeStr = [[NSUserDefaults standardUserDefaults] objectForKey:kSubscriptionPlanTypeStr];
    NSArray *freeTrialTypes = @[kGuardianFreeTrial3Days,
                                kGuardianExtendedTrial30Days];
    return ([freeTrialTypes containsObject:subscriptionTypeStr] && subscriptionTypeStr != nil);
}

//this still belongs in the subscription manager so this is the best compromise i could come up with.
- (GRDPlanDetailType)subscriptionTypeFromDefaults {
    return [GRDVPNHelper subscriptionTypeFromDefaults];
}

#pragma mark - StoreKit debug callback
- (void)test {
	GRDLog(@"Test method call.");
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGuardianSuccessfulSubscription object:nil];
		[self.delegate subscribedSuccessfully];
	});
}


#pragma mark - Local Notifications

- (void)setLocalNotificationForTrialPETExpirationDate:(NSInteger)expirationDate {
    if (@available(iOS 12.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionProvisional completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (error != nil) {
                GRDLog(@"Failed to request provisional notifiation permissions: %@", error);
                return;
            }
            
            // Setting a reminder 24h prior to expiration
            NSDateComponents *dateComponents24h = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond  fromDate:[NSDate dateWithTimeIntervalSince1970:expirationDate - 86400]];
            UNCalendarNotificationTrigger *trigger24h = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:dateComponents24h repeats:NO];
            
            UNMutableNotificationContent *content24h = [UNMutableNotificationContent new];
            [content24h setTitle:NSLocalizedString(@"Your Day Pass is expiring in 24 hours", nil)];
            [content24h setBody:NSLocalizedString(@"Subscribe or purchase additional Day Passes to continue enjoying the privacy protection of Guardian", nil)];
            
            UNNotificationRequest *request24h = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content24h trigger:trigger24h];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request24h withCompletionHandler:^(NSError * _Nullable error) {
                if (error != nil) {
                    GRDLog(@"Failed to schedule day passes notification: %@", error);
                }
            }];
            
            
            // Setting a reminder 6h prior to expiration
            NSDateComponents *dateComponents6h = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond  fromDate:[NSDate dateWithTimeIntervalSince1970:expirationDate - 21600]];
            UNCalendarNotificationTrigger *trigger6h = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:dateComponents6h repeats:NO];
            
            UNMutableNotificationContent *content6h = [UNMutableNotificationContent new];
            [content6h setTitle:NSLocalizedString(@"Your Day Pass is expiring in 6 hours", nil)];
            [content6h setBody:NSLocalizedString(@"Don’t leave your information exposed! Continue enjoying a private internet with additional Day Passes or a subscription", nil)];
            
            UNNotificationRequest *request6h = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content6h trigger:trigger6h];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request6h withCompletionHandler:^(NSError * _Nullable error) {
                if (error != nil) {
                    GRDLog(@"Failed to schedule day passes notification: %@", error);
                }
            }];
        }];
        
    } else {
        GRDLog(@"Not setting up local notifications since the local OS does not support provisional notification permissions yet");
    }
}

#pragma mark - StoreKit IAP

- (void)verifyReceipt {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([self hasWhitelistedSubscriptionType]) {
        GRDLog(@"A valid Pro account is already present. Not verifying the receipt");
        if (_activePurchase) { // extra hardening
            [self handleValidationSuccess];
        }
        return;
    }
    
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
                    [defaults setBool:YES forKey:kUserNotEligibleForFreeTrial];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFreeTrialEligibilityChanged object:nil];
                }
                
                if ([GRDVPNHelper isPayingUser] == NO) {
                    GRDLog(@"Free user with new subscription detected. Converting to paid user");
                    [GRDVPNHelper setIsPayingUser:YES];
                    
                    // Removing the PET if present since no PET should be present if a valid IAP subscription is active
                    [GRDKeychain removeKeychanItemForAccount:kKeychainStr_PEToken];
                    
                    // Removing any pending day pass expiration notifications
                    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
                    
                    NSString *productId = latestValidLineItem[kGRDProductID];
                    [defaults setObject:productId forKey:kSubscriptionPlanTypeStr];
                    [defaults removeObjectForKey:kKnownGuardianHosts];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionActive object:nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
                    [self handleValidationSuccess];
                    
                    //there are additional steps necessary if it is a day pass subscription, setting a different user default for the expiration & setting up local user notifications about pending day pass expiration.
                    if ([productId isEqualToString:kGuardianSubscriptionDayPassAlt] || [productId isEqualToString:kGuardianSubscriptionDayPass]) {
                        
                        NSInteger expiresDate = [latestValidLineItem[kGRDExpiresDate] integerValue];
                        [defaults setObject:[NSDate dateWithTimeIntervalSince1970:expiresDate] forKey:kGuardianDayPassExpirationDate];
                        
                        //handling sending notifications if on iOS 12+, trying to slim down this function, and this didn't need to be in here.
                        [self handleDayPassNotificationsIfNecessary:expiresDate];
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
                    
            } else if (success == YES && validLineItems == nil && ![self isFreeTrialOrDayPass]) { //the API call was successful, no subscription is found and they arent a day pass or free trial. if they are marked as a paying user, they are now expired.

                if ([GRDVPNHelper isPayingUser] == YES) {
                    GRDLog(@"No valid subscriptions found. Converting paid to free...");
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                    [defaults removeObjectForKey:kSubscriptionPlanTypeStr];
                    [defaults removeObjectForKey:kGuardianDayPassExpirationDate];
                    
                    [GRDVPNHelper setIsPayingUser:NO];
                    [defaults removeObjectForKey:kKnownGuardianHosts];
                    [defaults removeObjectForKey:kGuardianSubscriptionExpiresDate];
                    [defaults setBool:NO forKey:kGRDWifiAssistEnableFallback];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionInactive object:nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
                    self_weak_.activePurchase = false;
                    self_weak_.isRestore = false;
                    self_weak_.isPurchase = false;
                    [self.delegate receiptInvalid]; //needs testing
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

- (void)handleDayPassNotificationsIfNecessary:(NSInteger)expiresDate {
    if (@available(iOS 12.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionProvisional completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (error != nil) {
                GRDLog(@"Failed to request provisional notifiation permissions: %@", error);
                return;
            }
            
            // Setting a reminder 2h prior to expiration
            NSDateComponents *dateComponents2h = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond  fromDate:[NSDate dateWithTimeIntervalSince1970:expiresDate - 7200]];
            UNCalendarNotificationTrigger *trigger2h = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:dateComponents2h repeats:NO];
            
            UNMutableNotificationContent *content2h = [UNMutableNotificationContent new];
            [content2h setTitle:NSLocalizedString(@"Your Day Pass is expiring in 2 hours", nil)];
            [content2h setBody:NSLocalizedString(@"Continue protecting your personal data by purchasing additional Day Passes or subscribing now", nil)];
            
            UNNotificationRequest *request2h = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content2h trigger:trigger2h];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request2h withCompletionHandler:^(NSError * _Nullable error) {
                if (error != nil) {
                    GRDLog(@"Failed to schedule day passes notification: %@", error);
                }
            }];
            
            
            // Setting a reminder 6h prior to expiration
            NSDateComponents *dateComponents6h = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond  fromDate:[NSDate dateWithTimeIntervalSince1970:expiresDate - 21600]];
            UNCalendarNotificationTrigger *trigger6h = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:dateComponents6h repeats:NO];
            
            UNMutableNotificationContent *content6h = [UNMutableNotificationContent new];
            [content6h setTitle:NSLocalizedString(@"Your Day Pass is expiring in 6 hours", nil)];
            [content6h setBody:NSLocalizedString(@"Don’t leave your information exposed! Continue enjoying a private internet with additional Day Passes or a subscription", nil)];
            
            UNNotificationRequest *request6h = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content6h trigger:trigger6h];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request6h withCompletionHandler:^(NSError * _Nullable error) {
                if (error != nil) {
                    GRDLog(@"Failed to schedule day passes notification: %@", error);
                }
            }];
        }];
        
    } else {
        GRDLog(@"Not setting up local notifications since the local OS does not support provisional notification permissions yet");
    }
}

- (void)handleValidationSuccess {
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        self_weak_.activePurchase = false;
        if (self_weak_.isRestore){
            [self_weak_.delegate subscriptionRestored];
            self_weak_.isPurchase = false;
            self_weak_.isRestore = false;
        } else if (self_weak_.isPurchase){
            [self_weak_.delegate subscribedSuccessfully];
            self_weak_.isPurchase = false;
            self_weak_.isRestore = false;
        }
    });
}


- (void)verifySubscription {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *petExpiresAt = [defaults objectForKey:kGuardianDayPassExpirationDate];
    
    NSString *subType = [defaults stringForKey:kSubscriptionPlanTypeStr];
    NSArray *dayPasses = @[kGuardianSubscriptionCustomDayPass, kGuardianSubscriptionGiftedDayPass];
    // Explicitly check for the gifted day pass & custom day pass subscription type
    if ([dayPasses containsObject:subType] == YES && petExpiresAt != nil && [[NSDate date] compare:petExpiresAt] == NSOrderedDescending) {
        GRDLog(@"Day Pass expired. Reverting back to free");
        [[GRDVPNHelper sharedInstance] forceDisconnectVPNIfNecessary];
        // Safeguard to prevent anything dumb
        if ([GRDVPNHelper isPayingUser]) {
            [defaults setBool:TRUE forKey:kGRDFreeTrialExpired];
            [defaults removeObjectForKey:kGuardianDayPassExpirationDate];
            [GRDKeychain removeSubscriberCredentialWithRetries:3];
            [defaults removeObjectForKey:kSubscriptionPlanTypeStr];
            [GRDVPNHelper setIsPayingUser:NO];
            [defaults removeObjectForKey:kKnownGuardianHosts];
            [defaults removeObjectForKey:kGuardianSubscriptionExpiresDate];
            [defaults setBool:NO forKey:kGRDWifiAssistEnableFallback];
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionInactive object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
        }
    }
}

@end
