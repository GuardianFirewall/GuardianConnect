//
//  GCSubscriptionManager.h
//  GuardianConnectSampleMacApp
//
//  Created by Kevin Bradley on 4/22/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GuardianConnectMac.h>
NS_ASSUME_NONNULL_BEGIN
static NSString * const kGRDExpiresDate =                       @"grd_expires_date";
static NSString * const kGRDProductID =                         @"product_id";
@protocol GCSubscriptionManagerDelegate <NSObject>

- (void)handleValidationSuccess;

@end

@interface GCSubscriptionManager : NSObject

@property id <GCSubscriptionManagerDelegate> delegate;
+ (instancetype)sharedInstance;
- (void)verifyReceipt;
@end

NS_ASSUME_NONNULL_END
