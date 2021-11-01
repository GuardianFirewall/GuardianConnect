//
//  GRDSubscriptionManager.m
//  Guardian
//
//  Created by Constantin Jacob on 12.04.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

@import UserNotifications;
#import <GuardianConnect/GuardianConnect.h>
#import <GuardianConnect/NSObject+Dictionary.h>
#import <GuardianConnect/GRDSubscriptionManager.h>

@interface GRDSubscriptionManager ()

@property (nonatomic, copy, nullable) void (^productIdCompletionBlock)(NSArray <SKProduct *>*products, BOOL apiSuccess, NSString *error);

@end

#pragma mark - Class Setup

@implementation GRDSubscriptionManager {
    BOOL _isRestore;
    BOOL _isPurchase;
    BOOL _activePurchase;
    BOOL _addedObservers;
    NSMutableArray *_mutableProducts; //keeps track of SKProducts
}
@synthesize delegate;

- (instancetype)init {
	self = [super init];
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	_mutableProducts = [NSMutableArray new];
	return self;
}

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static GRDSubscriptionManager *shared;
    dispatch_once(&onceToken, ^{
        shared = [GRDSubscriptionManager new];
    });
    return shared;
}

- (void)setAPISecret:(NSString *)apiSecret andBundleId:(NSString *)bundleId {
	self.apiSecret = apiSecret;
	self.bundleId = bundleId;
}


#pragma mark - StoreKit Delegate Methods

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count > 0) {
        self.subscriptionLocale = response.products[0].priceLocale;
        [_mutableProducts addObjectsFromArray:response.products];
        
        for (NSString *invalidIdentifier in response.invalidProductIdentifiers) {
            GRDLog(@"Invalid product id: %@", invalidIdentifier);
        }
        
        // Sorting the returned products by lowest to highest price
        NSSortDescriptor *priceDescriptor = [[NSSortDescriptor alloc] initWithKey:@"price" ascending:YES];
        self.sortedProductOfferings = [_mutableProducts sortedArrayUsingDescriptors:@[priceDescriptor]];
        if (self.productIdCompletionBlock) {
            self.productIdCompletionBlock(self.sortedProductOfferings, YES, nil);
        }
        
    } else {
        GRDLog(@"No products were returned from StoreKit!");
        if (self.productIdCompletionBlock) {
            self.productIdCompletionBlock(nil, NO, @"No products were returned from StoreKit!");
        }
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    GRDLog(@"StoreKit request failed: %@", [error localizedDescription]);
    if (self.productIdCompletionBlock) {
        self.productIdCompletionBlock(nil, false, [error localizedDescription]);
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    GRDLog(@"Queue: %@", queue);
    GRDLog(@"Transactions: %@", queue.transactions);
	
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRestoreSubscriptionFinished object:nil];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    GRDLog(@"Queue: %@", queue);
    GRDLog(@"Error: %@", error);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRestoreSubscriptionError object:nil userInfo:@{@"errorString":NSLocalizedString(@"Failed to restore purchase", nil), @"NSError":error}];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {    
    BOOL wasSuccessfulPurchase = NO;
    
    for (SKPaymentTransaction *IAPPaymentTransaction in transactions) {
        if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStatePurchasing) {
            GRDLog(@"Initialized purchase");
            _activePurchase = YES;
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStatePurchased) {
            GRDLog(@"Purchase succeeded!");
            [[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
            
            wasSuccessfulPurchase = YES;
            _isPurchase = YES;
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateRestored) {
			GRDLog(@"Restore successful");
			[[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
			wasSuccessfulPurchase = YES;
			_isRestore = YES;
			
		} else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateFailed) {
            GRDLog(@"Purchase failed. Removing payment transaction from queue. Error: %@", IAPPaymentTransaction.error);
            [[SKPaymentQueue defaultQueue] finishTransaction:IAPPaymentTransaction];
			if ([self.delegate respondsToSelector:@selector(purchaseFailedWithError:)]) {
				[self.delegate purchaseFailedWithError:IAPPaymentTransaction.error];
				
			} else {
				GRDLog(@"Using deprecated subscriptionFailed method. Please implement the new purchaseFailedWithError: method!");
				[self.delegate subscriptionFailed];
			}
            
        } else if (IAPPaymentTransaction.transactionState == SKPaymentTransactionStateDeferred) {
            GRDLog(@"Purchase deferred. Informing user about deferred state");
            [self.delegate purchaseDeferred];
        }
    }
    
    // calls 'verifyReceipt' for potential further action
    if (wasSuccessfulPurchase == YES) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			// Inform the delegate that the subscription/restoration was successful
			// and that the receipt is about to be verified
			// The delegate can then update the user with details about it
			[self.delegate validatingReceipt];
            [self verifyReceipt:nil filtered:YES];
        });
    }
}


