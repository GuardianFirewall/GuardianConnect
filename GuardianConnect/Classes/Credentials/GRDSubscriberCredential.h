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


/// Parses and processes a Subscriber Credential (JWT) string into
/// a valid Subscriber Credential object
///
/// There is potential for failure during parsing and processing in which
/// case an empty GRDConnectSubscriber object is returned
/// - Parameter subscriberCredential: a valid jwt to process
- (instancetype)initWithSubscriberCredential:(NSString *)subscriberCredential;

/// Returns the Subscriber Credentials currently stored in the local keychain
+ (GRDSubscriberCredential * _Nullable)currentSubscriberCredential;

/// Checks the JWT's token as well as the subscription expiration date
/// to ensure that token is still valid for server side interactions
- (BOOL)isExpired;

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
