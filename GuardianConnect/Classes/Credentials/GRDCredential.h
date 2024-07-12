//
//  GRDCredential.h
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDTransportProtocol.h>

//
// Note from CJ 2024-04-20
// GRDRegion is being imported via the @class operator here to prevent
// a circular import and the compiler being very sad
@class GRDRegion;
@class GRDSGWServer;

NS_ASSUME_NONNULL_BEGIN

@interface GRDCredential : NSObject <NSSecureCoding>

// Properties used by all credentials
@property NSString 	        *name;
@property NSString 	        *identifier;
@property BOOL              mainCredential;
@property TransportProtocol transportProtocol;
@property NSDate 	        *expirationDate;
@property NSString 	        *hostname;
@property NSString 	        *hostnameDisplayValue;
@property GRDRegion 		* _Nullable region;

@property NSString          *clientId;
@property NSString          *apiAuthToken;

// IKEv2 related properties
@property NSString 	* _Nullable username;
@property NSString 	* _Nullable password;
@property NSData 	* _Nullable passwordRef;

// WireGuard related properties
@property NSString * _Nullable devicePublicKey;
@property NSString * _Nullable devicePrivateKey;
@property NSString * _Nullable serverPublicKey;
@property NSString * _Nullable IPv4Address;
@property NSString * _Nullable IPv6Address;

- (NSString *)prettyHost;
- (NSString *)defaultFileName;
- (instancetype)initWithTransportProtocol:(TransportProtocol)protocol fullDictionary:(NSDictionary *)credDict server:(GRDSGWServer *)server validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds;
- (void)updateWithItem:(GRDCredential *)cred;
- (NSString *)truncatedHost;
- (NSString *)authTokenIdentifier;
- (BOOL)expired;
- (NSInteger)daysLeft; //days until it does expire
- (BOOL)canRevoke; //legacy credentials are missing the API auth token so they cant be revoked.
- (void)revokeCredentialWithCompletion:(void(^)(BOOL success, NSString *errorMessage))completion;

/// Helper function to quickly convert a GRDCredential into a GRDSGWServer representation
- (GRDSGWServer *)sgwServerFormat;


// Note from CJ 2022-05-03
// Both of these are deprecated and only remain in the codebase
// to leave existing codepaths untouched. They should never be used directly
// nor should they be adopted anywhere else in newly written code since
// all credentials are now saved together as a data blob in the keychain
// and managed by GRDCredentialManager
- (OSStatus)saveToKeychain;
- (BOOL)loadFromKeychain;
- (OSStatus)removeFromKeychain;

@end

NS_ASSUME_NONNULL_END