#pragma mark - StoreKit IAP

- (void)verifyReceipt {
	[self verifyReceipt:nil filtered:YES];
	
//	@weakify(self);
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//		[[GRDHousekeepingAPI new] verifyReceipt:nil bundleId:self.bundleId completion:^(NSArray<GRDReceiptItem *> * _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage) {
//			// validLineItems is sorted ascending by the line item's expiration date,
//			// the last item in the array will be the latest purchase aka. the item whose expiration date
//			// is the furthest out in the future
//            if (success == YES && validLineItems.count > 0) {
//                GRDReceiptItem *latestItem = [validLineItems lastObject];
//				dispatch_async(dispatch_get_main_queue(), ^{
//					self_weak_.activePurchase = false;
//					if (self_weak_.isRestore) {
//						if ([self_weak_.delegate respondsToSelector:@selector(subscriptionRestored)]) {
//							[self_weak_.delegate subscriptionRestored];
//						}
//
//						if ([self_weak_.delegate respondsToSelector:@selector(purchaseRestored:)]) {
//							[self_weak_.delegate purchaseRestored:latestItem];
//						}
//
//						self_weak_.isPurchase = false;
//						self_weak_.isRestore = false;
//
//					} else if (self_weak_.isPurchase) {
//						if ([self_weak_.delegate respondsToSelector:@selector(subscribedSuccessfully)]) {
//							[self_weak_.delegate subscribedSuccessfully];
//						}
//
//						if ([self_weak_.delegate respondsToSelector:@selector(purchasedSuccessfully:)]) {
//							[self_weak_.delegate purchasedSuccessfully:latestItem];
//						}
//
//						self_weak_.isPurchase = false;
//						self_weak_.isRestore = false;
//					}
//				});
//
//			} else if (success == YES && (validLineItems.count == 0 || validLineItems == nil)) {
//				[self.delegate receiptInvalid];
//
//            } else {
//                if (errorMessage != nil) {
//                    GRDLog(@"Failed to verify receipt: %@", errorMessage);
//					[self.delegate purchaseFailedWithError:[NSError errorWithDomain:@"com.guardian.GuardianConnect" code:400 userInfo:@{NSLocalizedDescriptionKey: errorMessage}]];
//                }
//            }
//
//            //everything else has been done by now, additional check to see if subscriber credential has expired.
//            GRDSubscriberCredential *cred = [GRDSubscriberCredential currentSubscriberCredential];
//            if (cred) {
//                if ([cred tokenExpired]) {
//                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
//                }
//            }
//
//			if ([self.delegate isKindOfClass:[GRDSubscriptionManager class]]) {
//				GRDLog(@"Detected GRDSubscriptionManager as the delegate");
//				self.delegate = nil;
//			}
//
//			self_weak_.isPurchase = false;
//			self_weak_.isRestore = false;
//		}];
//    });
}

