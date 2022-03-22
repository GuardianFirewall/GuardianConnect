//
//  GRDCredential.h
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDTransportProtocol.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDCredential : NSObject

// Properties releveant to all credentials
@property NSString 	*name;
@property NSString 	*identifier;
@property NSDate 	*expirationDate;
@property NSString 	*hostname;
@property NSString 	*hostnameDisplayValue;
@property NSString 	*apiAuthToken;
@property TransportProtocol transportProtocol;

// IKEv2 related properties
@property NSString 	*username;
@property NSString 	*password;
@property NSData 	*passwordRef;

// WireGuard related properties
@property NSString *devicePublicKey;
@property NSString *devicePrivateKey;
@property NSString *serverPublicKey;
@property NSString *IPv4Address;
@property NSString *IPv6Address;
@property NSString *clientId;

// Experimental
@property BOOL mainCredential;

- (NSString *)prettyHost;
- (NSString *)defaultFileName;
- (id)initWithFullDictionary:(NSDictionary *)credDict validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds;
- (id)initWithTransportProtocol:(TransportProtocol)protocol fullDictionary:(NSDictionary *)credDict validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds;
- (id)initWithDictionary:(NSDictionary *)credDict hostname:(NSString *)hostname expiration:(NSDate *)expirationDate;
- (void)updateWithItem:(GRDCredential *)cred;
- (OSStatus)saveToKeychain;
- (BOOL)loadFromKeychain;
- (NSString *)truncatedHost;
- (OSStatus)removeFromKeychain;
- (NSString *)authTokenIdentifier;
- (BOOL)expired;
- (NSInteger)daysLeft; //days until it does expire
- (BOOL)canRevoke; //legacy credentials are missing the API auth token so they cant be revoked.
- (void)revokeCredentialWithCompletion:(void(^)(BOOL success, NSString *errorMessage))completion;

@end

NS_ASSUME_NONNULL_END
