//
//  GRDReceiptMetadata.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 12.04.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDReceiptLineItemMetadata : NSObject

@property NSString *autoRenewProductId;
@property NSUInteger autoRenewStatus;
@property NSUInteger expirationIntent;
@property NSDate *gracePeriodExpiresDate;
@property BOOL isInBillingRetryPeriod;
@property NSString *originalTransactionId;
@property NSString *productId;

- (instancetype)initWithDictionary:(NSDictionary *)metadata;

@end

NS_ASSUME_NONNULL_END
