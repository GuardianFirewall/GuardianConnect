//
//  GRDReceiptItem.m
//  GuardianConnect
//
//  Created by Kevin Bradley on 5/23/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDReceiptLineItem.h>

@implementation GRDReceiptLineItem

- (instancetype)initWithDictionary:(NSDictionary *)receiptItem {
    self = [super init];
    if (self) {
        self.quantity 					= [receiptItem[@"quantity"] integerValue];
		self.expiresDatePst 			= receiptItem[@"expires_date_pst"];
		self.isInIntroOfferPeriod 		= [receiptItem[@"is_in_intro_offer_period"] boolValue];
		self.purchaseDateMs 			= [receiptItem[@"purchase_date_ms"] integerValue];
		self.transactionId 				= [receiptItem[@"transaction_id"] integerValue];
		self.isTrialPeriod 				= [receiptItem[@"is_trial_period"] boolValue];
		self.originalTransactionId 		= [receiptItem[@"original_transaction_id"] integerValue];
		self.originalPurchaseDatePst 	= receiptItem[@"original_purchase_date_pst"];
		self.productId 					= receiptItem[@"product_id"];
		self.subscriptionGroupIdentifier = [receiptItem[@"subscription_group_identifier"] integerValue];
		self.originalPurchaseDateMs 	= [receiptItem[@"original_purchase_date_ms"] integerValue];
		self.webOrderLineItemId 		= [receiptItem[@"web_order_line_item_id"] integerValue];
		self.expiresDateMs 				= [receiptItem[@"expires_date_ms"] integerValue];
		self.purchaseDatePst 			= receiptItem[@"purchase_date_pst"];
        [self _translateDates];
    }
    return self;
}

/// Convert MS date values into proper NSDate's
- (void)_translateDates {
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

- (BOOL)subscriberCredentialExpired {
    NSDate *subCredSubExpirationDate = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianSubscriptionExpiresDate];
    return ([subCredSubExpirationDate isEqualToDate:self.expiresDate] == NO);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"product-id: %@; expires: %@; purchased: %@", self.productId, self.expiresDate, self.purchaseDate];
}

@end
