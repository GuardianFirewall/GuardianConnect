//
//  GRDSubscriptionManager.h
//  Guardian
//
//  Created by Constantin Jacob on 12.04.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDIAPDiscountDetails.h>
#import <GuardianConnect/GRDSubscriberCredential.h>

//missing, add properly later
#define kUserNotEligibleForFreeTrial    @"guardianUserNotEligibleForTrial"
#define kNotificationSubscriptionActive @"notifSubscriptionActive"
#define kNotficationPurchaseInAppStore @"notifPurchaseOriginatedAppStore"
#define kNotificationRestoreSubscriptionFinished @"notifRestoreSubFinished"
#define kNotificationRestoreSubscriptionError @"notifRestoreSubError"
#define kNotificationFreeTrialEligibilityChanged @"notifFreeTrialEligibilityChanged"
#define kNotificationSubscriptionInactive @"notifSubscriptionInactive"

NS_ASSUME_NONNULL_BEGIN

@protocol GRDSubscriptionDelegate;

@interface GRDSubscriptionManager : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>
/// Delegate that handles callbacks for receipt validation handling
@property (nonatomic, weak) id <GRDSubscriptionDelegate> delegate;

/// Always use the sharedManager singleton when using this class.
+ (instancetype)sharedManager;

/// Set the API secret key as well as the bundle id for future requests to obtain the list of
/// known product ids or verify the in-app purchase receipts
- (void)setAPISecret:(NSString *)apiSecret andBundleId:(NSString *)bundleId;

/// API Secret used to identify the Apple provided shared secret to verify in-app purchase receipts
@property (nonatomic, strong) NSString *apiSecret;

/// Bundle Id identifying the Guardian partner app to verify in-app purchase receipts
@property (nonatomic, strong) NSString * bundleId;

/// Guardian internal properties for IAP discount tracking
@property BOOL isEligibleForDiscounts;
/// Ditto
@property (nonatomic, strong) GRDIAPDiscountDetails *discountDetails;

/// Add to this array if you want any product id's exempt from receipt validation (non-app store purchases)
@property NSArray *receiptExceptionIds;

/// Product ID's to limit programatically which ids are supposed to get verified / which products the app should retrieve prices and product details for. Currently not implemented
@property NSArray *productIds;

/// Keeps track of the response from SKProductRequest
@property NSArray <SKProduct *> *sortedProductOfferings;

/// Keeps track of the locale for the SKProducts
@property NSLocale *subscriptionLocale;



/// Used when a user account expires to clear all the necessary user defaults and keychain credentials
/// @param wasTrial BOOL value that determines whether or not the account was a trial
- (void)userExpiredTrial:(BOOL)wasTrial;

/// Used to process & verify receipt data for a valid subscription, plan update or subscription expiration, communicates via GRDSubscriptionDelegate callbacks
- (void)verifyReceipt;

/// TODO: this is redundant in VPN manager and should be factored out of there.
- (GRDPlanDetailType)subscriptionTypeFromDefaults;

/// Called in showActivateButton and in verifyReceipt to make certain day pass users that are missing corresponding receipt data don't get unsubscribed accidently.
- (BOOL)isFreeTrialOrDayPass;

/// These are subscription types that we skip receipt validation on, they consist of partner product ID's and purchases made outside of the app store.
- (NSArray *)whitelist;

/// Conveinience check to see if our subscription type exists among the whitelisted types.
- (BOOL)hasWhitelistedSubscriptionType;


@end


@protocol GRDSubscriptionDelegate <NSObject>

- (void)receiptInvalid;
- (void)validatingReceipt;
- (void)subscribedSuccessfully; //will be obsoleted
- (void)subscribedSuccessfully:(GRDReceiptItem *)receiptItem;
- (void)subscriptionDeferred;
- (void)subscriptionFailed;
- (void)subscriptionRestored; //will be obsoleted
- (void)subscriptionRestored:(GRDReceiptItem *)receiptItem;

@end

NS_ASSUME_NONNULL_END
