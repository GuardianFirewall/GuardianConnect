//
//  GRDSubscriberCredential.h
//  Guardian
//
//  Created by Constantin Jacob on 11.05.20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDVPNHelper.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDSubscriberCredential : NSObject

@property (nonatomic, strong) NSString *subscriberCredential; //for sending to API endpoints
@property (nonatomic, strong) NSString *subscriptionType;
@property (nonatomic, strong) NSString *subscriptionTypePretty;
@property (nonatomic) NSInteger tokenExpirationDate;
@property (nonatomic) NSInteger subscriptionExpirationDate;

@property (nonatomic) BOOL tokenExpired;

/// current subscriber credential if applicable
+ (GRDSubscriberCredential * _Nullable)currentSubscriberCredential;

- (instancetype)initWithSubscriberCredential:(NSString *)subscriberCredential;
- (void)processSubscriberCredentialInformation;

@end

NS_ASSUME_NONNULL_END
