//
//  GRDIAPReceiptResponse.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 12.04.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDReceiptLineItem.h>
#import <GuardianConnect/GRDReceiptLineItemMetadata.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDIAPReceiptResponse : NSObject

@property NSArray <GRDReceiptLineItem *> *lineItems;
@property NSArray <GRDReceiptLineItemMetadata *> *lineItemsMetadata;


- (instancetype)initWithWithReceiptResponse:(NSDictionary *)receiptResponse;


@end

NS_ASSUME_NONNULL_END
