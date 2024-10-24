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
@property GRDSGWServer 		*server;
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


- (instancetype)initWithTransportProtocol:(TransportProtocol)protocol fullDictionary:(NSDictionary *)credDict server:(GRDSGWServer *)server validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds;
- (void)updateWithItem:(GRDCredential *)cred;
- (NSString *)prettyHost;
- (NSString *)truncatedHost;
- (NSString *)defaultFileName;
- (BOOL)expired;
- (NSInteger)daysLeft; //days until it does expire
- (BOOL)canRevoke; //legacy credentials are missing the API auth token so they cant be revoked.
- (void)revokeCredentialWithCompletion:(void(^)(NSError * _Nullable error))completion;

/// Helper function to quickly convert a GRDCredential into a GRDSGWServer representation
- (GRDSGWServer *)sgwServerFormat;

@end

NS_ASSUME_NONNULL_END
