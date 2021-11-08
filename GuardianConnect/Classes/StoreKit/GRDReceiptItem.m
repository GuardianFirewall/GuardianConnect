//
//  GRDReceiptItem.m
//  GuardianConnect
//
//  Created by Kevin Bradley on 5/23/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDReceiptItem.h>
#import <GuardianConnect/NSString+Extras.h>

@implementation GRDReceiptItem

- (instancetype)initWithDictionary:(NSDictionary *)receiptItem {
    self = [super init];
    if (self) {
        self.quantity = [receiptItem[@"quantity"] integerValue]; //ex: 1
        //_expiresDate = receiptItem[@"expires_date"]; //ex: 2021-04-22 21:26:00 Etc/GMT
		self.expiresDatePst = receiptItem[@"expires_date_pst"]; //ex: 2021-04-22 14:26:00 America/Los_Angeles
		self.isInIntroOfferPeriod = [receiptItem[@"is_in_intro_offer_period"] boolValue]; //ex: false
		self.purchaseDateMs = [receiptItem[@"purchase_date_ms"] integerValue]; //ex: 1619123160000
		self.transactionId = [receiptItem[@"transaction_id"] integerValue]; //ex: 1000000804227741
		self.isTrialPeriod = [receiptItem[@"is_trial_period"] boolValue]; //ex: false
		self.originalTransactionId = [receiptItem[@"original_transaction_id"] integerValue]; //ex: 1000000718884296
		self.originalPurchaseDatePst = receiptItem[@"original_purchase_date_pst"]; //ex: 2021-04-22 13:26:07 America/Los_Angeles
		self.productId = receiptItem[@"product_id"]; //ex: grd_pro
        //_purchaseDate = receiptItem[@"purchase_date"]; //ex: 2021-04-22 20:26:00 Etc/GMT
		self.subscriptionGroupIdentifier = [receiptItem[@"subscription_group_identifier"] integerValue]; //ex: 20483166
		self.originalPurchaseDateMs = [receiptItem[@"original_purchase_date_ms"] integerValue]; //ex: 1619123167000
		self.webOrderLineItemId = [receiptItem[@"web_order_line_item_id"] integerValue]; //ex: 1000000061894935
		self.expiresDateMs = [receiptItem[@"expires_date_ms"] integerValue]; //ex: 1619126760000
		self.purchaseDatePst = receiptItem[@"purchase_date_pst"]; //ex: 2021-04-22 13:26:00 America/Los_Angeles
        //_originalPurchaseDate = receiptItem[@"original_purchase_date"]; //ex: 2021-04-22 20:26:07 Etc/GMT
        [self _translateData];
    }
    return self;
}

- (BOOL)subscriberCredentialExpired {
    NSDate *subCredSubExpirationDate = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianSubscriptionExpiresDate];
    return ([subCredSubExpirationDate isEqualToDate:self.expiresDate] == NO);
}

- (BOOL)expired {
    NSComparisonResult result = [[NSDate date] compare:self.expiresDate];
    switch (result) {
        case NSOrderedSame:
        case NSOrderedDescending:
            break;
        case NSOrderedAscending: //expires date > current date
            return false;
    }
    return true;
}

//convert MS date values into proper NSDate's
- (void)_translateData {
	self.expiresDate = [NSDate dateWithTimeIntervalSince1970:self.expiresDateMs/1000];
	self.purchaseDate = [NSDate dateWithTimeIntervalSince1970:self.purchaseDateMs/1000];
	self.originalPurchaseDate = [NSDate dateWithTimeIntervalSince1970:self.originalPurchaseDateMs/1000];
	self.isDayPass = false; //default to false
    
    if (self.expiresDateMs == 0) {
		GRDLog(@"Day Pass detected");
		self.expiresDate = [NSDate dateWithTimeIntervalSince1970:(self.purchaseDateMs/1000)+86400];
		self.isDayPass = true;
    }
}

- (NSString *)description {
    NSString *ogDesc = [super description];
    return [NSString stringWithFormat:@"%@ %@ expires: %@ purchased: %@", ogDesc, self.productId, self.expiresDate, self.purchaseDate];
}

@end
