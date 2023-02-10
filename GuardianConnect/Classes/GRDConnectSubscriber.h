//
//  GRDConnectSubscriber.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDConnectDevice.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kGuardianConnectSubscriber 								= @"kGuardianConnectSubscriber";
static NSString * const kGuardianConnectSubscriberIdentifierKey 				= @"ep-grd-subscriber-identifier";
static NSString * const kGuardianConnectSubscriberSecretKey 					= @"ep-grd-subscriber-secret";
static NSString * const kGuardianConnectSubscriberEmailKey 						= @"ep-grd-subscriber-email";
static NSString * const kGuardianConnectSubscriberSubscriptionSKUKey 			= @"ep-grd-subscription-sku";
static NSString * const kGuardianConnectSubscriberSubscriptionNameFormattedKey 	= @"ep-grd-subscription-name-formatted";
static NSString * const kGuardianConnectSubscriberSubscriptionExpirationDateKey = @"ep-grd-subscription-expiration-date";
static NSString * const kGuardianConnectSubscriberCreatedAtKey 					= @"ep-grd-subscriber-created-at";


@interface GRDConnectSubscriber : NSObject <NSSecureCoding>

@property NSString 	*identifier;
@property NSString 	*secret;
@property NSString 	*email;
@property NSString 	*subscriptionSKU;
@property NSString 	*subscriptionNameFormmated;
@property NSDate 	*subscriptionExpirationDate;
@property NSDate 	*createdAt;

// TODO
// allow for easy storing and retrieving of the subscriber info
// add functions to load secret out of the keychain
// add function to quickly decode JSON into GRDConnectSubscriber object
// add convenience functions to register/update/validate subscriber
// add functions to quickly add a new device for this subscriber
// list all devices for the user?

- (instancetype)initFromDictionary:(NSDictionary * _Nonnull)dict;

+ (void)currentSubscriberWithCompletion:(void (^)(GRDConnectSubscriber * _Nullable subscriber, NSError * _Nullable error))completion;

- (BOOL)loadSecretFromKeychain;

- (NSError *)store;

- (void)allDevicesWithCompletion:(void (^)(NSArray <GRDConnectDevice *> * _Nullable devices, NSString * _Nullable errorMessage))completion;


- (void)registerNewConnectSubscriber:(BOOL)acceptedTOS withCompletion:(void (^)(GRDConnectSubscriber * _Nullable newSubscriber, NSString * _Nullable errorMessage))completion;

- (void)updateConnectSubscriberWithEmailAddress:(NSString * _Nonnull)email andCompletion:(void (^)(GRDConnectSubscriber * _Nullable subscriber, NSString * _Nullable errorMessage))completion;

- (void)validateConnectSubscriberWithCompletion:(void (^)(GRDConnectSubscriber * _Nullable subscriber, NSString * _Nullable errorMessage))completion;

@end

NS_ASSUME_NONNULL_END
