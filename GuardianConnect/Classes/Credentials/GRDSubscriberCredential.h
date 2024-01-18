//
//  GRDSubscriberCredential.h
//  Guardian
//
//  Created by Constantin Jacob on 11.05.20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDKeychain.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDSubscriberCredential : NSObject

/// The complete unparsed, encoded JWT string
@property (nonatomic, strong) NSString *jwt;

/// The subscription type of the parsed Subscriber Credential
@property (nonatomic, strong) NSString *subscriptionType;

/// The user formatted, pretty subscription type of the parsed Subscriber Credential
@property (nonatomic, strong) NSString *subscriptionTypePretty;

/// The subscription expiration date of the parsed Subscriber Credential
@property (nonatomic) NSInteger 		subscriptionExpirationDate;

/// The JWT expiration date of the parsed Subscriber Credential
@property (nonatomic) NSInteger 		tokenExpirationDate;

/// Convenience property to quickly check whether or not the JWT has expired
@property (nonatomic) BOOL 				tokenExpired;


- (instancetype)initWithSubscriberCredential:(NSString *)subscriberCredential;

/// Returns the Subscriber Credentials currently stored in the local keychain
+ (GRDSubscriberCredential * _Nullable)currentSubscriberCredential;

- (void)processSubscriberCredentialInformation;

/// Persistently store the preferred Subscriber Credential generation validation method
///
/// Storing the preferred validation method persistently will cause GRDVPNHelper to pick up the
/// preference during initalization and will in turn force [GRDVPNHelper getValidSubscriberCredentialWithCompletion:]
/// to always use the set preference.
/// Pass ValidationMethodInvalid to remove the preference
/// - Parameter validationMethod: the validation method that will be stored persistently
+ (void)setPreferredValidationMethod:(GRDHousekeepingValidationMethod)validationMethod;

/// Retrieves the persistently stored preferred validation method for Subscriber Credential generation
///
/// If no preferred validation method is set ValidationMethodInvalid will be returned
+ (GRDHousekeepingValidationMethod)getPreferredValidationMethod;

@end

NS_ASSUME_NONNULL_END
