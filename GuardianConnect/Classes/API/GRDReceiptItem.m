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
        _quantity = [receiptItem[@"quantity"] integerValue]; //ex: 1
        //_expiresDate = receiptItem[@"expires_date"]; //ex: 2021-04-22 21:26:00 Etc/GMT
        _expiresDatePst = receiptItem[@"expires_date_pst"]; //ex: 2021-04-22 14:26:00 America/Los_Angeles
        _isInIntroOfferPeriod = [receiptItem[@"is_in_intro_offer_period"] boolValue]; //ex: false
        _purchaseDateMs = [receiptItem[@"purchase_date_ms"] integerValue]; //ex: 1619123160000
        _transactionId = [receiptItem[@"transaction_id"] integerValue]; //ex: 1000000804227741
        _isTrialPeriod = [receiptItem[@"is_trial_period"] boolValue]; //ex: false
        _originalTransactionId = [receiptItem[@"original_transaction_id"] integerValue]; //ex: 1000000718884296
        _originalPurchaseDatePst = receiptItem[@"original_purchase_date_pst"]; //ex: 2021-04-22 13:26:07 America/Los_Angeles
        _productId = receiptItem[@"product_id"]; //ex: grd_pro
        //_purchaseDate = receiptItem[@"purchase_date"]; //ex: 2021-04-22 20:26:00 Etc/GMT
        _subscriptionGroupIdentifier = [receiptItem[@"subscription_group_identifier"] integerValue]; //ex: 20483166
        _originalPurchaseDateMs = [receiptItem[@"original_purchase_date_ms"] integerValue]; //ex: 1619123167000
        _webOrderLineItemId = [receiptItem[@"web_order_line_item_id"] integerValue]; //ex: 1000000061894935
        _expiresDateMs = [receiptItem[@"expires_date_ms"] integerValue]; //ex: 1619126760000
        _purchaseDatePst = receiptItem[@"purchase_date_pst"]; //ex: 2021-04-22 13:26:00 America/Los_Angeles
        //_originalPurchaseDate = receiptItem[@"original_purchase_date"]; //ex: 2021-04-22 20:26:07 Etc/GMT
        [self _translateData];
    }
    return self;
}

//convert MS date values into proper NSDate's

- (void)_translateData {
    _expiresDate = [NSDate dateWithTimeIntervalSince1970:self.expiresDateMs/1000];
    _purchaseDate = [NSDate dateWithTimeIntervalSince1970:self.purchaseDateMs/1000];
    _originalPurchaseDate = [NSDate dateWithTimeIntervalSince1970:self.originalPurchaseDateMs/1000];
    
    if (!_expiresDate) { //must be a day pass
        _expiresDate = [NSDate dateWithTimeIntervalSince1970:(self.purchaseDateMs/1000)+86400];
    }
    
}

- (NSString *)description {
    NSString *ogDesc = [super description];
    return [NSString stringWithFormat:@"%@ %@ expires: %@ purchased: %@", ogDesc, _productId, _expiresDate, _purchaseDate];
}

@end
