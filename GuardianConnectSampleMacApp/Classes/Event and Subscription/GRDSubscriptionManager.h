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
#import <GuardianConnect/GRDSubscriberCredential.h>

//missing, add properly later
#define kUserNotEligibleForFreeTrial    @"guardianUserNotEligibleForTrial"
#define kNotificationSubscriptionActive @"notifSubscriptionActive"
#define kNotficationPurchaseInAppStore @"notifPurchaseOriginatedAppStore"
#define kNotificationRestoreSubscriptionFinished @"notifRestoreSubFinished"
#define kNotificationRestoreSubscriptionError @"notifRestoreSubError"
#define kNotificationFreeTrialEligibilityChanged @"notifFreeTrialEligibilityChanged"
#define kNotificationSubscriptionInactive @"notifSubscriptionInactive"

static NSString * _Nonnull const kGRDFreeTrialExpired =                 @"kGRDFreeTrialExpired";
static NSString * _Nonnull const kGRDTrialExpirationInterval =          @"kGRDTrialExpirationInterval";

//#import "GRDHousekeepingAPI+Private.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const kGRDExpiresDate =                       @"grd_expires_date";
static NSString * const kGRDProductID =                         @"product_id";

typedef NS_ENUM(NSInteger, GRDTrialBalanceResponse) {
    GRDTrialBalanceNotApplicable,
    GRDTiralBalanceOldStyleActivated,
    GRDTrialBalanceAvailable,
    GRDTrialBalanceExpired,
    GRDDayPassesAvailable,
    GRDTrialBalanceError
};


@protocol GRDSubscriptionDelegate;

@interface GRDSubscriptionManager : NSObject <SKPaymentTransactionObserver>

@property (nonatomic, weak) id <GRDSubscriptionDelegate> delegate;
@property BOOL isEligibleForDiscounts;
@property (nonatomic, strong) NSString *iapDiscountId;
@property (nonatomic, strong) NSString *iapDiscountSubType;
@property (nonatomic, strong) NSString *iapDiscountPercentage;

+ (instancetype)sharedManager;
- (void)verifyReceipt;
- (void)test;
- (GRDPlanDetailType)subscriptionTypeFromDefaults;
- (void)verifySubscription;
- (BOOL)isFreeTrial;
- (BOOL)isFreeTrialOrDayPass;
- (BOOL)showActivateButton;
- (void)expireFreeTrial;
- (NSArray *)whitelist;
- (BOOL)hasWhitelistedSubscriptionType;
- (void)setLocalNotificationForTrialPETExpirationDate:(NSInteger)expirationDate;
@end


@protocol GRDSubscriptionDelegate <NSObject>

- (void)receiptInvalid;
- (void)validatingReceipt;
- (void)subscribedSuccessfully;
- (void)subscriptionDeferred;
- (void)subscriptionFailed;
- (void)subscriptionRestored;

@end

NS_ASSUME_NONNULL_END
