//
//  GRDSubscriptionManager.m
//  Guardian
//
//  Created by Constantin Jacob on 12.04.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

@import UserNotifications;
#import <GuardianConnect/GuardianConnect.h>
#import <GuardianConnect/GRDSubscriptionManager.h>
#import <GuardianConnect/GRDIAPDiscountDetails.h>
#import <GuardianConnect/NSObject+Dictionary.h>

@interface GRDSubscriptionManager ()

@property (nonatomic, copy, nullable) void (^productIdCompletionBlock)(NSArray <SKProduct *>*products, BOOL apiSuccess, NSString *error);

@end

@implementation GRDSubscriptionManager {
    BOOL _isRestore;
    BOOL _isPurchase;
    BOOL _activePurchase;
    BOOL _addedObservers;
    NSMutableArray *_mutableProducts; //keeps track of SKProducts
}
@synthesize delegate;

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static GRDSubscriptionManager *shared;
    dispatch_once(&onceToken, ^{
        shared = [[GRDSubscriptionManager alloc] init];
    });
    return shared;
}

#pragma mark - SKProductRequest delegate methods

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count > 0) {
        self.subscriptionLocale = response.products[0].priceLocale;
        [_mutableProducts addObjectsFromArray:response.products];
        
        for (NSString *invalidIdentifier in response.invalidProductIdentifiers) {
            GRDLog(@"invalid id: %@", invalidIdentifier);
        }
        
        
        NSSortDescriptor *priceDescriptor = [[NSSortDescriptor alloc] initWithKey:@"price" ascending:YES];
        self.sortedProductOfferings = [_mutableProducts sortedArrayUsingDescriptors:@[priceDescriptor]];
        if (self.productIdCompletionBlock) {
            self.productIdCompletionBlock(self.sortedProductOfferings, TRUE, nil);
        }
        
    } else {
        GRDLog(@"response.products.count is not greater than 0 !!!");
        if (self.productIdCompletionBlock) {
            self.productIdCompletionBlock(nil, false, @"response.products.count is not greater than 0!!!");
        }
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    GRDLog(@"Failed to retrieve IAP objects: %@", [error localizedDescription]);
    if (self.productIdCompletionBlock) {
        self.productIdCompletionBlock(nil, false, [error localizedDescription]);
    }
}

- (void)addObservers {
    if (!_addedObservers) {
        [self addObserver:self forKeyPath:@"productIds" options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:nil];
        _addedObservers = true;
    }
}

- (void)setProductIds:(NSArray * _Nonnull)productIds completion:(void(^)(NSArray <SKProduct *>*products, BOOL success, NSString *error))completion {
    [self setProductIds:productIds];
    if (completion) {
        self.productIdCompletionBlock = completion;
    }
}

- (void)getProducts {
    if (self.productIds.count == 0 || self.productIds == nil) {
        return;
    }
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:self.productIds]];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    //NSArray *changed = change[NSKeyValueChangeNewKey];
    if ([keyPath isEqualToString:@"productIds"]){
        [self getProducts];
    }
}

- (instancetype)init {
    self = [super init];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    [self addObservers];
    _mutableProducts = [NSMutableArray new];
    return self;
}

- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
    GRDLog(@"[delegate/shouldAddStorePayment] payment == %@", payment);
    GRDLog(@"[delegate/shouldAddStorePayment] product == %@", product);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotficationPurchaseInAppStore object:nil];
    return YES;
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    GRDLog(@"[paymentQueueRestoreCompletedTransactionsFinished] queue == %@", queue);
    
    GRDLog(@"transactions: %@", queue.transactions);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRestoreSubscriptionFinished object:nil];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error; {
    GRDLog(@"[paymentQueue:queuerestoreCompletedTransactionsFailedWithError] queue == %@", queue);
    GRDLog(@"[paymentQueue:queuerestoreCompletedTransactionsFailedWithError] error == %@", error);
    
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
        
    } else if (@available(macOS 10.15, *)) {
        if([error code] == SKErrorStoreProductNotAvailable) {
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
    } else {
        // Fallback on earlier versions
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRestoreSubscriptionError object:nil userInfo:@{@"errorString":errorString, @"NSError":error}];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {    
    BOOL wasSuccessfulPurchase = NO;
    
    for (SKPaymentTransaction *IAPPaymentTransaction in transactions) {
        if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStatePurchasing) {
            GRDLog(@"[delegate/updatedTransactions] purchasing...");
            _activePurchase = YES;
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStatePurchased) {
            GRDLog(@"[delegate/updatedTransactions] state is purchased!");
            [[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
            
            wasSuccessfulPurchase = YES;
            [self.delegate validatingReceipt];
            _isPurchase = YES;
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateFailed) {
            GRDLog(@"Purchase failed. Removing payment transaction from queue. Error: %@", IAPPaymentTransaction.error);
            [[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
            [self.delegate subscriptionFailed];
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateDeferred) {
            GRDLog(@"[delegate/updatedTransactions] Purchase deferred. Informing user about deferred");
            [self.delegate subscriptionDeferred];
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateRestored) {
            //GRDLog(@"[delegate/updatedTransactions] Restore successful");
            [[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
            wasSuccessfulPurchase = YES;
            [self.delegate validatingReceipt];
            _isRestore = YES;
        }
    }
    
    // calls 'verifyReceipt' for potential further action
    if (wasSuccessfulPurchase == YES) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self verifyReceipt];
        });
    }
}

- (BOOL)hasWhitelistedSubscriptionType {
    NSString *subType = [[NSUserDefaults standardUserDefaults] stringForKey:kSubscriptionPlanTypeStr];
    return ([self.whitelist containsObject:subType]);
}

- (NSArray *)whitelist {
    NSArray *initial = @[kGuardianSubscriptionTypeProfessionalBrave,
                         kGuardianSubscriptionTypeProfessionalYearly,
                         kGuardianSubscriptionTypeVisionary,
                         kGuardianSubscriptionTypeProfessionalMonthly];
    
    if (self.receiptExceptionIds.count > 0){
        return [[initial mutableCopy] arrayByAddingObjectsFromArray:self.receiptExceptionIds];
    }
    return initial;
}

- (BOOL)isFreeTrialOrDayPass {
    NSString *subscriptionTypeStr = [[NSUserDefaults standardUserDefaults] objectForKey:kSubscriptionPlanTypeStr];
    NSArray *freeTrialTypes = @[kGuardianFreeTrial3Days,
                                kGuardianExtendedTrial30Days,
                                kGuardianSubscriptionGiftedDayPass,
                                kGuardianSubscriptionCustomDayPass,
                                kGuardianTrialBalanceDayPasses];
    return ([freeTrialTypes containsObject:subscriptionTypeStr]);
}


//this still belongs in the subscription manager so this is the best compromise i could come up with.
- (GRDPlanDetailType)subscriptionTypeFromDefaults {
    return [GRDVPNHelper subscriptionTypeFromDefaults];
}

/// Maybe the user updated to a better account type, migrate here. TODO: this needs some kind of sanity check to make sure they are upgrading to a higher quality product (ie day pass or monthly to pro)
- (void)processReceiptItemForExistingUser:(GRDReceiptItem *)receiptItem {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *currentPlan = [defaults objectForKey:kSubscriptionPlanTypeStr];
    if (![receiptItem.productId isEqualToString:currentPlan]) {
        GRDLog(@"old plan: %@ new plan: %@", currentPlan, receiptItem.productId);
        [defaults setObject:receiptItem.productId forKey:kSubscriptionPlanTypeStr];
        [defaults setObject:receiptItem.expiresDate forKey:kGuardianSubscriptionExpiresDate];
        if ([receiptItem subscriberCredentialExpired]) {
            GRDLog(@"Subscription change/renewal detected. Deleting subscriber credential in keychain");
            [GRDKeychain removeSubscriberCredentialWithRetries:3];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionActive object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
        [self handleValidationSuccess:receiptItem];
    }
}

/// Process the receipt item for a new paying customer, sets all the necessary keychain and default items for a user
- (void)processReceiptItemForNewPayingUser:(GRDReceiptItem *)receiptItem {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [GRDVPNHelper setIsPayingUser:YES];
    
    // Removing the PET if present since no PET should be present if a valid IAP subscription is active
    [GRDKeychain removeKeychanItemForAccount:kKeychainStr_PEToken];
    
    // Removing any pending day pass expiration notifications
    if (@available(macOS 10.14, iOS 10.0, *)) {
        [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
    }
    
    [defaults setObject:[receiptItem productId] forKey:kSubscriptionPlanTypeStr];
    [defaults setObject:[receiptItem expiresDate] forKey:kGuardianSubscriptionExpiresDate];
    [defaults removeObjectForKey:kKnownGuardianHosts];
    
    //there are additional steps necessary if it is a day pass subscription, setting a different user default for the expiration & setting up local user notifications about pending day pass expiration.
    
    if ([receiptItem isDayPass]) {
        [defaults setObject:receiptItem.expiresDate forKey:kGuardianDayPassExpirationDate];
    }
    
    //determine if subscriber credentials need refreshing
    if ([receiptItem subscriberCredentialExpired]) {
        GRDLog(@"Subscription change/renewal detected. Deleting subscriber credential in keychain");
        [GRDKeychain removeSubscriberCredentialWithRetries:3];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionActive object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
    [self handleValidationSuccess:receiptItem];
    
}

#pragma mark - StoreKit IAP

- (void)userExpiredTrial:(BOOL)wasTrial {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [GRDKeychain removeSubscriberCredentialWithRetries:3];
    if (wasTrial) { //if it was a free trial we modify two additional detault fields but leave the subscription plan string intact
        [defaults setBool:TRUE forKey:kGRDFreeTrialExpired];
        [defaults removeObjectForKey:kGRDTrialExpirationInterval];
    } else {
        [defaults removeObjectForKey:kSubscriptionPlanTypeStr];
    }
    [defaults removeObjectForKey:kGuardianDayPassExpirationDate];
    
    [GRDVPNHelper setIsPayingUser:NO];
    [defaults removeObjectForKey:kKnownGuardianHosts];
    [defaults removeObjectForKey:kGuardianSubscriptionExpiresDate];
    [defaults setBool:NO forKey:kGRDWifiAssistEnableFallback];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSubscriptionInactive object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSubscriptionUpdatedNotification object:nil];
    self.activePurchase = false;
    self.isRestore = false;
    self.isPurchase = false;
}

- (void)verifyReceipt {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([self hasWhitelistedSubscriptionType]) {
        GRDLog(@"A valid Pro account is already present. Not verifying the receipt");
        if (_activePurchase) { // extra hardening
            [self handleValidationSuccess:nil];
        }
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [[GRDHousekeepingAPI new] verifyReceiptFiltered:true completion:^(NSArray<GRDReceiptItem *> * _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage) {
            if (success == YES && validLineItems.count > 0) { //sorted ascending, the last item will be the newest
                
                GRDReceiptItem *latestItem = [validLineItems lastObject];
                //GRDLog(@"latestItem: %@ in validLineItems: %@", latestItem, validLineItems);
                //this may no longer be necessary
                BOOL isTrial = [latestItem isTrialPeriod];
                if (!isTrial) {
                    [defaults setBool:YES forKey:kUserNotEligibleForFreeTrial];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFreeTrialEligibilityChanged object:nil];
                }
                
                if ([GRDVPNHelper isPayingUser] == NO) {
                    GRDLog(@"Free user with new subscription detected. Converting to paid user");
                    [self processReceiptItemForNewPayingUser:latestItem];
                } else {
                    [self processReceiptItemForExistingUser:latestItem];
                }
                
            } else if (success == YES && (validLineItems.count == 0 || validLineItems == nil) && ![self isFreeTrialOrDayPass]) {
                
                if ([GRDVPNHelper isPayingUser] == YES) {
                    GRDLog(@"No valid subscriptions found. Converting paid to free...");
                    [self userExpiredTrial:false];
                    [self.delegate receiptInvalid];
                }
            } else {
                if (errorMessage != nil){
                    GRDLog(@"Failed to verify receipt: %@", errorMessage);
                }
            }
            
            //everything else has been done by now, additional check to see if subscriber credential has expired.
            GRDSubscriberCredential *cred = [GRDSubscriberCredential currentSubscriberCredential];
            if (cred) {
                if ([cred tokenExpired]) {
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                }
            }
            
        }];
    });
}

- (void)handleValidationSuccess:(GRDReceiptItem *_Nullable)receiptItem  {
    @weakify(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        self_weak_.activePurchase = false;
        if (self_weak_.isRestore){
            if ([self_weak_.delegate respondsToSelector:@selector(subscriptionRestored)]){
                [self_weak_.delegate subscriptionRestored];
            }
            if ([self_weak_.delegate respondsToSelector:@selector(subscriptionRestored:)]){
                [self_weak_.delegate subscriptionRestored:receiptItem];
            }
            self_weak_.isPurchase = false;
            self_weak_.isRestore = false;
        } else if (self_weak_.isPurchase){
            if([self_weak_.delegate respondsToSelector:@selector(subscribedSuccessfully)]){
                [self_weak_.delegate subscribedSuccessfully];
            }
            if ([self_weak_.delegate respondsToSelector:@selector(subscribedSuccessfully:)]){
                [self_weak_.delegate subscribedSuccessfully:receiptItem];
            }
            self_weak_.isPurchase = false;
            self_weak_.isRestore = false;
        }
    });
}

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

@end
