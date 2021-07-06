//
//  GRDIAPDiscountDetails.m
//  GuardianCore
//
//  Created by Kevin Bradley on 7/5/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDIAPDiscountDetails.h>

@implementation GRDIAPDiscountDetails

- (instancetype)initWithDictionary:(NSDictionary *)iapDiscountInfo {
    self = [super init];
    if (self) {
        _discountSubType       = iapDiscountInfo[@"discount-sub-type"];
        _discountSubTypePretty = iapDiscountInfo[@"discount-sub-type-pretty"];
        _discountIdentifier    = iapDiscountInfo[@"discount-identifier"];
        _discountPercentage    = iapDiscountInfo[@"discount-percentage"];
        _isCancelledSubscription    = [iapDiscountInfo[@"is-cancelled"] boolValue];
        _valid = [self validate];
    }
    return self;
}

- (BOOL)validate {
    return (_discountSubType != nil && _discountIdentifier != nil && _discountPercentage != nil && _discountSubTypePretty != nil);
}

@end
