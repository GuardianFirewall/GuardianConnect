//
//  GRDIAPReceiptResponse.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 12.04.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDIAPReceiptResponse.h"

@implementation GRDIAPReceiptResponse

- (instancetype)initWithWithReceiptResponse:(NSDictionary *)receiptResponse {
	self = [super init];
	if (self) {
		NSArray *lineItems = receiptResponse[@"line-items"];
		NSMutableArray <GRDReceiptLineItem *> *parsedLineItems = [NSMutableArray new];
		if (lineItems != nil) {
			for (NSDictionary *lineItem in lineItems) {
				[parsedLineItems addObject:[[GRDReceiptLineItem alloc] initWithDictionary:lineItem]];
			}
			
			self.lineItems = [NSArray arrayWithArray:parsedLineItems];
		}
		
		NSArray *lineItemsMetadata = receiptResponse[@"line-items-metadata"];
		NSMutableArray <GRDReceiptLineItemMetadata *> *parsedLineItemsMetadata = [NSMutableArray new];
		if (lineItemsMetadata != nil) {
			for (NSDictionary *metadata in lineItemsMetadata) {
				[parsedLineItemsMetadata addObject:[[GRDReceiptLineItemMetadata alloc] initWithDictionary:metadata]];
			}
			
			self.lineItemsMetadata = [NSArray arrayWithArray:parsedLineItemsMetadata];
		}
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"line-items: %@; line-items-metadata: %@", self.lineItems, self.lineItemsMetadata];
}


@end