- (void)verifyReceipt:(NSData *)receipt filtered:(BOOL)filtered {
	@weakify(self);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSString *encodedReceipt;
		if (receipt) {
			encodedReceipt = [receipt base64EncodedStringWithOptions:0];
		}
		
		[[GRDHousekeepingAPI new] verifyReceipt:encodedReceipt bundleId:self.bundleId completion:^(NSArray<GRDReceiptItem *> * _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage) {
			NSArray *sortedValidLineItems = validLineItems;
			if (filtered == YES) {
				NSMutableArray *arrayWithoutIgnoredProductIds = [NSMutableArray new];
				for (GRDReceiptItem *receiptItem in validLineItems) {
					if (![self.ignoredProductIds containsObject:receiptItem.productId]) {
						[arrayWithoutIgnoredProductIds addObject:receiptItem];
					}
				}
				// sorted is sorted ascending by the line item's expiration date,
				// the last item in the array will be the latest purchase aka. the item whose expiration date
				// is the furthest out in the future
				NSSortDescriptor *expireDesc = [[NSSortDescriptor alloc] initWithKey:@"expiresDate" ascending:true];
				sortedValidLineItems = [arrayWithoutIgnoredProductIds sortedArrayUsingDescriptors:@[expireDesc]];
			}
			
			if (success == YES && sortedValidLineItems.count > 0) {
				GRDReceiptItem *latestItem = [sortedValidLineItems lastObject];
				dispatch_async(dispatch_get_main_queue(), ^{
					self_weak_.activePurchase = false;
					if (self_weak_.isRestore) {
						if ([self_weak_.delegate respondsToSelector:@selector(subscriptionRestored)]) {
							[self_weak_.delegate subscriptionRestored];
						}
						
						if ([self_weak_.delegate respondsToSelector:@selector(purchaseRestored:)]) {
							[self_weak_.delegate purchaseRestored:latestItem];
						}
						
						self_weak_.isPurchase = false;
						self_weak_.isRestore = false;
						
					} else if (self_weak_.isPurchase) {
						if ([self_weak_.delegate respondsToSelector:@selector(subscribedSuccessfully)]) {
							[self_weak_.delegate subscribedSuccessfully];
						}
						
						if ([self_weak_.delegate respondsToSelector:@selector(purchasedSuccessfully:)]) {
							[self_weak_.delegate purchasedSuccessfully:latestItem];
						}
						
						self_weak_.isPurchase = false;
						self_weak_.isRestore = false;
					}
				});

			} else if (success == YES && (sortedValidLineItems.count == 0 || sortedValidLineItems == nil)) {
				[self.delegate receiptInvalid];
				
			} else {
				if (errorMessage != nil) {
					GRDLog(@"Failed to verify receipt: %@", errorMessage);
					[self.delegate purchaseFailedWithError:[NSError errorWithDomain:@"com.guardian.GuardianConnect" code:400 userInfo:@{NSLocalizedDescriptionKey: errorMessage}]];
				}
			}
			
			//everything else has been done by now, additional check to see if subscriber credential has expired.
			GRDSubscriberCredential *cred = [GRDSubscriberCredential currentSubscriberCredential];
			if (cred) {
				if ([cred tokenExpired]) {
					[GRDKeychain removeSubscriberCredentialWithRetries:3];
				}
			}
			
			if ([self.delegate isKindOfClass:[GRDSubscriptionManager class]]) {
				GRDDebugLog(@"Detected GRDSubscriptionManager as the delegate. Setting delegate back to nil");
				self.delegate = nil;
			}
			
			self_weak_.isPurchase = false;
			self_weak_.isRestore = false;
		}];
	});
}


# pragma mark - Internal States

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

#pragma mark - Misc Helpers

+ (BOOL)isPayingUser {
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	return ([ud boolForKey:kGuardianSuccessfulSubscription] && [ud boolForKey:kIsPremiumUser]);
}

+ (void)setIsPayingUser:(BOOL)isPaying {
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[ud setBool:isPaying forKey:kIsPremiumUser];
	[ud setBool:isPaying forKey:kGuardianSuccessfulSubscription];
}

@end
