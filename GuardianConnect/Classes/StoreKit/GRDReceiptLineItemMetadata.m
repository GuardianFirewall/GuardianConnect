//
//  GRDReceiptMetadata.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 12.04.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDReceiptLineItemMetadata.h"

@implementation GRDReceiptLineItemMetadata

- (instancetype)initWithDictionary:(NSDictionary *)metadata {
	self = [super init];
	if (self) {
		self.autoRenewProductId = metadata[@"auto_renew_product_id"];
		self.autoRenewStatus = [metadata[@"auto_renew_status"] integerValue];
		self.expirationIntent = [metadata[@"expiration_intent"] integerValue];
		NSUInteger gracePeriodExpiresDateMS = [metadata[@"grace_period_expires_date_ms"] integerValue];
		self.gracePeriodExpiresDate = [NSDate dateWithTimeIntervalSince1970:gracePeriodExpiresDateMS/1000];
		self.isInBillingRetryPeriod = [metadata[@"is_in_billing_retry_period"] boolValue];
		self.originalTransactionId = metadata[@"original_transaction_id"];
		self.productId = metadata[@"product_id"];
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"product-id: %@; auto-renew-product-id: %@; auto-renew-status: %lu; original-transaction-id: %@", self.productId, self.autoRenewProductId, self.autoRenewStatus, self.originalTransactionId];
}

@end
